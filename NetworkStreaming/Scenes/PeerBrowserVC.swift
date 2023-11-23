//
//  PeerBrowserVC.swift
//  NetworkStreaming
//
//  Created by cleanmac on 23/11/23.
//

import UIKit
import Network
import Combine

protocol PeerBrowserVCDelegate: AnyObject {
    func connectedConnections() -> [PeerConnection]
    func didConnect(to connection: PeerConnection)
}

final class PeerBrowserVC: UIViewController {
    private lazy var resultTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()
    
    weak var delegate: PeerBrowserVCDelegate?
    
    private var hostSession: HostSession
    private var peerResults: [NWBrowser.Result] = []
    private var name = "Default"
    
    private var disposables = Set<AnyCancellable>()
    
    init(using hostSession: HostSession) {
        self.hostSession = hostSession
        self.peerResults = hostSession.peerResults
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        view.backgroundColor = .systemBackground
        
        view.addSubview(resultTableView)
        
        NSLayoutConstraint.activate([
            resultTableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            resultTableView.rightAnchor.constraint(equalTo: view.rightAnchor),
            resultTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            resultTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        resultTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ResultCell")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hostSession.$peerResults.receive(on: DispatchQueue.main).sink { [weak self] value in
            self?.peerResults = value
            self?.resultTableView.reloadData()
        }.store(in: &disposables)
    }
    
    private func createNewConnection(for result: NWBrowser.Result) {
        let newConnection = PeerConnection(endpoint: result.endpoint, interface: result.interfaces.first)
        delegate?.didConnect(to: newConnection)
        dismiss(animated: true)
    }
}

// MARK: - Table view delegate and data source

extension PeerBrowserVC: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        peerResults.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Available Peers"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ResultCell")!
        
        let peerEndpoint = peerResults[indexPath.row].endpoint
        if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = peerEndpoint {
            cell.textLabel?.text = name
            cell.textLabel?.textColor = .label
            
            if let delegate, delegate.connectedConnections().firstIndex(where: { $0.endpointName == name }) != nil {
                cell.textLabel?.text = name + " (Connected)"
                cell.textLabel?.textColor = .lightGray
            }
        } else {
            cell.textLabel?.text = "Unknown Endpoint"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let peerEndpoint = peerResults[indexPath.row].endpoint
            if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = peerEndpoint {
                if delegate?.connectedConnections().firstIndex(where: { $0.endpointName == name }) == nil {
                    createNewConnection(for: peerResults[indexPath.row])
                }
            }
        }
    }
}
