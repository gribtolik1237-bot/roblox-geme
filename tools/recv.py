# Temporary receiver: Studio POSTs {path, source} -> writes <root>/<path>. Localhost only.
import json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
ROOT = os.path.abspath(sys.argv[1])
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        try:
            d = json.loads(body.decode("utf-8"))
            rel = d["path"].replace("\\", "/")
            if ".." in rel.split("/"):
                raise ValueError("bad path")
            full = os.path.join(ROOT, *rel.split("/"))
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "w", encoding="utf-8", newline="\n") as f:
                f.write(d["source"])
            self.send_response(200); self.end_headers(); self.wfile.write(b"ok")
        except Exception as e:
            self.send_response(400); self.end_headers(); self.wfile.write(str(e).encode())
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", 8765), H).serve_forever()
