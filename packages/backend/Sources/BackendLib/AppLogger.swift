import Foundation
import os

public enum Log {
    public struct Wrapper: Sendable {
        let logger: os.Logger
        let category: String

        init(category: String) {
            self.category = category
            let subsystem = Bundle.main.bundleIdentifier ?? "com.yaindrop.websidecar"
            logger = os.Logger(subsystem: subsystem, category: category)
        }

        private func timestamp() -> String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: Date())
        }

        public func info(_ message: String) {
            print("\(timestamp()) [\(category)] [INFO] \(message)")
            logger.info("\(message, privacy: .public)")
        }

        public func debug(_ message: String) {
            print("\(timestamp()) [\(category)] [DEBUG] \(message)")
            logger.debug("\(message, privacy: .public)")
        }

        public func warning(_ message: String) {
            print("\(timestamp()) [\(category)] [WARN] \(message)")
            logger.warning("\(message, privacy: .public)")
        }

        public func error(_ message: String) {
            print("\(timestamp()) [\(category)] [ERROR] \(message)")
            logger.error("\(message, privacy: .public)")
        }

        public func critical(_ message: String) {
            print("\(timestamp()) [\(category)] [CRITICAL] \(message)")
            logger.critical("\(message, privacy: .public)")
        }

        public func log(_ message: String) {
            print("\(timestamp()) [\(category)] [LOG] \(message)")
            logger.log("\(message, privacy: .public)")
        }
    }

    public static let server = Wrapper(category: "server")
    public static let connection = Wrapper(category: "connection")
    public static let stream = Wrapper(category: "stream")
    public static let config = Wrapper(category: "config")
    public static let request = Wrapper(category: "request")
    public static let general = Wrapper(category: "general")
}
