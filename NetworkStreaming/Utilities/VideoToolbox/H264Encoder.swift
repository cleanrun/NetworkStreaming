//
//  H264Encoder.swift
//  NetworkStreaming
//
//  Created by cleanmac on 20/11/23.
//

import Foundation
import VideoToolbox

protocol H264EncoderDelegate: AnyObject {
    func didReceiveNALU(_ naluData: Data)
}

final class H264Encoder: NSObject {
    private weak var delegate: H264EncoderDelegate?
    
    enum EncoderError: Error {
        case createSessionError
        case setPropertiesError
        case prepareToEncodeFailed
    }
    
    private var compressionSession: VTCompressionSession!
    private static let naluStartCode = Data([UInt8](arrayLiteral: 0x00, 0x00, 0x00, 0x01))
    
    private lazy var encodingQueue = DispatchQueue(label: "com.cleanrun.networkstreaming.encodingQueue", qos: .userInitiated)
    
    init(delegate: H264EncoderDelegate) throws {
        self.delegate = delegate
        super.init()
        try configureCompressionSession()
    }
    
    private var encodingOutputCallback: VTCompressionOutputCallback = { outputCallbackRefcon, _, status, flags, sampleBuffer in
        guard let sampleBuffer else {
            print("\(#function): Sample buffer is nil")
            return
        }
        
        guard let outputCallbackRefcon else {
            print("\(#function): Encoder pointer is nil")
            return
        }
        
        guard status == noErr else {
            print("\(#function): Encoding failed with error code = \(status)")
            return
        }
        
        guard CMSampleBufferDataIsReady(sampleBuffer) else {
            print("\(#function): Sample buffer is not ready")
            return
        }
        
        guard flags != VTEncodeInfoFlags.frameDropped else {
            print("\(#function): Frame is dropped")
            return
        }
        
        let encoder: H264Encoder = Unmanaged<H264Encoder>.fromOpaque(outputCallbackRefcon).takeUnretainedValue()
        
        if sampleBuffer.isKeyFrame {
            encoder.extractSPSandPPS(from: sampleBuffer)
        }
        
        guard let dataBuffer = sampleBuffer.dataBuffer else {
            print("\(#function): Data buffer is nil")
            return
        }
        
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        let error = CMBlockBufferGetDataPointer(dataBuffer,
                                                atOffset: 0,
                                                lengthAtOffsetOut: nil,
                                                totalLengthOut: &totalLength,
                                                dataPointerOut: &dataPointer)
        
        guard error == kCMBlockBufferNoErr, let dataPointer else {
            print("\(#function): Data pointer is nil")
            return
        }
        
        var packageStartIndex = 0
        
        while packageStartIndex < totalLength {
            var nextNALULength: UInt32 = 0
            memcpy(&nextNALULength, dataPointer.advanced(by: packageStartIndex), 4)
            
            nextNALULength = CFSwapInt32BigToHost(nextNALULength)
            
            var nalu = Data(bytes: dataPointer.advanced(by: packageStartIndex + 4), count: Int(nextNALULength))
            
            packageStartIndex += (4 + Int(nextNALULength))
            
            encoder.delegate?.didReceiveNALU(H264Encoder.naluStartCode + nalu)
        }
    }
    
    func encode(_ buffer: CMSampleBuffer) {
        encodingQueue.async { [unowned self] in
            guard let compressionSession,
                  let imageBuffer = CMSampleBufferGetImageBuffer(buffer)
            else { return }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(buffer)
            let duration = CMSampleBufferGetDuration(buffer)
            
            VTCompressionSessionEncodeFrame(compressionSession,
                                            imageBuffer: imageBuffer,
                                            presentationTimeStamp: timestamp,
                                            duration: duration,
                                            frameProperties: nil,
                                            sourceFrameRefcon: nil,
                                            infoFlagsOut: nil)
        }
    }
    
    // MARK: - Private methods
    
    private func configureCompressionSession() throws {
        let error = VTCompressionSessionCreate(allocator: kCFAllocatorDefault,
                                               width: Int32(720),
                                               height: Int32(1280),
                                               codecType: kCMVideoCodecType_H264,
                                               encoderSpecification: nil,
                                               imageBufferAttributes: nil,
                                               compressedDataAllocator: kCFAllocatorDefault,
                                               outputCallback: encodingOutputCallback, refcon: Unmanaged.passUnretained(self).toOpaque(),
                                               compressionSessionOut: &compressionSession)
        
        guard error == errSecSuccess, let compressionSession else {
            throw EncoderError.createSessionError
        }
        
        let propertyDictionary = [
            kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Baseline_AutoLevel,
            kVTCompressionPropertyKey_MaxKeyFrameInterval: 60,
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_Quality: 0.5,
        ] as CFDictionary
        
        guard VTSessionSetProperties(compressionSession, propertyDictionary: propertyDictionary) == noErr else {
            throw EncoderError.setPropertiesError
        }
        
        guard VTCompressionSessionPrepareToEncodeFrames(compressionSession) == noErr else {
            throw EncoderError.prepareToEncodeFailed
        }
    }
    
    private func extractSPSandPPS(from buffer: CMSampleBuffer) {
        guard let description = CMSampleBufferGetFormatDescription(buffer) else {
            print("\(#function): Format description is nil")
            return
        }
        
        var parameterSetCount = 0
        
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: &parameterSetCount,
                                                           nalUnitHeaderLengthOut: nil)
        
        guard parameterSetCount == 2 else {
            print("\(#function): Parameter set count is not the same as 2, so no SPS and PPS that needs to be extracted.")
            return
        }
        
        var spsSize: Int = 0
        var sps: UnsafePointer<UInt8>?
        
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: &sps,
                                                           parameterSetSizeOut: &spsSize,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: nil)
        
        var ppsSize: Int = 0
        var pps: UnsafePointer<UInt8>?
        
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 1,
                                                           parameterSetPointerOut: &pps,
                                                           parameterSetSizeOut: &ppsSize,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: nil)
        
        guard let sps, let pps else {
            print("\(#function): SPS/PPS is nil")
            return
        }
        
        let parameterDatas = [Data(bytes: sps, count: spsSize), Data(bytes: pps, count: ppsSize)]
        
        parameterDatas.forEach {
            delegate?.didReceiveNALU(H264Encoder.naluStartCode + $0)
        }
    }
}
