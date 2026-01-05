import Foundation
import os

public struct ConfigData: Codable, Sendable {
    public var maxDimension: Int
    public var videoQuality: Float
    public var dropFramesWhenBusy: Bool?
}

public enum Config {
    // MARK: - Constants

    public static let port: UInt16 = 65532
    public static let boundary = "websidecar"

    // MARK: - Storage

    private static let data = OSAllocatedUnfairLock(initialState: loadInitialData())

    // MARK: - File Handling

    public static let configURL: URL = {
        // Try to find a suitable location for config
        let fileManager = FileManager.default

        // 1. Environment Variable Override
        if let envPath = ProcessInfo.processInfo.environment["WEBSIDECAR_CONFIG"] {
            let envURL = URL(filePath: envPath)
            // If it's a directory, append config.json
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: envURL.path(percentEncoded: false), isDirectory: &isDir), isDir.boolValue {
                return envURL.appending(component: "config.json")
            }
            return envURL
        }

        // 2. Check if running as a CLI in a local dev environment (cwd/config.json exists)
        let cwd = fileManager.currentDirectoryPath
        let localConfig = URL(filePath: cwd).appending(component: "config.json")
        if fileManager.fileExists(atPath: localConfig.path(percentEncoded: false)) {
            return localConfig
        }

        // 3. Use Application Support (Preferred for both App and installed CLI tools)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appDir = appSupport.appending(component: "com.yaindrop.websidecar")
            // Create directory if needed
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            return appDir.appending(component: "config.json")
        }

        // 4. Fallback to CWD if all else fails
        return localConfig
    }()

    // MARK: - Initialization

    private static func loadInitialData() -> ConfigData {
        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(ConfigData.self, from: data)
        } catch {
            Log.config.error("Failed to load config from \(configURL.path(percentEncoded: false)), using defaults: \(error.localizedDescription)")
            return ConfigData(maxDimension: 1920, videoQuality: 0.75, dropFramesWhenBusy: true)
        }
    }

    // MARK: - Accessors

    static var maxDimension: Int {
        get { data.withLock { $0.maxDimension } }
        set {
            data.withLock {
                $0.maxDimension = newValue
                saveToDisk($0)
            }
        }
    }

    static var videoQuality: Float {
        get { data.withLock { $0.videoQuality } }
        set {
            data.withLock {
                $0.videoQuality = newValue
                saveToDisk($0)
            }
        }
    }

    static var dropFramesWhenBusy: Bool {
        get { data.withLock { $0.dropFramesWhenBusy ?? true } }
        set {
            data.withLock {
                $0.dropFramesWhenBusy = newValue
                saveToDisk($0)
            }
        }
    }

    // MARK: - Methods

    static func save() {
        data.withLock { saveToDisk($0) }
    }

    private static func saveToDisk(_ data: ConfigData) {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: configURL)
        } catch {
            Log.config.error("Failed to save config to \(configURL.path(percentEncoded: false)): \(error.localizedDescription)")
        }
    }

    static func load() -> ConfigData {
        data.withLock { $0 }
    }

    static func update(_ configData: ConfigData) {
        data.withLock {
            $0 = configData
            saveToDisk($0)
        }
    }
}
