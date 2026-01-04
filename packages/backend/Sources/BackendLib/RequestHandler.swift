import Foundation
import Network

class RequestHandler {
    private let connection: NWConnection
    private var streamer: MJPEGStreamer?

    private var publicDir: URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let publicURL = resourceURL.appendingPathComponent("public")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: publicURL.path, isDirectory: &isDir), isDir.boolValue {
                return publicURL
            }
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let publicCwd = cwd.appendingPathComponent("public")
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: publicCwd.path, isDirectory: &isDir), isDir.boolValue {
            return publicCwd
        }
        return nil
    }

    init(connection: NWConnection) {
        self.connection = connection
    }

    func handle(method: String, path: String, body: String? = nil) {
        Logger.log("\(method) \(path)")

        // Handle CORS Preflight
        if method == "OPTIONS" {
            sendCORSPreflight()
            return
        }

        if path == "/api/displays", method == "GET" {
            sendDisplays()
        } else if path == "/api/config" {
            if method == "GET" {
                sendConfig()
            } else if method == "POST", let body {
                updateConfig(body: body)
            } else {
                send404()
            }
        } else if path.hasPrefix("/v/"), method == "GET" {
            handleVideoStream(path: path)
        } else {
            // Static file serving fallback
            if method == "GET" {
                serveStaticFile(path: path)
            } else {
                send404()
            }
        }
    }

    private func serveStaticFile(path: String) {
        guard let publicDir else {
            send404()
            return
        }

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

        let fileURL = publicDir.appendingPathComponent(filePath)
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir) {
             if isDir.boolValue {
                 // Try index.html in directory
                 let indexURL = fileURL.appendingPathComponent("index.html")
                 if FileManager.default.fileExists(atPath: indexURL.path) {
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
             let indexURL = publicDir.appendingPathComponent("index.html")
             if FileManager.default.fileExists(atPath: indexURL.path) {
                 sendFile(url: indexURL)
                 return
             }
        }

        send404()
    }

    private func sendFile(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let contentType = mimeType(for: url.pathExtension)
            
            let header = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: \(contentType)\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
            var packet = header.data(using: .utf8) ?? Data()
            packet.append(data)
            
            connection.send(content: packet, completion: .contentProcessed { [weak self] _ in
                self?.connection.cancel()
            })
        } catch {
            Logger.log("Failed to read file \(url.path): \(error)")
            send404()
        }
    }

    private func mimeType(for extension: String) -> String {
        switch `extension`.lowercased() {
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "ico": return "image/x-icon"
        default: return "application/octet-stream"
        }
    }

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

    private func updateConfig(body: String) {
        do {
            try APIResponder.updateConfig(body: body)
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
                Logger.log("Failed to send headers: \(error)")
                self?.connection.cancel()
                return
            }

            guard let self else { return }

            streamer = MJPEGStreamer(displayID: displayID) { [weak self] data, completion in
                guard let self else {
                    completion(NWError.posix(.ECANCELED))
                    return
                }
                sendFrame(data, completion: completion)
            }
            streamer?.start()
        })
    }

    private func sendFrame(_ data: Data, completion: @escaping (Error?) -> Void) {
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

    func stop() {
        streamer?.stop()
    }
}
