import CoreGraphics
import CoreMedia
import CoreVideo
import Foundation
import os
import ScreenCaptureKit
import VideoToolbox

final class MJPEGStreamer: NSObject {
    typealias OutputHandler = @Sendable (Data, @escaping @Sendable (Error?) -> Void) -> Void

    // MARK: - Constants

    private static let queueDepth = 2
    private static let timescale: Int32 = 60
    private static let frameInterval = CMTime(value: 1, timescale: timescale)
    private static let pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange

    // MARK: - Properties

    private let displayID: Int
    private let outputHandler: OutputHandler

    // MARK: - State Management

    private struct SampleBufferBox: @unchecked Sendable {
        let buffer: CMSampleBuffer
    }

    private struct CompressionSessionBox: @unchecked Sendable {
        let session: VTCompressionSession
    }

    private struct State {
        var stream: SCStream?
        var captureTask: Task<Void, Never>?
        var isBusy = false
        var sampleBufferBox: SampleBufferBox?
        var compressionSessionBox: CompressionSessionBox?
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    // MARK: - Initialization

    init(displayID: Int, outputHandler: @escaping OutputHandler) {
        self.displayID = displayID
        self.outputHandler = outputHandler
    }

    deinit {
        stop()
    }

    // MARK: - Public

    func start() {
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await startCapture()
            } catch {
                guard !Task.isCancelled else { return }
                Logger.stream.error("Failed to start stream: \(error.localizedDescription, privacy: .public)")
            }
        }
        state.withLock { $0.captureTask = task }
    }

    func stop() {
        let (stream, sessionBox, task) = state.withLock { state -> (SCStream?, CompressionSessionBox?, Task<Void, Never>?) in
            let s = state.stream
            let c = state.compressionSessionBox
            let t = state.captureTask

            state.stream = nil
            state.captureTask = nil
            state.isBusy = false
            state.sampleBufferBox = nil
            state.compressionSessionBox = nil

            return (s, c, t)
        }

        task?.cancel()

        Logger.stream.info("Stopping stream for display \(self.displayID, privacy: .public)")

        if let stream {
            try? stream.removeStreamOutput(self, type: .screen)
            Task { try? await stream.stopCapture() }
        }

        if let session = sessionBox?.session {
            VTCompressionSessionInvalidate(session)
        }
    }

    // MARK: - Private: Capture Setup

    private func startCapture() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == self.displayID }) else {
            throw StreamError.displayNotFound(displayID)
        }

        let config = createStreamConfiguration(for: display)
        let filter = SCContentFilter(display: display, excludingWindows: [])

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))

        try await stream.startCapture()

        // Check cancellation before committing state
        try Task.checkCancellation()

        let (width, height) = (config.width, config.height)

        state.withLock { state in
            state.stream = stream

            var session: VTCompressionSession?
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
                compressionSessionOut: &session,
            )

            if status == noErr, let session {
                VTSessionSetProperty(session, key: kVTCompressionPropertyKey_Quality, value: Config.videoQuality as CFNumber)
                VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
                state.compressionSessionBox = CompressionSessionBox(session: session)
            } else {
                Logger.stream.error("Failed to create compression session: \(status, privacy: .public)")
            }
        }

        Logger.stream.info("Started capture for display \(self.displayID, privacy: .public)")
    }

    private func createStreamConfiguration(for display: SCDisplay) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()

        config.minimumFrameInterval = Self.frameInterval
        config.queueDepth = Self.queueDepth
        config.pixelFormat = Self.pixelFormat
        config.capturesAudio = false

        guard let mode = CGDisplayCopyDisplayMode(display.displayID) else { return config }

        let (width, height) = calculateDimensions(mode: mode)
        config.width = width
        config.height = height

        return config
    }

    private func calculateDimensions(mode: CGDisplayMode) -> (Int, Int) {
        let width = mode.pixelWidth
        let height = mode.pixelHeight

        guard Config.maxDimension > 0 else {
            return (width & ~1, height & ~1)
        }

        let scale = min(1.0, Double(Config.maxDimension) / Double(max(width, height)))
        return (Int(Double(width) * scale) & ~1, Int(Double(height) * scale) & ~1)
    }

    // MARK: - Private: MJPEG Compression

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
            Logger.stream.error("Encoding failed: \(status, privacy: .public)")
            processingFinished()
        }
    }

    private func processingFinished() {
        let (pendingFrame, sessionBox) = state.withLock { state -> (SampleBufferBox?, CompressionSessionBox?) in
            if Config.dropFramesWhenBusy, let pending = state.sampleBufferBox {
                state.sampleBufferBox = nil
                return (pending, state.compressionSessionBox)
            } else {
                state.isBusy = false
                return (nil, nil)
            }
        }

        if let pendingFrame, let session = sessionBox?.session {
            encode(pendingFrame.buffer, session: session)
        } else if pendingFrame != nil {
            // pending frame but no session, clear busy
            state.withLock { $0.isBusy = false }
        }
    }

    // MARK: - Internal Handling

    fileprivate func handleEncodedFrame(_ data: Data) {
        outputHandler(data) { [weak self] error in
            if let error {
                Logger.stream.error("Output failed: \(error.localizedDescription, privacy: .public)")
                self?.stop()
            }
            self?.processingFinished()
        }
    }

    fileprivate func handleEncodingError() {
        processingFinished()
    }
}

// MARK: - SCStreamOutput

extension MJPEGStreamer: SCStreamOutput {
    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        // Capture session inside lock to ensure thread safety
        let sampleBufferBox = SampleBufferBox(buffer: sampleBuffer)
        let (compressionSessionBox, shouldEncode) = state.withLock { state -> (CompressionSessionBox?, Bool) in
            guard type == .screen, let box = state.compressionSessionBox else { return (nil, false) }

            let dropFramesWhenBusy = Config.dropFramesWhenBusy

            if dropFramesWhenBusy, state.isBusy {
                state.sampleBufferBox = sampleBufferBox
                return (nil, false)
            }

            state.isBusy = true
            return (box, true)
        }

        if shouldEncode, let session = compressionSessionBox?.session {
            encode(sampleBuffer, session: session)
        }
    }
}

// MARK: - Compression Callback

private func compressionCallback(
    outputCallbackRefCon: UnsafeMutableRawPointer?,
    sourceFrameRefCon _: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags _: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?,
) {
    guard let refCon = outputCallbackRefCon else { return }
    let streamer = Unmanaged<MJPEGStreamer>.fromOpaque(refCon).takeUnretainedValue()

    guard status == noErr, let sampleBuffer, let data = sampleBuffer.createData() else {
        streamer.handleEncodingError()
        return
    }

    streamer.handleEncodedFrame(data)
}

// MARK: - Errors

private enum StreamError: Error {
    case displayNotFound(Int)
}
