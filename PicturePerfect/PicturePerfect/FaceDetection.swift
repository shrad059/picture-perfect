//
//  FaceDetection.swift
//  PicturePerfect
//
//  Created by Shraddha Singh on 2024-07-29.
//

import Foundation
import MLKitVision
import MLKitFaceDetection
import AVFoundation
import CoreMedia

class FaceDetection {
    static let shared = FaceDetection()
    
    var faceDetector: FaceDetector?
    var options = FaceDetectorOptions()
    
    func setupFaceDetection() {
        // High-accuracy landmark detection and face classification
        
        self.options.performanceMode = .fast
        self.options.landmarkMode = .all
        self.options.classificationMode = .all
        self.options.minFaceSize = CGFloat(0.1)

        // Real-time contour detection of multiple faces
        // options.contourMode = .all
        
        self.faceDetector = FaceDetector.faceDetector(options: self.options)
    }
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer, completion: @escaping(_ face: [Face],_ pickedImage: UIImage) -> Void) {
        let ciimage: CIImage = CIImage(cvImageBuffer: pixelBuffer)
        let ciContext = CIContext()
        guard let cgImage: CGImage = ciContext.createCGImage(ciimage, from: ciimage.extent) else {
            // end of measure
            return
        }
        let uiImage: UIImage = UIImage(cgImage: cgImage)
        
        // predict!
        self.detectFace(uiImage) { face, pickedImage in
            completion(face, pickedImage)
        }
    }
    
    func detectFace(_ pickedImage: UIImage, completion: @escaping(_ face: [Face],_ pickedImage: UIImage) -> Void) {
        let visionImage = VisionImage (image: pickedImage)
        self.faceDetector?.process (visionImage) { faces, error in
            guard let faces = faces,
                  !faces.isEmpty,
                  faces.count >= 1,
                  let face = faces.first
            else {
                return
            }
            completion([face], pickedImage)
        }
    }
    
}
