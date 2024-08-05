import Foundation
import AVFoundation
import UIKit
import Photos
import Combine
import MLKitFaceDetection
import MLKitVision

class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @Published var capturedImage: UIImage?
    
    var session: AVCaptureSession?
    var delegate: AVCapturePhotoCaptureDelegate?
    
    let output = AVCapturePhotoOutput()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    private var faceDetector: FaceDetector!
    private var shouldCapturePhoto = false
    
    override init() {
        super.init()
        let options = FaceDetectorOptions()
        options.performanceMode = .fast
        options.contourMode = .none
        options.landmarkMode = .none
        options.classificationMode = .none
        faceDetector = FaceDetector.faceDetector(options: options)
    }
    
    func start(delegate: AVCapturePhotoCaptureDelegate, completion: @escaping (Error?) -> ()) {
        self.delegate = delegate
        checkPermissions(completion: completion)
    }
    
    private func checkPermissions(completion: @escaping (Error?) -> ()) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else { return }
                DispatchQueue.main.async {
                    self?.setupCamera(completion: completion)
                }
            }
        case .restricted, .denied:
            completion(NSError(domain: "CameraServiceError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Camera access is restricted or denied."]))
        case .authorized:
            setupCamera(completion: completion)
        @unknown default:
            completion(NSError(domain: "CameraServiceError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status."]))
        }
    }
    
    private func setupCamera(completion: @escaping (Error?) -> ()) {
        let session = AVCaptureSession()
        self.session = session
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            completion(NSError(domain: "CameraServiceError", code: 3, userInfo: [NSLocalizedDescriptionKey: "No video capture device available."]))
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                videoDeviceInput = input
            }
            
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            }
            
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.session = session
            
            session.startRunning()
            completion(nil)
        } catch {
            completion(error)
        }
    }
    
    func capturePhoto(with settings: AVCapturePhotoSettings = AVCapturePhotoSettings()) {
        guard let session = session, session.isRunning else {
            print("Session is not running or not initialized.")
            return
        }

        if output.connections.first(where: { $0.inputPorts.contains(where: { $0.mediaType == .video }) }) == nil {
            print("No active and enabled video connection.")
            return
        }

        output.capturePhoto(with: settings, delegate: self)
    }
    
    func switchCamera() {
        guard let session = session else { return }
        
        session.beginConfiguration()
        
        if let currentInput = videoDeviceInput {
            session.removeInput(currentInput)
        }
        
        currentCameraPosition = (currentCameraPosition == .back) ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("Failed to get new camera device.")
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        session.commitConfiguration()
    }
    
    private func saveImageToPhotosLibrary(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photo library access not authorized.")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("Successfully saved image to Photos.")
                    } else {
                        print("Error saving image to Photos: \(String(describing: error))")
                    }
                }
            }
        }
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }
        
        if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            DispatchQueue.main.async {
                self.capturedImage = image
                self.saveImageToPhotosLibrary(image)
            }
        } else {
            print("Error: no image data found")
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let visionImage = VisionImage(buffer: sampleBuffer)
        visionImage.orientation = .up
        
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces, !faces.isEmpty else {
                self.shouldCapturePhoto = false
                return
            }
            
            if self.shouldCapturePhoto == false {
                self.shouldCapturePhoto = true
                self.capturePhoto()
            }
        }
    }
}
