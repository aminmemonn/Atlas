import SwiftUI
import UIKit
import AVFoundation

/// A thin `UIViewControllerRepresentable` wrapper around an AVFoundation capture
/// session that scans QR codes and reports decoded strings.
struct QRScannerView: UIViewControllerRepresentable {
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScan: ((String) -> Void)?
        // AVCaptureSession is not Sendable; it is confined to `sessionQueue`.
        nonisolated(unsafe) private let session = AVCaptureSession()
        private let sessionQueue = DispatchQueue(label: "com.atlas.camera.session")
        private var preview: AVCaptureVideoPreviewLayer?
        private var hasReported = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            configureSession()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            sessionQueue.async { [session] in
                if !session.isRunning { session.startRunning() }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            sessionQueue.async { [session] in
                if session.isRunning { session.stopRunning() }
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            preview?.frame = view.bounds
        }

        private func configureSession() {
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = view.bounds
            view.layer.addSublayer(layer)
            preview = layer
        }

        // The metadata delegate queue is `.main` (set above), so the callback is
        // already on the main actor; assert that to satisfy Swift 6 isolation.
        nonisolated func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            // Extract the Sendable string in the nonisolated callback, then hop
            // to the main actor with only that value.
            guard let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue
            else { return }
            Task { @MainActor in
                guard !self.hasReported else { return }
                self.hasReported = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.onScan?(value)
            }
        }
    }
}
