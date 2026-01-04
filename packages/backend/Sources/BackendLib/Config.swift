import Foundation

public struct ConfigData: Codable {
    public var maxDimension: Int
    public var videoQuality: Float
}

public enum Config {
    public static let port: UInt16 = 65532
    public static let boundary = "meDisplayBoundary"

    private static let fileURL: URL = {
        let cwd = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: cwd).appendingPathComponent("config.json")
    }()

    private static var _data: ConfigData = {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ConfigData.self, from: data)
        } catch {
            Logger.log("Failed to load config from \(fileURL.path), using defaults: \(error)")
            return ConfigData(maxDimension: 1920, videoQuality: 0.75)
        }
    }()

    static var maxDimension: Int {
        get { _data.maxDimension }
        set {
            _data.maxDimension = newValue
            save()
        }
    }

    static var videoQuality: Float {
        get { _data.videoQuality }
        set {
            _data.videoQuality = newValue
            save()
        }
    }

    static func save() {
        do {
            let data = try JSONEncoder().encode(_data)
            try data.write(to: fileURL)
        } catch {
            Logger.log("Failed to save config to \(fileURL.path): \(error)")
        }
    }

    static func load() -> ConfigData {
        _data
    }

    static func update(maxDimension: Int, videoQuality: Float) {
        _data.maxDimension = maxDimension
        _data.videoQuality = videoQuality
        save()
    }
}
