import os
import threading
import time
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

root = Path(os.environ.get("WGS_ROOT", os.getcwd())).resolve()
start_port = int(os.environ.get("WGS_PORT", "8765"))
port_file = Path(os.environ.get("WGS_PORT_FILE", str(root / ".port")))
stop_file = Path(os.environ.get("WGS_STOP_FILE", str(root / ".stop")))

root.mkdir(parents=True, exist_ok=True)
stop_file.unlink(missing_ok=True)
port_file.unlink(missing_ok=True)

class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(root), **kwargs)

    def log_message(self, format, *args):
        return

server = None

for port in range(start_port, start_port + 20):
    try:
        server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
        port_file.write_text(str(port), encoding="utf-8")
        break
    except OSError:
        continue

if server is None:
    raise RuntimeError("No available LAN port")

def watch_stop():
    while True:
        if stop_file.exists():
            try:
                server.shutdown()
            except Exception:
                pass
            return
        time.sleep(0.25)

threading.Thread(target=watch_stop, daemon=True).start()

try:
    server.serve_forever()
finally:
    server.server_close()
    port_file.unlink(missing_ok=True)
    stop_file.unlink(missing_ok=True)
