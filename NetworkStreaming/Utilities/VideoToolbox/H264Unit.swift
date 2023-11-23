//
//  H264Unit.swift
//  NetworkStreaming
//
//  Created by cleanmac on 22/11/23.
//

import Foundation

struct H264Unit {
    enum NALUType {
        case sps
        case pps
        case vcl
    }
    
    let type: NALUType
    
    private let payload: Data
    private var dataLength: Data?
    
    var data: Data {
        if type == .vcl {
            return dataLength! + payload
        } else {
            return payload
        }
    }
    
    init(from payload: Data) {
        let typeNumber = payload.first! & 0x1F
        
        if typeNumber == 7 {
            self.type = .sps
        } else if typeNumber == 8 {
            self.type = .pps
        } else {
            self.type = .vcl
            
            var naluLength = UInt32(payload.count)
            naluLength = CFSwapInt32HostToBig(naluLength)
            
            self.dataLength = Data(bytes: &naluLength, count: 4)
        }
        
        self.payload = payload
    }
}
