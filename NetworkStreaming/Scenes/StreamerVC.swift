//
//  StreamerVC.swift
//  NetworkStreaming
//
//  Created by cleanmac on 23/11/23.
//

import UIKit
import Network
import AVFoundation

final class StreamerVC: UIViewController {
    
    private var cameraPreviewLayerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        return view
    }()
    
    private var captureSession: AVCaptureSession!
    private var captureDevice: AVCaptureDevice!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var bufferDisplayLayer: AVSampleBufferDisplayLayer!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var captureQueue = DispatchQueue(label: "com.cleanrun.networkstreaming.captureQueue")
    
    private var listener: PeerListener!
    private var connection: PeerConnection?
    private var encoder: H264Encoder!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        encoder = try! H264Encoder(delegate: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        title = "Streamer"
        view.backgroundColor = .systemBackground
        
        view.addSubview(cameraPreviewLayerView)
        
        NSLayoutConstraint.activate([
            cameraPreviewLayerView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            cameraPreviewLayerView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            cameraPreviewLayerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cameraPreviewLayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupListener()
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.global(qos: .background).async { [unowned self] in
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        connection?.stopConnection()
        listener.stopListening()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1280x720
        
        let devices = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices
        
        guard let videoCaptureDevice = devices.first,
              let audioCaptureDevice = AVCaptureDevice.default(for: .audio) else {
            return
        }
        
        captureDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        let audioInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            audioInput = try AVCaptureDeviceInput(device: audioCaptureDevice)
        } catch {
            return
        }
        
        if captureSession.canAddInput(videoInput),
           captureSession.canAddInput(audioInput) {
            captureSession.addInput(videoInput)
            captureSession.addInput(audioInput)
        } else {
            return
        }
        
        videoDataOutput = AVCaptureVideoDataOutput()
        setupDataOutput()
        
        captureSession.beginConfiguration()
        for vFormat in videoCaptureDevice.formats {
            let ranges = vFormat.videoSupportedFrameRateRanges as [AVFrameRateRange]
            let frameRate = ranges.first!
            
            if frameRate.maxFrameRate == 240 {
                do {
                    try videoCaptureDevice.lockForConfiguration()
                    videoCaptureDevice.activeFormat = vFormat
                    videoCaptureDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(24))
                    videoCaptureDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(24))
                    videoCaptureDevice.unlockForConfiguration()
                } catch {
                    print("Could not lock for configuration")
                }
            }
        }
        captureSession.commitConfiguration()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        DispatchQueue.main.async { [unowned self] in
            self.previewLayer.frame = self.cameraPreviewLayerView.bounds
            self.cameraPreviewLayerView.layer.addSublayer(self.previewLayer)
        }
    }
    
    private func setupDataOutput() {
        videoDataOutput.videoSettings = [
            String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_32BGRA)
        ]
        
        if captureSession.canAddOutput(videoDataOutput) {
            DispatchQueue.main.async { [unowned self] in
                self.captureSession.addOutput(videoDataOutput)
            }
            videoDataOutput.setSampleBufferDelegate(self, queue: captureQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = false
        }
    }
    
    private func setupListener() {
        do {
            listener = PeerListener(name: UUID().uuidString, delegate: self)
            try listener.setupListener()
            listener.startListening { [unowned self] connection in
                self.connection = PeerConnection(connection: connection)
                self.connection?.delegate = self
                self.connection?.startConnection()
            }
        } catch {
            return
        }
    }
    
    private func showMessageAlert(title: String, message: String) {
        DispatchQueue.main.async { [unowned self] in
            self.presentedViewController?.dismiss(animated: true)
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            alert.addAction(action)
            self.present(alert, animated: true)
        }
    }

}

// MARK: - Connection delegate

extension StreamerVC: PeerConnectionDelegate {
    func connectionDidReady(_ connection: PeerConnection) {
        print(#function)
        showMessageAlert(title: "Connection established", message: "Connected to host: \(connection.endpointName ?? "Unrecognized endpoint")")
    }
    
    func connectionDidFailed(_ connection: PeerConnection, error: NWError) {
        print("\(#function); \(error.localizedDescription)")
        showMessageAlert(title: "Connection Failed", message: "Failed to connect to host: \(connection.endpointName ?? "Unrecognized endpoint")")
    }
    
    func didReceiveMessage(_ connection: PeerConnection, content: Data?, message: NWProtocolFramer.Message) {
        let type = message.peerMessageType
        
        switch type {
        case .invalid:
            break
        case .message:
            guard let content else { break }
            showMessageAlert(title: "Received message", message: "Data: \(String(decoding: content, as: UTF8.self))")
        default:
            break
        }
    }
    
    func connectionDidCancelled(_ connection: PeerConnection) {
        print("\(#function); \(connection.endpointName ?? "nil")")
    }
    
    func didReceiveError(_ connection: PeerConnection, error: NWError) {
        print(#function)
    }
    
}

extension StreamerVC: PeerListenerDelegate {
    func listenerDidReady(_ listener: NWListener) {}
    func listenerDidFailed(_ error: NWError) {}
    func listenerDidCancelled() {}
}

// MARK: - Data output sample buffer delegate

extension StreamerVC: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard self.connection != nil else { return }
        connection.videoOrientation = .portrait
        encoder.encode(sampleBuffer)
    }
}

// MARK: - Encoder delegate

extension StreamerVC: H264EncoderDelegate {
    func didReceiveNALU(_ naluData: Data) {
        guard let connection else { return }
        connection.send(type: .videoData, data: naluData)
    }
}
