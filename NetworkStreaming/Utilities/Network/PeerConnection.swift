//
//  PeerConnection.swift
//  NetworkStreaming
//
//  Created by cleanmac on 05/10/23.
//

import Foundation
import Network

protocol PeerConnectionDelegate: AnyObject {
    /// Tells the delegate that a connection is ready.
    func connectionDidReady(_ connection: PeerConnection)
    
    /// Tells the delegate that a connection that a connection has failed.
    func connectionDidFailed(_ connection: PeerConnection, error: NWError)
    
    /// Tells the delegate that a connection has been cancelled.
    func connectionDidCancelled(_ connection: PeerConnection)
    
    /// Tells the delegate that a connection has received a message,
    /// - Parameters:
    ///   - content: The data that was recieved by the connection. Optional.
    ///   - message: The message that was recieved by the connection.
    func didReceiveMessage(_ connection: PeerConnection, content: Data?, message: NWProtocolFramer.Message)
    
    /// Tells the delegate that an error has been catched.
    /// - Parameter error: An error that was thrown during the connection.
    func didReceiveError(_ connection: PeerConnection, error: NWError)
}

final class PeerConnection {
    weak var delegate: PeerConnectionDelegate?
    
    private var interface: NWInterface?
    let endpoint: NWEndpoint?
    private let initiatedConnection: Bool
    private(set) var connection: NWConnection?
    private(set) var endpointName: String?
    
    init(endpoint: NWEndpoint, interface: NWInterface? = nil) {
        self.endpoint = endpoint
        self.interface = interface
        self.initiatedConnection = true
        
        if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = endpoint {
            self.endpointName = name
        }
        
        self.connection = NWConnection(to: endpoint, using: .customTcp())
    }
    
    init(connection: NWConnection) {
        self.connection = connection
        self.endpoint = connection.endpoint
        self.initiatedConnection = false
        
        if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = connection.endpoint {
            self.endpointName = name
        }
    }
    
    // MARK: - Public methods
    
    /// Starts the connection.
    func startConnection() {
        guard let connection else { return }
        
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            
            switch state {
            case .ready:
                self.receiveNextMessage()
                self.delegate?.connectionDidReady(self)
            case .failed(let error):
                connection.cancel()
                self.delegate?.connectionDidFailed(self, error: error)
            case .cancelled:
                self.delegate?.connectionDidCancelled(self)
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
    
    /// Stops the connection.
    func stopConnection() {
        connection?.cancelCurrentEndpoint()
        connection?.forceCancel()
    }
    
    /// Sends a data with a specific message type to the other receiving end.
    /// - Parameters:
    ///   - type: The message type of the data.
    ///   - data: The data that will be sent.
    func send(type: PeerMessageType, data: Data) {
        guard let connection else { fatalError("The connection is not exist.") }
        let messageFramer = NWProtocolFramer.Message(peerMessageType: type)
        let context = NWConnection.ContentContext(identifier: type.contentContextIdentifier, metadata: [messageFramer])
        
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    // MARK: - Private methods
    
    /// Receieve another message after receiving a message.
    private func receiveNextMessage() {
        guard let connection else { return }
        
        connection.receiveMessage { content, contentContext, isComplete, error in
            if let message = contentContext?.protocolMetadata(definition: PeerMessageProtocol.definition) as? NWProtocolFramer.Message {
                self.delegate?.didReceiveMessage(self, content: content, message: message)
            }
            
            if error == nil {
                self.receiveNextMessage()
            }
        }
    }
}

