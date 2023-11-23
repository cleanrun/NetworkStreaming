//
//  NWProtocolFramer.Message+Extension.swift
//  NetworkStreaming
//
//  Created by cleanmac on 13/10/23.
//

import Network

extension NWProtocolFramer.Message {
    convenience init(peerMessageType: PeerMessageType) {
        self.init(definition: PeerMessageProtocol.definition)
        self["PeerMessageType"] = peerMessageType
    }

    var peerMessageType: PeerMessageType {
        if let type = self["PeerMessageType"] as? PeerMessageType {
            return type
        } else {
            return .invalid
        }
    }
}
