//
//  FaceDetectionView.swift
//  PicturePerfect
//
//  Created by Shraddha Singh on 2024-07-29.
//

import Foundation
import UIKit
import MLKitVision
import MLKitFaceDetection
import AVFoundation
import CoreMedia
import Photos

class FaceDetectionView: BaseViewController {
    
    //MARK: - IBOutlets
    @IBOutlet weak private var videoPreview: UIView!
    
    //MARK: - Properties
    private var videoCapture: CameraPreview?
    
    var squareLayer = CALayer()
    let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.setUpCamera()
        
        self.videoPreview.layer.borderWidth = 6
        self.videoPreview.layer.cornerRadius = 10
        self.videoPreview.layer.borderColor = UIColor.yellow.cgColor
        self.videoPreview.clipsToBounds = true
    }
    
    private func setUpCamera() {
        FaceDetection.shared.setupFaceDetection()
        
        videoCapture = CameraPreview()
        videoCapture?.delegate = self
        videoCapture?.fps = 15
        videoCapture?.setUp(sessionPreset: .vga640x480) { success in
            if success {
                // add preview view on the layer
                if let previewLayer = self.videoCapture?.previewLayer {
                    self.videoCapture?.previewLayer?.frame = self.videoPreview.bounds
                    self.videoPreview.layer.addSublayer(previewLayer)
                }
                // start video preview when setup is done
                self.videoCapture?.start()
            }
        }
    }
    
    private var isSmiling = false  // Track smile state
    
    private func drawSquareOnFace(faces: [Face], in originalImage: UIImage) {
        for face in faces {
            let boundingBox = face.frame
            let imageSize = originalImage.size
            
            let faceRectConverted = CGRect(
                x: imageSize.width - boundingBox.origin.x - boundingBox.size.width - 46,
                y: boundingBox.origin.y + 50,
                width: boundingBox.size.width,
                height: boundingBox.size.height + 20
            )
            
            var labelText = ""

            if face.smilingProbability > 0.3 {
                labelText = "PERFECT! "
                
                // Only take a picture when transitioning from non-smiling to smiling
                if !isSmiling {
                    saveImageToPhotos(originalImage)
                    isSmiling = true  // Set the flag to true so no more pictures are taken until the smile goes away
                }
                
            } else {
                labelText = "SMILE to detect"
                isSmiling = false  // Reset the flag when no smile is detected
            }
            
            self.label.numberOfLines = 0
            self.label.textColor = .systemPink
            self.label.text = labelText
            self.label.font = UIFont.systemFont(ofSize: 20)
            self.label.sizeToFit()
            self.label.center = CGPoint(x: faceRectConverted.midX, y: faceRectConverted.maxY + self.label.frame.height / 2 + 5)
            self.label.frame.size.width = face.frame.width
            
            self.view.addSubview(self.label)
            
            self.squareLayer.bounds = faceRectConverted
            self.squareLayer.position = CGPoint(x: faceRectConverted.midX, y: faceRectConverted.midY)
            self.squareLayer.borderWidth = 5.0
            self.squareLayer.cornerRadius = 5.0
            self.squareLayer.borderColor = UIColor(red: 255/255, green: 78/255, blue: 136/255, alpha: 1.0).cgColor
            self.view.layer.addSublayer(self.squareLayer)
        }
    }
    
    // Method to save the image to Photos
    private func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if success {
                print("Image saved to Photos")
            } else if let error = error {
                print("Error saving image: \(error)")
            }
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

// MARK: - Video Delegate
extension FaceDetectionView: CameraPreviewDelegate {
    func videoCapture(_ capture: CameraPreview, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if let pixelBuffer = pixelBuffer {
            FaceDetection.shared.predictUsingVision(pixelBuffer: pixelBuffer) { face, pickedImage in
                self.drawSquareOnFace(faces: face, in: pickedImage)
            }
        }
    }
}
