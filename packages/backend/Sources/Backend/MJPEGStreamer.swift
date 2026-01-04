import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import ScreenCaptureKit
import VideoToolbox

class MJPEGStreamer: NSObject, SCStreamOutput {
    typealias OutputHandler = (Data, @escaping (Error?) -> Void) -> Void

    private let displayID: Int
    private let outputHandler: OutputHandler
    private var stream: SCStream?
    private var compressionSession: VTCompressionSession?

    // Backpressure: 1 = free, 0 = busy
    private let processingSemaphore = DispatchSemaphore(value: 1)

    init(displayID: Int, outputHandler: @escaping OutputHandler) {
        self.displayID = displayID
        self.outputHandler = outputHandler
    }

    func start() {
        Task {
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first(where: { $0.displayID == self.displayID }) else {
                    Logger.log("Display \(displayID) not found")
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = createStreamConfiguration(for: display)

                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
                try await stream?.startCapture()
                Logger.log("Started capture for display \(displayID)")

                setupCompressionSession(width: config.width, height: config.height)
            } catch {
                Logger.log("Failed to start stream: \(error)")
            }
        }
    }

    private func createStreamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        guard let mode = CGDisplayCopyDisplayMode(display.displayID) else { return config }

        // Calculate scale factor to fit within maxDimension while maintaining aspect ratio
        let width = mode.pixelWidth
        let height = mode.pixelHeight
        let scale: Double = if Config.maxDimension > 0 {
            min(1.0, Double(Config.maxDimension) / Double(max(width, height)))
        } else {
            1.0
        }

        // Apply scale and ensure dimensions are even (required for most video encoders)
        config.width = Int(Double(width) * scale) & ~1
        config.height = Int(Double(height) * scale) & ~1

        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 2
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.capturesAudio = false

        return config
    }

    func stop() {
        Task { try? await stream?.stopCapture() }
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }

    private func setupCompressionSession(width: Int, height: Int) {
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_JPEG,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: compressionCallback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &compressionSession,
        )

        if status != noErr {
            Logger.log("Failed to create compression session: \(status)")
            return
        }

        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_Quality, value: Config.videoQuality as CFNumber)
        VTSessionSetProperty(compressionSession!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
    }

    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let session = compressionSession else { return }

        if processingSemaphore.wait(timeout: .now()) != .success { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            processingSemaphore.signal()
            return
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil,
        )

        if status != noErr {
            Logger.log("Encoding failed: \(status)")
            processingSemaphore.signal()
        }
    }

    func handleEncodedFrame(_ data: Data) {
        outputHandler(data) { [weak self] error in
            self?.processingSemaphore.signal()
            if let error {
                Logger.log("Output failed: \(error)")
                self?.stop()
            }
        }
    }

    func handleEncodingError() {
        processingSemaphore.signal()
    }
}

func compressionCallback(outputCallbackRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon _: UnsafeMutableRawPointer?, status: OSStatus, infoFlags _: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
    guard let refCon = outputCallbackRefCon else { return }
    let encoder = Unmanaged<MJPEGStreamer>.fromOpaque(refCon).takeUnretainedValue()

    guard status == noErr, let sampleBuffer, let data = sampleBuffer.createData() else {
        encoder.handleEncodingError()
        return
    }

    encoder.handleEncodedFrame(data)
}
