import Foundation
import Network
import os

final class ConnectionManager: @unchecked Sendable {
    // MARK: - Properties

    private let id = UUID()

    private let connection: NWConnection
    private let requestHandler: RequestHandler

    // Serial queue for this connection to ensure sequential processing
    private let queue = DispatchQueue(label: "com.websidecar.connection")

    // Protect mutable state
    private let lock = OSAllocatedUnfairLock()
    private var _onClose: (@Sendable () -> Void)?

    var onClose: (@Sendable () -> Void)? {
        get { lock.withLock { _onClose } }
        set { lock.withLock { _onClose = newValue } }
    }

    // MARK: - Initialization

    init(connection: NWConnection) {
        self.connection = connection
        requestHandler = RequestHandler(connection: connection)

        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            let id = id
            switch state {
            case .ready:
                Log.connection.debug("[\(id)] State: Ready")
            case let .waiting(error):
                Log.connection.warning("[\(id)] State: Waiting - \(error.localizedDescription)")
            case let .failed(error):
                Log.connection.error("[\(id)] State: Failed - \(error.localizedDescription)")
                handleClose()
            case .cancelled:
                Log.connection.debug("[\(id)] State: Cancelled")
                handleClose()
            default:
                break
            }
        }
    }

    // MARK: - Public API

    func start() {
        Log.connection.info("[\(id)] Client connected from \(connection.endpoint.debugDescription)")
        connection.start(queue: queue)
        readRequest()
    }

    // MARK: - Private: Reading

    private func readRequest() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let self, let data, !data.isEmpty else {
                self?.connection.cancel()
                return
            }

            if let requestString = String(data: data, encoding: .utf8) {
                parseAndHandle(requestString)
            } else {
                connection.cancel()
            }
        }
    }

    // MARK: - Private: Handling

    private func parseAndHandle(_ request: String) {
        let components = request.components(separatedBy: "\r\n\r\n")
        let headerPart = components.first ?? ""
        let body = components.count > 1 ? components[1] : nil

        let lines = headerPart.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { connection.cancel(); return }
        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { connection.cancel(); return }

        requestHandler.handle(method: parts[0], path: parts[1], body: body)

        // Keep reading to detect when client closes connection
        waitForClose()
    }

    private func waitForClose() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] _, _, isComplete, error in
            guard let self else { return }

            if isComplete || error != nil {
                if let error {
                    Log.connection.error("[\(id)] Receive error: \(error.localizedDescription)")
                } else {
                    Log.connection.info("[\(id)] Client closed connection gracefully")
                }
                connection.cancel()
                return
            }

            waitForClose()
        }
    }

    private func handleClose() {
        requestHandler.stop()
        onClose?()
    }
}
