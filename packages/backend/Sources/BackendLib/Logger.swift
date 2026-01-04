import Foundation

public enum Logger {
    public static func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let logMessage = "[\(formatter.string(from: Date()))] \(message)"
        print(logMessage)
        fflush(stdout)
    }
}
