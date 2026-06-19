import Darwin

enum NetworkUtility {

    // Returns the machine's preferred local IPv4 address for use as the DNS redirect target.
    static func localIPAddress() -> String {
        ipViaUDPSocket() ?? ipViaNetworkInterfaces() ?? "127.0.0.1"
    }

    // Connects a UDP socket to an external address (no data is sent) so the OS reveals
    // which local interface it would use for outgoing traffic.
    private static func ipViaUDPSocket() -> String? {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }
        defer { close(sock) }

        var remote = sockaddr_in()
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = UInt16(80).bigEndian
        inet_pton(AF_INET, "8.8.8.8", &remote.sin_addr)

        let connected = withUnsafePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard connected == 0 else { return nil }

        var local = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(sock, $0, &len)
            }
        }

        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &local.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
        let ip = String(cString: buffer)
        return ip == "0.0.0.0" ? nil : ip
    }

    // Falls back to scanning network interfaces for a private IPv4 address.
    private static func ipViaNetworkInterfaces() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let interface = ptr {
            let flags = Int32(interface.pointee.ifa_flags)
            let addr = interface.pointee.ifa_addr

            if addr?.pointee.sa_family == UInt8(AF_INET),
               flags & IFF_UP != 0,
               flags & IFF_LOOPBACK == 0 {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr!.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let ip = String(cString: hostname)
                    if ip.hasPrefix("192.168.") || ip.hasPrefix("10.") || ip.hasPrefix("172.") {
                        return ip
                    }
                }
            }
            ptr = interface.pointee.ifa_next
        }
        return nil
    }
}
