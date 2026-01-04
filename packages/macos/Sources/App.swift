import SwiftUI
import BackendLib
import ServiceManagement

@main
struct WebSidecarApp: App {
    @AppStorage("launchAtLogin") var launchAtLogin = false

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
    
    func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update launch at login: \(error)")
            }
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

            Toggle("Open at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    launchAtLogin = newValue
                    toggleLaunchAtLogin()
                }
            ))
            
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
