import Foundation
import Network
import os
import UniformTypeIdentifiers

final class RequestHandler {
    // MARK: - Properties

    private let connection: NWConnection

    // Protect mutable state with a lock for strict concurrency safety
    private let lock = OSAllocatedUnfairLock()
    private var _streamer: MJPEGStreamer?

    private var streamer: MJPEGStreamer? {
        get { lock.withLock { _streamer } }
        set { lock.withLock { _streamer = newValue } }
    }

    private lazy var publicDir: URL? = {
        let fileManager = FileManager.default

        // 1. Check Bundle Resources
        if let resourceURL = Bundle.main.resourceURL {
            let publicURL = resourceURL.appending(path: "public", directoryHint: .isDirectory)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: publicURL.path(percentEncoded: false), isDirectory: &isDir), isDir.boolValue {
                return publicURL
            }
        }

        // 2. Check Current Working Directory
        let cwd = URL(filePath: fileManager.currentDirectoryPath, directoryHint: .isDirectory)
        let publicCwd = cwd.appending(path: "public", directoryHint: .isDirectory)
        var isDir: ObjCBool = false
        if fileManager.fileExists(atPath: publicCwd.path(percentEncoded: false), isDirectory: &isDir), isDir.boolValue {
            return publicCwd
        }

        return nil
    }()

    // MARK: - Initialization

    init(connection: NWConnection) {
        self.connection = connection
    }

    // MARK: - Public API

    func handle(method: String, path: String, body: String? = nil) {
        Log.request.log("\(method) \(path)")

        if method == "OPTIONS" {
            sendCORSPreflight()
            return
        }

        // Router
        switch (method, path) {
        case ("GET", "/api/displays"):
            sendDisplays()

        case ("GET", "/api/config"):
            sendConfig()

        case ("POST", "/api/config"):
            if let body {
                updateConfig(json: body)
            } else {
                send404()
            }

        case ("GET", _) where path.hasPrefix("/v/"):
            handleVideoStream(path: path)

        case ("GET", _):
            serveStaticFile(path: path)

        default:
            send404()
        }
    }

    // MARK: - Static File Serving

    private func serveStaticFile(path: String) {
        guard let publicDir else {
            send404()
            return
        }

        // Sanitize path
        var filePath = path
        if filePath == "/" {
            filePath = "/index.html"
        }

        // Security check: prevent directory traversal
        if filePath.contains("..") {
            send404()
            return
        }

        // Remove leading slash for appending
        if filePath.hasPrefix("/") {
            filePath = String(filePath.dropFirst())
        }

        let fileURL = publicDir.appending(path: filePath)

        // Check if file exists
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false), isDirectory: &isDir) {
            if isDir.boolValue {
                // Try index.html in directory
                let indexURL = fileURL.appending(path: "index.html")
                if FileManager.default.fileExists(atPath: indexURL.path(percentEncoded: false)) {
                    sendFile(url: indexURL)
                    return
                }
            } else {
                sendFile(url: fileURL)
                return
            }
        }

        // SPA Fallback: if not found and it looks like a route (no extension), serve index.html
        if !filePath.contains(".") {
            let indexURL = publicDir.appending(path: "index.html")
            if FileManager.default.fileExists(atPath: indexURL.path(percentEncoded: false)) {
                sendFile(url: indexURL)
                return
            }
        }

        send404()
    }

    private func sendFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

            let header = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
            var packet = header.data(using: .utf8) ?? Data()
            packet.append(data)

            connection.send(content: packet, completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
            })
        } catch {
            Log.request.error("Failed to read file \(url.path(percentEncoded: false)): \(error.localizedDescription)")
            send404()
        }
    }

    // MARK: - API Handlers

    private func sendCORSPreflight() {
        let response = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nConnection: close\r\n\r\n"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }

    private func sendDisplays() {
        Task {
            do {
                let json = try await APIResponder.getDisplaysJSON()
                sendResponse(body: json, contentType: "application/json")
            } catch {
                sendResponse(status: "500 Internal Server Error", body: "{\"error\": \"Failed to list displays\"}", contentType: "application/json")
            }
        }
    }

    private func sendConfig() {
        let json = APIResponder.getConfigJSON()
        sendResponse(body: json, contentType: "application/json")
    }

    private func updateConfig(json: String) {
        do {
            try APIResponder.updateConfig(json: json)
            sendResponse(body: "{\"status\": \"ok\"}", contentType: "application/json")
        } catch {
            sendResponse(status: "400 Bad Request", body: "{\"error\": \"Invalid config\"}", contentType: "application/json")
        }
    }

    private func handleVideoStream(path: String) {
        let displayIDString = String(path.dropFirst(3)) // Remove /v/
        guard let displayID = Int(displayIDString) else {
            send404()
            return
        }

        startStreaming(displayID: displayID)
    }

    private func startStreaming(displayID: Int) {
        // MJPEG Stream headers - CORS allowed
        let headers = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: multipart/x-mixed-replace; boundary=\(Config.boundary)\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"

        connection.send(content: headers.data(using: .utf8), completion: .contentProcessed { [weak self] error in
            if let error {
                Log.request.error("Failed to send headers: \(error.localizedDescription)")
                self?.connection.cancel()
                return
            }

            guard let self else { return }

            let newStreamer = MJPEGStreamer(displayID: displayID) { [weak self] data, completion in
                guard let self else {
                    completion(NWError.posix(.ECANCELED))
                    return
                }
                sendFrame(data, completion: completion)
            }

            streamer = newStreamer
            newStreamer.start()
        })
    }

    private func sendFrame(_ data: Data, completion: @escaping @Sendable (Error?) -> Void) {
        let header = "--\(Config.boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: \(data.count)\r\n\r\n"
        var packet = header.data(using: .utf8) ?? Data()
        packet.append(data)
        packet.append("\r\n".data(using: .utf8) ?? Data())

        connection.send(content: packet, completion: .contentProcessed { error in
            completion(error)
        })
    }

    private func sendResponse(status: String = "200 OK", body: String, contentType: String) {
        let response = "HTTP/1.1 \(status)\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { [weak self] _ in
            self?.connection.cancel()
        })
    }

    private func send404() {
        sendResponse(status: "404 Not Found", body: "Not Found", contentType: "text/plain")
    }

    // MARK: - Lifecycle

    func stop() {
        streamer?.stop()
        streamer = nil
    }
}
