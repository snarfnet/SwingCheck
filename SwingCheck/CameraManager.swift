import AVFoundation
import Vision
import UIKit

@Observable
final class CameraManager: NSObject {
    let session = AVCaptureSession()
    var currentPose: BodyPose?
    var isBackCamera = false  // front camera default

    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "camera.pose.queue")
    private let confidenceThreshold: Float = 0.1
    private let ciContext = CIContext()

    func start() {
        guard !session.isRunning else { return }
        queue.async { [weak self] in
            self?.configureSession()
            self?.session.startRunning()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func flipCamera() {
        isBackCamera.toggle()
        queue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        session.sessionPreset = .high

        let position: AVCaptureDevice.Position = isBackCamera ? .back : .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration(); return
        }

        if session.canAddInput(input) { session.addInput(input) }
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoRotationAngle = 90
            if !isBackCamera { connection.isVideoMirrored = true }
        }
        session.commitConfiguration()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var detectedPose: BodyPose?
        let request = VNDetectHumanBodyPoseRequest { [weak self] req, _ in
            guard let self,
                  let results = req.results as? [VNHumanBodyPoseObservation],
                  let obs = results.first else { return }

            var pose = BodyPose()
            let names: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .neck,
                .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow,
                .leftWrist, .rightWrist,
                .leftHip, .rightHip,
                .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle,
                .root
            ]
            for name in names {
                guard let pt = try? obs.recognizedPoint(name),
                      pt.confidence > self.confidenceThreshold else { continue }
                pose.joints[name] = CGPoint(x: pt.location.x, y: 1 - pt.location.y)
            }
            detectedPose = pose
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])

        let pose = detectedPose
        DispatchQueue.main.async { [weak self] in
            self?.currentPose = pose
        }
    }
}
