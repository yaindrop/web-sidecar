import CoreMedia
import Foundation

extension CMSampleBuffer {
    func createData() -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(self) else { return nil }
        let totalLength = CMBlockBufferGetDataLength(dataBuffer)
        if totalLength == 0 { return Data() }

        var data = Data(count: totalLength)
        let status = data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return OSStatus(-1) }
            return CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: totalLength, destination: baseAddress)
        }

        guard status == noErr else { return nil }
        return data
    }
}
