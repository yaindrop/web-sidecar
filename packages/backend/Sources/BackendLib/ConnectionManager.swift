import Foundation
import Network

class ConnectionManager {
    let connection: NWConnection
    let requestHandler: RequestHandler
    var onClose: (() -> Void)?

    init(connection: NWConnection) {
        self.connection = connection
        requestHandler = RequestHandler(connection: connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(_), .cancelled:
                self?.requestHandler.stop()
                self?.onClose?()
            default:
                break
            }
        }
    }

    func start() {
        Logger.log("Client connected: \(connection.endpoint)")
        connection.start(queue: .global(qos: .userInteractive))
        readRequest()
    }

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
                Logger.log("Client closed connection: \(isComplete), \(error?.localizedDescription ?? "no error")")
                connection.cancel()
                return
            }

            waitForClose()
        }
    }
}
