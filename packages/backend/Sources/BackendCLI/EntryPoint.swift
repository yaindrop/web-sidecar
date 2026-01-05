import BackendLib
import Foundation

@main
struct Main {
    static func main() {
        do {
            let server = try HTTPServer(port: Config.port)
            server.start()
            RunLoop.main.run()
        } catch {
            print("Failed to create server: \(error)")
            exit(1)
        }
    }
}
