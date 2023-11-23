//
//  H264Decoder.swift
//  NetworkStreaming
//
//  Created by cleanmac on 20/11/23.
//

import Foundation
import VideoToolbox

protocol H264DecoderDelegate: AnyObject {
    func didCreateBuffer(_ sbuf: CMSampleBuffer)
}

final class H264Decoder {
    weak var delegate: H264DecoderDelegate?
    
    private var sps: H264Unit?
    private var pps: H264Unit?
    
    private var formatDescription: CMVideoFormatDescription?
    
    private lazy var decodingQueue = DispatchQueue(label: "com.cleanrun.networkstreaming.decodingQueue", qos: .userInteractive)
    
    init(delegate: H264DecoderDelegate) {
        self.delegate = delegate
    }
    
    func decode(_ unit: H264Unit) {
        decodingQueue.async { [unowned self] in
            if unit.type == .sps || unit.type == .pps {
                formatDescription = nil
                createFormatDescription(using: unit)
                return
            } else {
                sps = nil
                pps = nil
            }
            
            guard let blockBuffer = createBlockBuffer(using: unit),
                  let sampleBuffer = createSampleBuffer(using: blockBuffer) else {
                print("\(#function): Block/Sample Buffer creation returns nil")
                return
            }
            
            delegate?.didCreateBuffer(sampleBuffer)
        }
    }
    
    // MARK: - Private methods
    
    private func createFormatDescription(using unit: H264Unit) {
        if unit.type == .sps {
            sps = unit
        } else if unit.type == .pps {
            pps = unit
        }
        
        guard let sps, let pps else {
            print("\(#function): SPS or PPS is nil")
            return
        }
        
        let spsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: sps.data.count)
        sps.data.copyBytes(to: spsPointer, count: sps.data.count)
        
        let ppsPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: pps.data.count)
        pps.data.copyBytes(to: ppsPointer, count: pps.data.count)
        
        let parameterSet = [UnsafePointer(spsPointer), UnsafePointer(ppsPointer)]
        let parameterSetSizes = [sps.data.count, pps.data.count]
        
        defer {
            parameterSet.forEach { $0.deallocate() }
        }
        
        CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault,
                                                            parameterSetCount: parameterSet.count,
                                                            parameterSetPointers: parameterSet,
                                                            parameterSetSizes: parameterSetSizes,
                                                            nalUnitHeaderLength: 4,
                                                            formatDescriptionOut: &formatDescription)
    }
    
    private func createBlockBuffer(using unit: H264Unit) -> CMBlockBuffer? {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: unit.data.count)
        
        unit.data.copyBytes(to: pointer, count: unit.data.count)
        var blockBuffer: CMBlockBuffer?
        
        let status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault,
                                                        memoryBlock: pointer,
                                                        blockLength: unit.data.count,
                                                        blockAllocator: kCFAllocatorDefault,
                                                        customBlockSource: nil,
                                                        offsetToData: 0,
                                                        dataLength: unit.data.count,
                                                        flags: .zero,
                                                        blockBufferOut: &blockBuffer)
        
        guard status == kCMBlockBufferNoErr else {
            print("\(#function): Block Buffer creation error with code = \(status)")
            return nil
        }
        
        return blockBuffer
    }
    
    private func createSampleBuffer(using bBuf: CMBlockBuffer) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo()
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.duration = .invalid
        timingInfo.presentationTimeStamp = .zero
        
        let status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                               dataBuffer: bBuf,
                                               formatDescription: formatDescription,
                                               sampleCount: 1,
                                               sampleTimingEntryCount: 1,
                                               sampleTimingArray: &timingInfo,
                                               sampleSizeEntryCount: 0,
                                               sampleSizeArray: nil,
                                               sampleBufferOut: &sampleBuffer)
        
        guard status == noErr, let sampleBuffer else {
            print("\(#function): Sample Buffer creation error with code = \(status)")
            return nil
        }
        
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        
        return sampleBuffer
    }
}
