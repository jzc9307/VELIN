"""Synthetic loopback provider. Never use a real API key with this test server."""
import http.server,json,sys,time
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
        if '/redirect/' in self.path:
            self.send_response(302);self.send_header('Location','http://127.0.0.1:9/no-secret-forwarding');self.end_headers();return
        self.send_response(200);self.send_header('Content-Type','text/event-stream');self.send_header('Cache-Control','no-cache');self.end_headers()
        if '/error/' in self.path:
            self.wfile.write(('data: '+json.dumps({'error':{'message':'Synthetic failure. '*200}})+'\n\n').encode());self.wfile.flush();return
        self.wfile.write(b': heartbeat\n\n');self.wfile.flush()
        for text in ['Hello',' world']:
            if self.path.endswith('/responses'): event={'type':'response.output_text.delta','delta':text}
            elif self.path.endswith('/messages'):event={'type':'content_block_delta','delta':{'type':'text_delta','text':text}}
            elif ':streamGenerateContent' in self.path:event={'candidates':[{'content':{'parts':[{'text':text}]}}]}
            else:event={'choices':[{'delta':{'content':text}}]}
            self.wfile.write(('data: '+json.dumps(event)+'\n\n').encode());self.wfile.flush();time.sleep(.02)
        self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
if __name__=='__main__':
    server=http.server.ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1]) if len(sys.argv)>1 else 0),Handler)
    print(server.server_address[1],flush=True);server.serve_forever()
