//
//  HostSession.swift
//  NetworkStreaming
//
//  Created by cleanmac on 23/11/23.
//

import Foundation
import Combine
import Network

protocol HostSessionDelegate: AnyObject {
    func didReceiveNALU(_ nalu: Data)
}

final class HostSession: ObservableObject {
    private weak var delegate: HostSessionDelegate?
    
    private(set) var peerBrowser: PeerBrowser!
    
    @Published private(set) var peerConnections: [PeerConnection] = []
    @Published private(set) var peerResults: [NWBrowser.Result] = []
    
    private let name = "Default"
    
    init(delegate: HostSessionDelegate) {
        self.delegate = delegate
        peerBrowser = PeerBrowser(delegate: self)
    }
    
    // MARK: - Public functions
    
    /// Creates and appends a new connection for a remote peer.
    /// - Parameters:
    ///   - connection: The newly established peer connection.
    ///   - completionHandler: A completion block to handle post appending connection.
    func createNewConnection(_ connection: PeerConnection, completionHandler: (PeerConnection) -> Void) {
        connection.delegate = self
        connection.startConnection()
        peerConnections.append(connection)
        completionHandler(connection)
    }
    
    /// Removes and closes a connection for a remote peer.
    /// - Parameters:
    ///   - connection: The connection to close.
    ///   - completionHandler: A completion block to handle post closing connection.
    func removeConnection(_ connection: PeerConnection, completionHandler: (PeerConnection) -> Void) {
        connection.delegate = nil
        connection.stopConnection()
        peerConnections.removeAll(where: { $0.endpointName == connection.endpointName })
        completionHandler(connection)
    }
    
    /// Stops browsing for peers and removes all connected connection.
    func immediatelyCloseAllConnection() {
        peerBrowser.stopBrowsing()
        peerConnections.forEach { connection in
            connection.delegate = nil
            connection.stopConnection()
        }
        peerConnections.removeAll()
        peerBrowser = nil
    }
    
    /// Broadcasts a command to all connected peer.
    /// - Parameters:
    ///   - type: The message/command type.
    ///   - data: The data of the message/command.
    func broadcastMessage(type: PeerMessageType, data: Data) {
        peerConnections.forEach { connection in
            connection.send(type: type, data: data)
        }
    }
    
    /// Sends a disconnect notification to all connected peers.
    /// - Parameter completionHandler: A completion block to handle post disconnect notification.
    func sendDisconnectNotificationToAllPeers(completionHandler: () -> Void = {}) {
        let disconnectData = "Disconnect".data(using: .utf8)!
        broadcastMessage(type: .disconnect, data: disconnectData)
        completionHandler()
    }
    
    /// Sends a disconnect notification to a specific peer.
    /// - Parameter peerEndpointName: The endpoint name of the peer to disconnect.
    /// - Returns: Returns the connection of the disconnected peer.
    @discardableResult func sendDisconnectNotification(peerEndpointName: String) -> PeerConnection? {
        guard let connection = peerConnections.first(where: { $0.endpointName == peerEndpointName }) else { return nil }
        
        let disconnectData = "Disconnect".data(using: .utf8)!
        connection.send(type: .disconnect, data: disconnectData)
        
        return connection
    }
}

// MARK: - Peer Connection delegate

extension HostSession: PeerConnectionDelegate {
    func connectionDidReady(_ connection: PeerConnection) {
        print("MM: Network callback; \(#function)")
    }
    
    func connectionDidFailed(_ connection: PeerConnection, error: NWError) {
        print("MM: Network callback; \(#function)")
    }
    
    func connectionDidCancelled(_ connection: PeerConnection) {
        print("MM: Network callback; \(#function)")
    }
    
    func didReceiveMessage(_ connection: PeerConnection, content: Data?, message: NWProtocolFramer.Message) {
        guard let content else { return }
        
        let messageType = message.peerMessageType
        
        switch messageType {
        case .videoData:
            delegate?.didReceiveNALU(content)
        default:
            break
        }
    }
    
    func didReceiveError(_ connection: PeerConnection, error: NWError) {
        print("MM: Network callback; \(#function)")
    }
}

// MARK: - Peer Browser Delegate

extension HostSession: PeerBrowserDelegate {
    func didRefreshResults(_ results: Set<NWBrowser.Result>) {
        var tempPeerResults = [NWBrowser.Result]()
        for result in results {
            if case let NWEndpoint.service(name: name, type: _, domain: _, interface: _) = result.endpoint {
                if name != self.name {
                    tempPeerResults.append(result)
                }
            }
        }
        
        peerResults = tempPeerResults
    }
    
    func didReceiveError(_ error: NWError) {
        print("MM: PeerBrowserDelegate \(#function); \(error.localizedDescription)")
    }
}


