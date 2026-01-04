import SwiftUI
import BackendLib

@main
struct WebSidecarApp: App {
    init() {
        startServer()
    }

    func startServer() {
        do {
            let server = try HTTPServer(port: Config.port)
            server.start()
            print("Server started on port \(Config.port)")
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            Text("WebSidecar: Running")
            Text("Port: \(Config.port)")
            
            Divider()
            
            Button("Open in Browser") {
                if let url = URL(string: "http://localhost:\(Config.port)") {
                    NSWorkspace.shared.open(url)
                }
            }
            
            Button("Open Config Folder") {
                let configURL = Config.configURL
                if FileManager.default.fileExists(atPath: configURL.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([configURL])
                } else {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
                }
            }
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            let icon = NSImage(named: "status_icon") ?? NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)!
            Image(nsImage: icon)
        }
    }
}
