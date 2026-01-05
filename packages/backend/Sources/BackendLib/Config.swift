import Foundation
import os

public struct ConfigData: Codable {
    public var maxDimension: Int
    public var videoQuality: Float
    public var dropFramesWhenBusy: Bool?
}

public enum Config {
    public static let port: UInt16 = 65532
    public static let boundary = "meDisplayBoundary"

    private static let lock = OSAllocatedUnfairLock()

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
            Logger.config.error("Failed to load config from \(fileURL.path, privacy: .public), using defaults: \(error.localizedDescription, privacy: .public)")
            return ConfigData(maxDimension: 1920, videoQuality: 0.75, dropFramesWhenBusy: true)
        }
    }()

    static var maxDimension: Int {
        get { lock.withLock { _data.maxDimension } }
        set {
            lock.withLock {
                _data.maxDimension = newValue
                saveData()
            }
        }
    }

    static var videoQuality: Float {
        get { lock.withLock { _data.videoQuality } }
        set {
            lock.withLock {
                _data.videoQuality = newValue
                saveData()
            }
        }
    }

    static var dropFramesWhenBusy: Bool {
        get { lock.withLock { _data.dropFramesWhenBusy ?? true } }
        set {
            lock.withLock {
                _data.dropFramesWhenBusy = newValue
                saveData()
            }
        }
    }

    static func save() {
        lock.withLock { saveData() }
    }

    private static func saveData() {
        do {
            let data = try JSONEncoder().encode(_data)
            try data.write(to: fileURL)
        } catch {
            Logger.config.error("Failed to save config to \(fileURL.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    static func load() -> ConfigData {
        lock.withLock { _data }
    }

    static func update(_ configData: ConfigData) {
        lock.withLock {
            _data = configData
            saveData()
        }
    }
}
