import http.server,sys
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n=int(self.headers.get('Content-Length',0)); b=self.rfile.read(n).decode('utf8','replace')
        open(sys.argv[1],'a').write(b+'\n'); self.send_response(200); self.end_headers(); self.wfile.write(b'ok')
    def log_message(self,*a): pass
http.server.HTTPServer(('127.0.0.1',int(sys.argv[2]) if len(sys.argv)>2 else 8765),H).serve_forever()
