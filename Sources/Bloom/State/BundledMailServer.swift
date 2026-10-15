import Darwin
import Foundation
import BloomCore

/// Owns Bloom's SMTP server. The small supervisor keeps the server tied to this app process even
/// if Bloom crashes: closing the pipe on exit is its signal to stop Mailpit.
@MainActor
final class BundledMailServer {
    enum Failure: LocalizedError {
        case missing
        case portInUse(Int)

        var errorDescription: String? {
            switch self {
            case .missing: "The built-in inbox is missing from this Bloom installation."
            case .portInUse(let port): "Port \(port) is already in use. Stop the other mail server or choose Existing server."
            }
        }
    }

    private var supervisor: Process?
    private var input: Pipe?

    var isRunning: Bool { supervisor?.isRunning == true }

    func start(ports: MailpitSettings.Ports) throws {
        if isRunning { return }
        stop()

        guard let executables = Bundle.main.executableURL?.deletingLastPathComponent() else {
            throw Failure.missing
        }
        let mailpit = executables.appendingPathComponent("mailpit")
        let helper = executables.appendingPathComponent("bloom-mail-server")
        guard FileManager.default.isExecutableFile(atPath: mailpit.path),
              FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw Failure.missing
        }
        for port in [ports.smtp, ports.api] where !Self.isAvailable(port) {
            throw Failure.portInUse(port)
        }

        let directory = URL(fileURLWithPath: try Store.defaultPath()).deletingLastPathComponent()
        let process = Process()
        let pipe = Pipe()
        process.executableURL = helper
        process.arguments = [
            mailpit.path,
            directory.appendingPathComponent("incoming-mails.sqlite").path,
            String(ports.smtp),
            String(ports.api),
            directory.appendingPathComponent("incoming-mails.log").path,
        ]
        // Mailpit reads MP_* environment variables, including forwarding and relay settings.
        // Inheriting Bloom's environment could turn a local test inbox into a mail sender.
        process.environment = ["HOME": NSHomeDirectory(), "TMPDIR": NSTemporaryDirectory()]
        process.standardInput = pipe
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        supervisor = process
        input = pipe
    }

    func stop() {
        // The helper reads until EOF, then terminates and reaps its Mailpit child. Terminating the
        // helper here instead would strand that child on the SMTP port.
        input?.fileHandleForWriting.closeFile()
        input = nil
        supervisor = nil
    }

    private static func isAvailable(_ port: Int) -> Bool {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
}
