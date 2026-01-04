import BackendLib
import ServiceManagement
import SwiftUI

@main
struct WebSidecarApp: App {
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @State private var hostIP: String?

    init() {
        startServer()
        _hostIP = State(initialValue: Self.getIPAddress())
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

    static func getIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name != "lo0" { // Ignore loopback
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        // Prefer en0 (usually Wi-Fi)
                        if name == "en0" {
                            freeifaddrs(ifaddr)
                            return address
                        }
                    }
                }
            }
            freeifaddrs(ifaddr)
        }
        return address
    }

    var body: some Scene {
        MenuBarExtra {
            Text("WebSidecar: Running")

            if let ip = hostIP {
                Button("Host: \(ip):\(String(Config.port))") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("http://\(ip):\(String(Config.port))", forType: .string)
                }
                .keyboardShortcut("c", modifiers: .command)
                .help("Click to copy URL")
            }

            Button("Open in Browser") {
                let host = hostIP ?? "localhost"
                if let url = URL(string: "http://\(host):\(String(Config.port))") {
                    NSWorkspace.shared.open(url)
                }
            }

            Divider()

            Button("Open Config Folder") {
                let configURL = Config.configURL
                if FileManager.default.fileExists(atPath: configURL.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([configURL])
                } else {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.deletingLastPathComponent().path)
                }
            }

            Toggle("Open at Login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    launchAtLogin = newValue
                    toggleLaunchAtLogin()
                },
            ))

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            let icon = NSImage(named: "status_icon") ?? NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)!
            Image(nsImage: icon)
        }
        .menuBarExtraStyle(.menu) // Ensure standard menu behavior
    }
}
