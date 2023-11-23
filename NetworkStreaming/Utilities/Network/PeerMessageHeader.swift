//
//  PeerMessageHeader.swift
//  NetworkStreaming
//
//  Created by cleanmac on 11/10/23.
//

import Foundation

struct PeerMessageHeader: Codable {
    let type: UInt32
    let length: UInt32
    
    var encodedData: Data {
        var tempType = type
        var tempLength = length
        var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
        data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
        return data
    }
    
    static var encodedSize: Int { MemoryLayout<UInt32>.size * 2 }
    
    init(type: UInt32, length: UInt32) {
        self.type = type
        self.length = length
    }
    
    init(buffer: UnsafeMutableRawBufferPointer) {
        var tempType: UInt32 = 0
        var tempLength: UInt32 = 0
        withUnsafeMutableBytes(of: &tempType) { typePointer in
            typePointer.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0), count: MemoryLayout<UInt32>.size))
        }
        withUnsafeMutableBytes(of: &tempLength) { lengthPointer in
            lengthPointer.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size), count: MemoryLayout<UInt32>.size))
        }
        type = tempType
        length = tempLength
    }
}
