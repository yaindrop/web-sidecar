import Foundation
import os

public extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.yaindrop.websidecar"

    static let server = Logger(subsystem: subsystem, category: "server")
    static let connection = Logger(subsystem: subsystem, category: "connection")
    static let stream = Logger(subsystem: subsystem, category: "stream")
    static let config = Logger(subsystem: subsystem, category: "config")
    static let request = Logger(subsystem: subsystem, category: "request")
    static let general = Logger(subsystem: subsystem, category: "general")
}
