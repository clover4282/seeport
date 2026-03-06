import Foundation
import Darwin

// PROC_PIDPATHINFO_MAXSIZE = 4 * MAXPATHLEN, not available as Swift constant
private let kMaxPathSize: Int = 4 * Int(MAXPATHLEN)

actor PortScanner {
    func scan() async -> [PortInfo] {
        let currentUser = NSUserName()
        var ports: [PortInfo] = []
        var seen = Set<String>()

        // 1. Get all PIDs
        var pidCount = proc_listallpids(nil, 0)
        guard pidCount > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: Int(pidCount))
        pidCount = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size * pids.count))
        guard pidCount > 0 else { return [] }

        // 2. For each PID, get file descriptors and check for TCP LISTEN sockets
        for i in 0..<Int(pidCount) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            // Get fd list size
            let fdBufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
            guard fdBufferSize > 0 else { continue }

            let fdCount = fdBufferSize / Int32(MemoryLayout<proc_fdinfo>.size)
            var fdInfos = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(fdCount))
            let actualSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fdInfos, fdBufferSize)
            guard actualSize > 0 else { continue }

            let actualCount = Int(actualSize) / MemoryLayout<proc_fdinfo>.size
            var processName: String?

            for j in 0..<actualCount {
                let fd = fdInfos[j]
                // Only check socket file descriptors
                guard fd.proc_fdtype == PROX_FDTYPE_SOCKET else { continue }

                var socketInfo = socket_fdinfo()
                let socketInfoSize = proc_pidfdinfo(
                    pid,
                    fd.proc_fd,
                    PROC_PIDFDSOCKETINFO,
                    &socketInfo,
                    Int32(MemoryLayout<socket_fdinfo>.size)
                )
                guard socketInfoSize == MemoryLayout<socket_fdinfo>.size else { continue }

                // Check: TCP socket in LISTEN state
                let si = socketInfo.psi
                guard si.soi_family == AF_INET || si.soi_family == AF_INET6 else { continue }
                guard si.soi_kind == SOCKINFO_TCP else { continue }
                guard si.soi_proto.pri_tcp.tcpsi_state == TSI_S_LISTEN else { continue }

                // Extract port (network byte order → host byte order)
                let port: UInt16
                let address: String
                // insi_lport is Int32 in network byte order
                let rawPort = UInt16(truncatingIfNeeded: si.soi_proto.pri_tcp.tcpsi_ini.insi_lport)
                if si.soi_family == AF_INET {
                    let addr4 = si.soi_proto.pri_tcp.tcpsi_ini.insi_laddr.ina_46.i46a_addr4
                    port = CFSwapInt16BigToHost(rawPort)
                    let addrInt = addr4.s_addr
                    if addrInt == INADDR_ANY {
                        address = "0.0.0.0"
                    } else {
                        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var addrCopy = addr4
                        inet_ntop(AF_INET, &addrCopy, &buf, socklen_t(INET_ADDRSTRLEN))
                        address = String(cString: buf)
                    }
                } else {
                    // AF_INET6
                    port = CFSwapInt16BigToHost(rawPort)
                    let addr6 = si.soi_proto.pri_tcp.tcpsi_ini.insi_laddr.ina_6
                    var buf = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    var addrCopy = addr6
                    inet_ntop(AF_INET6, &addrCopy, &buf, socklen_t(INET6_ADDRSTRLEN))
                    let addrStr = String(cString: buf)
                    if addrStr == "::" {
                        address = "0.0.0.0"
                    } else {
                        address = addrStr
                    }
                }

                guard port > 0 else { continue }

                let key = "\(port)-\(pid)"
                guard seen.insert(key).inserted else { continue }

                // Lazy resolve process name
                if processName == nil {
                    processName = Self.getProcessName(pid: pid)
                }

                let procInfo = ProcessInfo(
                    id: pid,
                    name: processName ?? "unknown",
                    user: currentUser
                )
                let portInfo = PortInfo(
                    port: port,
                    process: procInfo,
                    address: address,
                    isFavorite: Favorites.isFavorite(port)
                )
                ports.append(portInfo)
            }
        }

        return ports
    }

    private static func getProcessName(pid: pid_t) -> String {
        // Use proc_pidpath to get full executable path
        var pathBuffer = [CChar](repeating: 0, count: kMaxPathSize)
        let pathLen = proc_pidpath(pid, &pathBuffer, UInt32(kMaxPathSize))
        if pathLen > 0 {
            let fullPath = String(cString: pathBuffer)
            // Return just the executable name
            return (fullPath as NSString).lastPathComponent
        }
        // Fallback: proc_name
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXCOMLEN) + 1)
        let nameLen = proc_name(pid, &nameBuffer, UInt32(MAXCOMLEN) + 1)
        if nameLen > 0 {
            return String(cString: nameBuffer)
        }
        return "unknown"
    }
}
