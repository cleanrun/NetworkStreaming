//
//  HostVC.swift
//  NetworkStreaming
//
//  Created by cleanmac on 23/11/23.
//

import UIKit
import AVFoundation

final class HostVC: UIViewController {
    
    private var compressedPreviewLayerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 10
        view.layer.masksToBounds = true
        return view
    }()
    
    private var bufferDisplayLayer: AVSampleBufferDisplayLayer?
    
    private var hostSession: HostSession!
    private var naluParser: NALUParser!
    private var decoder: H264Decoder!
    
    init() {
        super.init(nibName: nil, bundle: nil)
        hostSession = HostSession(delegate: self)
        naluParser = NALUParser(delegate: self)
        decoder = H264Decoder(delegate: self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        title = "Host"
        view.backgroundColor = .systemBackground
        
        view.addSubview(compressedPreviewLayerView)
        
        NSLayoutConstraint.activate([
            compressedPreviewLayerView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            compressedPreviewLayerView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            compressedPreviewLayerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            compressedPreviewLayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Connect", style: .plain, target: self, action: #selector(showBrowserController))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hostSession.peerBrowser.startBrowsing()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupBufferDisplayLayer()
    }
    
    private func setupBufferDisplayLayer() {
        guard bufferDisplayLayer == nil else { return }
        
        bufferDisplayLayer = AVSampleBufferDisplayLayer()
        bufferDisplayLayer!.videoGravity = .resizeAspectFill
        bufferDisplayLayer!.frame = compressedPreviewLayerView.layer.bounds
        bufferDisplayLayer!.backgroundColor = UIColor.white.cgColor
        compressedPreviewLayerView.layer.addSublayer(bufferDisplayLayer!)
    }
    
    @objc private func showBrowserController() {
        guard hostSession.peerConnections.isEmpty else { return }
        let vc = PeerBrowserVC(using: hostSession)
        vc.delegate = self
        present(vc, animated: true)
    }
}

// MARK: - Host session delegate

extension HostVC: HostSessionDelegate {
    func didReceiveNALU(_ nalu: Data) {
        naluParser.enqueue(nalu)
    }
}

// MARK: - NALU parser delegate

extension HostVC: NALUParserDelegate {
    func didReceiveUnit(_ unit: H264Unit) {
        decoder.decode(unit)
    }
}

// MARK: - Decoder delegate

extension HostVC: H264DecoderDelegate {
    func didCreateBuffer(_ sbuf: CMSampleBuffer) {
        guard let bufferDisplayLayer else { return }
        bufferDisplayLayer.enqueue(sbuf)
        bufferDisplayLayer.setNeedsDisplay()
    }
}

// MARK: - Browser VC delegate

extension HostVC: PeerBrowserVCDelegate {
    func connectedConnections() -> [PeerConnection] {
        hostSession.peerConnections
    }
    
    func didConnect(to connection: PeerConnection) {
        hostSession.createNewConnection(connection, completionHandler: {_ in })
    }
}
