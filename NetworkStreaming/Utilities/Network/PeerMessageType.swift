//
//  PeerMessageType.swift
//  NetworkStreaming
//
//  Created by cleanmac on 13/10/23.
//

import Foundation

enum PeerMessageType: UInt32 {
    case invalid
    case message
    case videoData
    case disconnect
    
    var contentContextIdentifier: String {
        switch self {
        case .invalid:
            return "ContentContextIdentifierInvalid"
        case .message:
            return "ContentContextIdentifierMessage"
        case .videoData:
            return "ContentContextIdentifierVideoData"
        case .disconnect:
            return "ContentContextIdentifierDisconnect"
        }
    }
    
    var placeholderData: Data { Data() }
}
