//
//  PeerMessageProtocol.swift
//  NetworkStreaming
//
//  Created by cleanmac on 05/10/23.
//

import Network

final class PeerMessageProtocol: NWProtocolFramerImplementation {
    static let definition = NWProtocolFramer.Definition(implementation: PeerMessageProtocol.self)
    static var label: String { "NWP2P" }
    
    init(framer: NWProtocolFramer.Instance) {}
    
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func cleanup(framer: NWProtocolFramer.Instance) {}
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader: PeerMessageHeader? = nil
            let headerSize = PeerMessageHeader.encodedSize
            let parsed = framer.parseInput(minimumIncompleteLength: headerSize, maximumLength: headerSize, parse: { buffer, isComplete in
                guard let buffer else { return 0 }
                
                if buffer.count < headerSize {
                    return 0
                }
                
                tempHeader = PeerMessageHeader(buffer: buffer)
                return headerSize
            })
            
            guard parsed, let tempHeader else { return headerSize }
            
            var messageType = PeerMessageType.invalid
            if let parsedMessageType = PeerMessageType(rawValue: tempHeader.type) {
                messageType = parsedMessageType
            }
            let message = NWProtocolFramer.Message(peerMessageType: messageType)
            
            if !framer.deliverInputNoCopy(length: Int(tempHeader.length), message: message, isComplete: true) {
                return 0
            }
        }
    }
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        let type = message.peerMessageType
        
        let header = PeerMessageHeader(type: type.rawValue, length: UInt32(messageLength))
        
        framer.writeOutput(data: header.encodedData)
        
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            print("\(#function); Writing message error \(error.localizedDescription)")
        }
    }
    
}
