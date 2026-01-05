import Foundation

public struct ConfigData: Codable {
    public var maxDimension: Int
    public var videoQuality: Float
    public var dropFramesWhenBusy: Bool?
}

public enum Config {
    public static let port: UInt16 = 65532
    public static let boundary = "meDisplayBoundary"

    private static let fileURL: URL = {
        // Try to find a suitable location for config
        let fileManager = FileManager.default

        // 1. Environment Variable Override
        if let envPath = ProcessInfo.processInfo.environment["WEBSIDECAR_CONFIG"] {
            let envURL = URL(fileURLWithPath: envPath)
            // If it's a directory, append config.json
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: envURL.path, isDirectory: &isDir), isDir.boolValue {
                return envURL.appendingPathComponent("config.json")
            }
            return envURL
        }

        // 2. Check if running as a CLI in a local dev environment (cwd/config.json exists)
        let cwd = fileManager.currentDirectoryPath
        let localConfig = URL(fileURLWithPath: cwd).appendingPathComponent("config.json")
        if fileManager.fileExists(atPath: localConfig.path) {
            return localConfig
        }

        // 3. Use Application Support (Preferred for both App and installed CLI tools)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appendingPathComponent("com.yaindrop.websidecar")
            // Create directory if needed
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            return appDir.appendingPathComponent("config.json")
        }

        // 4. Fallback to CWD if all else fails
        return localConfig
    }()

    public static var configURL: URL {
        fileURL
    }

    private static var _data: ConfigData = {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(ConfigData.self, from: data)
        } catch {
            Logger.log("Failed to load config from \(fileURL.path), using defaults: \(error)")
            return ConfigData(maxDimension: 1920, videoQuality: 0.75, dropFramesWhenBusy: true)
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

    static var dropFramesWhenBusy: Bool {
        get { _data.dropFramesWhenBusy ?? true }
        set {
            _data.dropFramesWhenBusy = newValue
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

    static func update(_ configData: ConfigData) {
        _data = configData
        save()
    }
}
