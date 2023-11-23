//
//  NWParameters+Extension.swift
//  NetworkStreaming
//
//  Created by cleanmac on 11/10/23.
//

import Network

extension NWParameters {
    /// Returns a custom TCP parameter that uses a custom `NWProtocolFramer.Defintition` and peer-to-peer capabilities.
    static func customTcp() -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 2
        
        let parameter = NWParameters(tls: nil, tcp: tcpOptions)
        parameter.includePeerToPeer = true
        
        let protocolOptions = NWProtocolFramer.Options(definition: PeerMessageProtocol.definition)
        parameter.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
        
        return parameter
    }
    
}
