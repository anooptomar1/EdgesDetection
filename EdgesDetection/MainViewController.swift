import UIKit
import Vision
import AVFoundation
import Dispatch
import CoreImage

class MainViewController: UIViewController {
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue: DispatchQueue!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureDevice: AVCaptureDevice!
    private let session = AVCaptureSession()

    lazy var detectedRect: UIView = {
        let detectedRect = UIView()
        detectedRect.backgroundColor = .red
        detectedRect.frame = CGRect(x: 10, y: 10, width: 200, height: 200)
        view.addSubview(detectedRect)
        return detectedRect
    }()

    lazy var previewView: UIView = {
        let preview = UIView()
        view.addSubview(preview)
        preview.frame = view.bounds
        return preview
    }()

    override func loadView() {
        super.loadView()
        setupSession()
        view.backgroundColor = .green
    }
}


extension MainViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func setupSession() {
        session.sessionPreset = .hd1920x1080
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        captureDevice = device
        beginSession()
    }

    private func beginSession() {
        if let deviceInput = try? AVCaptureDeviceInput(device: captureDevice), session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutputQueue = DispatchQueue(label: "video_preview_queue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        session.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var requestOptions: [VNImageOption: Any] = [:]
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: camData]
        }
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: requestOptions)
        let request = VNDetectRectanglesRequest(completionHandler: self.detectRectanglesHandler)
        request.maximumObservations = 1
        do {
            try imageRequestHandler.perform([request])
        } catch {
            print("error")
        }
    }

    func detectRectanglesHandler(request: VNRequest, error: Error?) {
        guard let observations = request.results else { return }
        guard let rectangleObservation = observations.first as? VNRectangleObservation else { return }

        let observationRect = rectangleObservation.boundingBox
        let convertedRect = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observationRect)

        DispatchQueue.main.async {
            [unowned self] in
            self.detectedRect.frame = convertedRect
        }
    }
}
