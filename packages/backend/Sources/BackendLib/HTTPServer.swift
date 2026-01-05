import Foundation
import Network
import os

public class HTTPServer {
    let listener: NWListener
    var connections: [ObjectIdentifier: ConnectionManager] = [:]

    public init(port: UInt16) throws {
        let params = NWParameters.tcp
        let options = NWProtocolTCP.Options()
        options.enableKeepalive = true
        options.noDelay = true
        params.defaultProtocolStack.transportProtocol = options

        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    public func start() {
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                Log.server.info("Server started on port \(Config.port)")
                self.printIPs()
            case let .failed(error):
                Log.server.critical("Server failed: \(error.localizedDescription)")
                exit(1)
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            let manager = ConnectionManager(connection: connection)
            let id = ObjectIdentifier(manager)
            self?.connections[id] = manager

            manager.onClose = { [weak self] in
                self?.connections.removeValue(forKey: id)
            }

            manager.start()
        }

        listener.start(queue: .main)
    }

    private func printIPs() {
        print("http://localhost:\(Config.port)")
        if let hostname = ProcessInfo.processInfo.hostName.split(separator: ".").first {
            print(" `http://\(hostname):\(Config.port)` ")
        }
    }
}
