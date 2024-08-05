import SwiftUI

struct CustomCameraView: View {
    
    @StateObject private var cameraService = CameraService()
    @Binding var capturedImage: UIImage?
    
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        ZStack {
            CameraView(cameraService: cameraService) { result in
                switch result {
                case .success(let photo):
                    if let data = photo.fileDataRepresentation() {
                        capturedImage = UIImage(data: data)
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        print("Error: no image data found")
                    }
                case .failure(let error):
                    print("Camera capture failed: \(error.localizedDescription)")
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        cameraService.switchCamera()
                    }, label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    })
                    .padding()
                    Button(action: {
                        cameraService.capturePhoto()
                    }, label: {
                        Image(systemName: "circle")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)
                    })
                    .padding(.bottom)
                    Spacer()
                }
            }
        }
    }
}
