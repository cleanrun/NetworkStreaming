//
//  NALUParser.swift
//  NetworkStreaming
//
//  Created by cleanmac on 22/11/23.
//

import Foundation
import NIOCore

protocol NALUParserDelegate: AnyObject {
    func didReceiveUnit(_ unit: H264Unit)
}

final class NALUParser {
    weak var delegate: NALUParserDelegate?
    
    @available(*, deprecated, message: "Parsing using Data based payload is deprecated. Use Circular buffer based methods instead.")
    private var dataStream = Data()
    
    private var searchIndex = 0
    private lazy var parsingQueue = DispatchQueue(label: "com.cleanrun.networkstreaming.parsingQueue", qos: .userInteractive)
    
    init(delegate: NALUParserDelegate) {
        self.delegate = delegate
    }
    
    @available(*, deprecated, message: "Parsing using Data based payload is deprecated. Use Circular buffer based methods instead.")
    func enqueue(_ data: Data) {
        parsingQueue.async { [unowned self] in
            dataStream.append(data)
            
            while searchIndex < dataStream.endIndex-3 {
                if dataStream[searchIndex] | dataStream[searchIndex+1] | dataStream[searchIndex+2] | dataStream[searchIndex+3] == 1 {
                    
                    if searchIndex != 0 {
                        let unit = H264Unit(from: dataStream[0..<searchIndex])
                        delegate?.didReceiveUnit(unit)
                    }
                    
                    dataStream.removeSubrange(0...searchIndex+3)
                    //dataStream.removeFirst(4)
                    searchIndex = 0
                } else if dataStream[searchIndex+3] != 0 {
                    searchIndex += 4
                } else {
                    searchIndex += 1
                }
            }
        }
    }
    
    func enqueue(_ cbuf: CircularBuffer<UInt8>) {
        parsingQueue.async { [unowned self] in
            autoreleasepool {
                var mutableBuffer = cbuf
                if mutableBuffer[offset: 0] | mutableBuffer[offset: 1] |
                    mutableBuffer[offset: 2] |
                    mutableBuffer[offset: 3] == 1
                {
                    mutableBuffer.removeFirst(4)
                    let payload = Data(mutableBuffer)
                    self.delegate?.didReceiveUnit(H264Unit(from: payload))
                }
            }
        }
    }
    
}
