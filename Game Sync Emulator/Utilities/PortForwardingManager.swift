import AppKit

enum PortForwardingManager {

    @MainActor
    static func setup() {
        let hostIP = NetworkUtility.localIPAddress()
        let scriptPath = "/tmp/entralinked_relay.py"
        let logPath = "/tmp/entralinked_relay.log"

        // Bind UDP to the specific host IP rather than 0.0.0.0 so we don't
        // collide with mDNSResponder, which holds 0.0.0.0:53 on macOS.
        let script = """
import socket, threading, time

BIND_IP = '\(hostIP)'
LOG_PATH = '\(logPath)'

def log(msg):
    try:
        with open(LOG_PATH, 'a') as f:
            f.write(msg + '\\n')
            f.flush()
    except: pass

log('relay starting, BIND_IP=' + BIND_IP)

def udp_relay():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        s.bind((BIND_IP, 53))
        log('UDP bound ' + BIND_IP + ':53')
    except Exception as e:
        log('UDP bind failed: ' + str(e))
        return
    def handle(data, addr):
        r = None
        try:
            r = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            r.settimeout(2)
            r.sendto(data, ('127.0.0.1', 5300))
            resp, _ = r.recvfrom(512)
            s.sendto(resp, addr)
            log('UDP fwd ' + str(len(data)) + 'B from ' + str(addr) + ' -> got ' + str(len(resp)) + 'B resp')
        except Exception as e:
            log('UDP handle error from ' + str(addr) + ': ' + str(e))
        finally:
            if r: r.close()
    while True:
        try:
            data, addr = s.recvfrom(512)
            threading.Thread(target=handle, args=(data, addr), daemon=True).start()
        except: pass

def tcp_relay(listen_port, forward_port):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
        s.bind(('0.0.0.0', listen_port))
        s.listen(10)
        log('TCP bound 0.0.0.0:' + str(listen_port))
    except Exception as e:
        log('TCP bind ' + str(listen_port) + ' failed: ' + str(e))
        return
    def handle(conn, addr):
        with conn:
            try:
                r = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                r.connect(('127.0.0.1', forward_port))
                log('TCP :' + str(listen_port) + ' accepted ' + str(addr) + ' -> :' + str(forward_port))
                with r:
                    def fwd(src, dst, label):
                        total = 0
                        try:
                            while True:
                                d = src.recv(4096)
                                if not d: break
                                dst.sendall(d)
                                total += len(d)
                        except Exception as e:
                            log('TCP :' + str(listen_port) + ' fwd[' + label + '] err: ' + str(e))
                        log('TCP :' + str(listen_port) + ' fwd[' + label + '] done ' + str(total) + 'B')
                    t1 = threading.Thread(target=fwd, args=(conn, r, 'DS->SV'), daemon=True)
                    t2 = threading.Thread(target=fwd, args=(r, conn, 'SV->DS'), daemon=True)
                    t1.start(); t2.start(); t1.join(); t2.join()
            except Exception as e:
                log('TCP :' + str(listen_port) + ' handle error ' + str(addr) + ': ' + str(e))
    while True:
        try:
            conn, addr = s.accept()
            threading.Thread(target=handle, args=(conn, addr), daemon=True).start()
        except: pass

threading.Thread(target=udp_relay, daemon=True).start()
threading.Thread(target=tcp_relay, args=(80, 8080), daemon=True).start()
threading.Thread(target=tcp_relay, args=(443, 8443), daemon=True).start()
log('threads started')
while True:
    time.sleep(3600)
"""

        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        } catch {
            log("Port relay: could not write script — \(error)")
            return
        }

        // pfctl -F all nukes every rule/state/anchor so leftover rdr rules from
        // previous sessions can't intercept port 53 before Python's socket sees it.
        // pf.conf is reloaded immediately after to restore system defaults.
        let cmd = "pfctl -a com.apple/entralinked -F all 2>/dev/null; pkill -9 -f entralinked_relay.py 2>/dev/null; rm -f '\(logPath)'; python3 '\(scriptPath)' < /dev/null > '\(logPath)' 2>&1 & sleep 1; pgrep -f entralinked_relay.py > /dev/null && echo running || cat '\(logPath)'"
        var errorDict: NSDictionary?
        let result = NSAppleScript(source: "do shell script \"\(cmd)\" with administrator privileges")?
            .executeAndReturnError(&errorDict)

        let output = result?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let msg = errorDict?["NSAppleScriptErrorMessage"] as? String {
            log("Port relay error: \(msg)")
            return
        }

        if output == "running" {
            // Read the relay log to confirm which ports actually bound.
            let relayLog = (try? String(contentsOfFile: logPath))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            log("Port relay running — \(relayLog.isEmpty ? "no log output" : relayLog)")
        } else {
            log("Port relay startup output: \(output.isEmpty ? "(empty)" : output)")
        }
    }
}
