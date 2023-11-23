//
//  PeerBrowser.swift
//  NetworkStreaming
//
//  Created by cleanmac on 05/10/23.
//

import Network

protocol PeerBrowserDelegate: AnyObject {
    /// Tells the delegate that a new browser result exists.
    ///
    /// Use this method to refresh the list of available peers to connect, like the UI list components, etc.
    /// - Parameter results: The new peer results that was captured by the browser.
    func didRefreshResults(_ results: Set<NWBrowser.Result>)
    
    /// Tells the delegate that an error has been catched.
    /// - Parameter error: An error that was thrown during the browsing process.
    func didReceiveError(_ error: NWError)
}

final class PeerBrowser {
    private weak var delegate: PeerBrowserDelegate?
    private var browser: NWBrowser!
    
    init(delegate: PeerBrowserDelegate) {
        self.delegate = delegate
        
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        self.browser = NWBrowser(for: .bonjour(type: BONJOUR_SERVICE_IDENTIFIER, domain: nil), using: parameters)
    }
    
    /// Starts to browse for available peers.
    func startBrowsing() {
        browser.stateUpdateHandler = { state in
            switch state {
            case .failed(let error):
                if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                    self.browser.cancel()
                    self.startBrowsing()
                } else {
                    self.delegate?.didReceiveError(error)
                    self.browser.cancel()
                }
            case .ready:
                self.delegate?.didRefreshResults(self.browser.browseResults)
            case .cancelled:
                self.delegate?.didRefreshResults(Set())
                self.browser.cancel()
            default:
                break
            }
        }
        
        browser.browseResultsChangedHandler = { results, _ in
            self.delegate?.didRefreshResults(results)
        }
        
        browser.start(queue: .global())
    }
    
    /// Stops browsing for available peers.
    func stopBrowsing() {
        browser.cancel()
    }
}
