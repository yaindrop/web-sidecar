import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import os
import ScreenCaptureKit
import VideoToolbox

class MJPEGStreamer: NSObject, SCStreamOutput {
    typealias OutputHandler = (Data, @escaping (Error?) -> Void) -> Void

    private let displayID: Int
    private let outputHandler: OutputHandler
    private var stream: SCStream?
    private var compressionSession: VTCompressionSession?

    // Concurrency control
    private struct SampleBufferBox: @unchecked Sendable {
        let buffer: CMSampleBuffer
    }

    private struct ProcessingState {
        var isBusy = false
        var pendingFrame: SampleBufferBox?
    }

    private let state = OSAllocatedUnfairLock(initialState: ProcessingState())

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
        Logger.log("Stopping stream for display \(displayID)")
        Task { try? await stream?.stopCapture() }

        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }

        state.withLock { state in
            state = ProcessingState()
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

        let sampleBufferBox = SampleBufferBox(buffer: sampleBuffer)
        let dropFramesWhenBusy = Config.dropFramesWhenBusy

        let shouldEncode: Bool = state.withLock { state in
            if dropFramesWhenBusy, state.isBusy {
                // If busy, store this frame as the pending one (replacing any previous pending one)
                state.pendingFrame = sampleBufferBox
                return false
            }

            state.isBusy = true
            return true
        }

        if shouldEncode {
            encode(sampleBuffer, session: session)
        }
    }

    private func encode(_ sampleBuffer: CMSampleBuffer, session: VTCompressionSession) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            processingFinished()
            return
        }

        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: imageBuffer,
            presentationTimeStamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            duration: CMSampleBufferGetDuration(sampleBuffer),
            frameProperties: nil,
            sourceFrameRefcon: nil,
            infoFlagsOut: nil,
        )

        if status != noErr {
            Logger.log("Encoding failed: \(status)")
            processingFinished()
        }
    }

    private func processingFinished() {
        let pendingFrame: SampleBufferBox? = state.withLock { state in
            if Config.dropFramesWhenBusy, let pending = state.pendingFrame {
                state.pendingFrame = nil
                return pending
            } else {
                state.isBusy = false
                return nil
            }
        }

        if let pendingFrame {
            if let session = compressionSession {
                encode(pendingFrame.buffer, session: session)
            } else {
                state.withLock { state in state.isBusy = false }
            }
        }
    }

    func handleEncodedFrame(_ data: Data) {
        outputHandler(data) { [weak self] error in
            if let error {
                Logger.log("Output failed: \(error)")
                self?.stop()
            }
            self?.processingFinished()
        }
    }

    func handleEncodingError() {
        processingFinished()
    }
}

func compressionCallback(outputCallbackRefCon: UnsafeMutableRawPointer?, sourceFrameRefCon _: UnsafeMutableRawPointer?, status: OSStatus, infoFlags _: VTEncodeInfoFlags, sampleBuffer: CMSampleBuffer?) {
    guard let refCon = outputCallbackRefCon else { return }
    let streamer = Unmanaged<MJPEGStreamer>.fromOpaque(refCon).takeUnretainedValue()

    guard status == noErr, let sampleBuffer, let data = sampleBuffer.createData() else {
        streamer.handleEncodingError()
        return
    }

    streamer.handleEncodedFrame(data)
}
