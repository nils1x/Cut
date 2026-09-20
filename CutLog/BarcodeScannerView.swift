@preconcurrency import AVFoundation
import SwiftUI

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}
}

@MainActor
final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    // Configuration happens once before work is queued. Start/stop stay on one serial queue.
    nonisolated(unsafe) private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.nils.CutLog.barcode")
    private var isVisible = false
    private var isRequestingCamera = false
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isVisible = true
        if previewLayer != nil {
            sessionQueue.async { [session] in session.startRunning() }
            return
        }
        guard !isRequestingCamera else { return }
        isRequestingCamera = true
        Task { [weak self] in
            defer { self?.isRequestingCamera = false }
            let granted: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: granted = true
            case .notDetermined: granted = await AVCaptureDevice.requestAccess(for: .video)
            default: granted = false
            }
            guard let self, self.isVisible else { return }
            if granted { self.configureSession() }
            else { self.onFailure?("Camera access is off. Enable Camera for Cut. in iPhone Settings, or enter food manually.") }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isVisible = false
        sessionQueue.async { [session] in session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onFailure?("Camera is unavailable. Add the product manually.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onFailure?("Barcode scanner could not start.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
        layer.frame = view.bounds

        sessionQueue.async { [session] in session.startRunning() }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let value = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first?.stringValue else { return }
        Task { @MainActor [weak self] in
            self?.handleScannedCode(value)
        }
    }

    private func handleScannedCode(_ value: String) {
        guard !didScan, isVisible else { return }
        didScan = true
        sessionQueue.async { [session] in session.stopRunning() }
        onCode?(value)
    }

    deinit { sessionQueue.async { [session] in session.stopRunning() } }
}
