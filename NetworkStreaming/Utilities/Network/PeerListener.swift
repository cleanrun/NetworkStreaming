//
//  PeerListener.swift
//  NetworkStreaming
//
//  Created by cleanmac on 05/10/23.
//

import Network

protocol PeerListenerDelegate: AnyObject {
    /// Tells the delegate that the listener is ready to listen for available connections.
    /// - Parameter listener: The listener object that has been established.
    func listenerDidReady(_ listener: NWListener)
    
    /// Tells the delegate that the listener has failed to listen for available connections.
    /// - Parameter error: The error that was produced.
    func listenerDidFailed(_ error: NWError)
    
    /// Tells the delegate that the listener cancelled to listen for available connections.
    func listenerDidCancelled()
}

final class PeerListener {
    private weak var delegate: PeerListenerDelegate?
    private var listener: NWListener?
    private var name: String?
    
    init(name: String, delegate: PeerListenerDelegate) {
        self.delegate = delegate
        self.name = name
    }
    
    // MARK: - Public functions
    
    /// Sets up the listener.
    func setupListener() throws {
        guard let name else { return }
        
        let listener = try NWListener(using: .customTcp())
        self.listener = listener
        
        listener.service = NWListener.Service(name: name, type: BONJOUR_SERVICE_IDENTIFIER)
    }
    
    /// Start listening for peer connections.
    ///
    /// To start listening, you must make sure that you already setup the listener by calling `setupListener()`. Otherwise the listener might not be instantiated and this function will throw an error.
    /// - Parameter completionHandler: A closure to handle when a new connection has been established.
    func startListening(_ completionHandler: @escaping ((NWConnection) -> Void)) {
        guard let listener else { fatalError("The listener object doesn't exist. Make sure to call `setupListener()` before start listening.") }
        
        listener.stateUpdateHandler = listenerStateChanged
        
        listener.newConnectionHandler = { newConnection in
            completionHandler(newConnection)
        }
        
        listener.start(queue: .global())
    }
    
    /// Stop listening for peer connections.
    func stopListening() {
        if let listener {
            listener.cancel()
            self.listener = nil
        }
    }
    
    /// Reset the listener service name.
    /// - Parameter name: The name to reset.
    func resetName(_ name: String) {
        self.name = name
        listener?.service = NWListener.Service(name: name, type: BONJOUR_SERVICE_IDENTIFIER)
    }
    
    // MARK: - Private functions
    
    private func listenerStateChanged(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            delegate?.listenerDidReady(listener!)
        case .failed(let error):
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print("\(#function); Listener failed with \(error), restarting")
                listener?.cancel()
                try? setupListener()
            } else {
                delegate?.listenerDidFailed(error)
                listener?.cancel()
            }
        case .cancelled:
            listener = nil
        default:
            break
        }
    }
}
