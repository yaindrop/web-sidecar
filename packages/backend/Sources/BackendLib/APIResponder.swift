import CoreGraphics
import Foundation
import ScreenCaptureKit

struct DisplayInfo: Codable {
    let id: Int
    let width: Int
    let height: Int
}

enum APIResponder {
    static func getDisplaysJSON() async throws -> String {
        let content = try await SCShareableContent.current
        let displays = content.displays.compactMap { display -> DisplayInfo? in
            guard let mode = CGDisplayCopyDisplayMode(display.displayID) else { return nil }
            return DisplayInfo(id: Int(display.displayID), width: Int(mode.pixelWidth), height: Int(mode.pixelHeight))
        }
        let jsonData = try JSONEncoder().encode(displays)
        return String(data: jsonData, encoding: .utf8) ?? "[]"
    }

    static func getConfigJSON() -> String {
        let config = Config.load()
        guard let jsonData = try? JSONEncoder().encode(config) else { return "{}" }
        return String(data: jsonData, encoding: .utf8) ?? "{}"
    }

    static func updateConfig(json: String) throws {
        guard let data = json.data(using: .utf8) else { throw URLError(.badURL) }
        let newConfig = try JSONDecoder().decode(ConfigData.self, from: data)
        Config.update(newConfig)
    }
}
