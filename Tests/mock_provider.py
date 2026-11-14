"""Synthetic loopback provider. Never use a real API key with this test server."""
import http.server,json,sys,time,urllib.parse,hashlib,base64,struct
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def speech_socket(self):
        assert self.headers.get('Authorization')=='Bearer fixture-speech-key'
        self.protocol_version='HTTP/1.1'
        self.send_response(101);self.send_header('Upgrade','websocket');self.send_header('Connection','Upgrade')
        self.send_header('Sec-WebSocket-Accept',base64.b64encode(hashlib.sha1((self.headers['Sec-WebSocket-Key']+'258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest()).decode());self.end_headers()
        self.connection.settimeout(5)
        def read():
            head=self.rfile.read(2)
            if len(head)!=2:return 8,b''
            code=head[0]&15;size=head[1]&127
            if size==126:size=struct.unpack('!H',self.rfile.read(2))[0]
            if size==127:size=struct.unpack('!Q',self.rfile.read(8))[0]
            assert size<=1000000
            mask=self.rfile.read(4) if head[1]&128 else b'';data=self.rfile.read(size)
            if mask:data=bytes(b^mask[i%4] for i,b in enumerate(data))
            return code,data
        code,data=read();config=json.loads(data);assert code==1 and config['audio_format']=='pcm_s16le' and config['language_hints']==['en','ms','zh'] and 'api_key' not in config
        code,data=read();assert code==2 and len(data)>0 and len(data)%2==0
        for tokens in [[{'text':'你好','is_final':True},{'text':' J son','is_final':False}],[{'text':' JSON','is_final':False}],[{'text':' JSON','is_final':True},{'text':'<end>','is_final':True}]]:
            payload=json.dumps({'tokens':tokens},ensure_ascii=False).encode();self.wfile.write((bytes([129,len(payload)]) if len(payload)<126 else bytes([129,126])+struct.pack('!H',len(payload)))+payload);self.wfile.flush();time.sleep(.02)
        try:
            while read()[0]!=8:pass
        except (TimeoutError,ConnectionError):pass
        self.close_connection=True
    def do_GET(self):
        if self.path.endswith('/speech-socket'):self.speech_socket();return
        if '/catalog-redirect/' in self.path:
            self.send_response(302);self.send_header('Location','http://127.0.0.1:9/no-secret-forwarding');self.end_headers();return
        assert self.headers.get('x-goog-api-key') == 'fixture-key-not-a-real-secret'
        query=urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if '/catalog-loop/' in self.path:
            payload={'models':[], 'nextPageToken':'repeated'}
        elif query.get('pageToken') == ['next']:
            payload={'models':[{'name':'models/fixture-flash','supportedGenerationMethods':['generateContent']},{'name':'models/fixture-pro','supportedGenerationMethods':['generateContent']}]}
        else:
            payload={'models':[{'name':'models/fixture-flash','supportedGenerationMethods':['generateContent']},{'name':'models/embedding-only','supportedGenerationMethods':['embedContent']},{'name':'models/not/a/model','supportedGenerationMethods':['generateContent']}], 'nextPageToken':'next'}
        self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(json.dumps(payload).encode())
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers.get('Content-Length','0'))))
        if body.get('messages', [{}])[-1].get('content') == 'Yes, continue':
            assert 'Try a small JSON object.' in body['messages'][0]['content'] and 'FOLLOW-UP' in body['messages'][0]['content']
        if '/redirect/' in self.path:
            self.send_response(302);self.send_header('Location','http://127.0.0.1:9/no-secret-forwarding');self.end_headers();return
        if '/http404/' in self.path:
            self.send_response(404);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(b'{"error":{"message":"Reflected fixture-key-not-a-real-secret"}}');return
        self.send_response(200);self.send_header('Content-Type','text/event-stream');self.send_header('Cache-Control','no-cache');self.end_headers()
        if '/error/' in self.path:
            self.wfile.write(('data: '+json.dumps({'error':{'message':'Synthetic failure. '*200}})+'\n\n').encode());self.wfile.flush();return
        self.wfile.write(b': heartbeat\n\n');self.wfile.flush()
        chunks = ['Hello',' world']
        if '/packaged/' in self.path: chunks = ['JSON is a text format.', '\n[[VELIN_', 'SAY]]\nJSON lets apps exchange data.', '\n[[VELIN_NEXT]]\nTry a small JSON object.', '\n[[VELIN_MORE]]\nAn object contains key-value pairs.']
        for text in chunks:
            if self.path.endswith('/responses'): event={'type':'response.output_text.delta','delta':text}
            elif self.path.endswith('/messages'):event={'type':'content_block_delta','delta':{'type':'text_delta','text':text}}
            elif ':streamGenerateContent' in self.path:event={'candidates':[{'content':{'parts':[{'text':text}]}}]}
            else:event={'choices':[{'delta':{'content':text}}]}
            self.wfile.write(('data: '+json.dumps(event)+'\n\n').encode());self.wfile.flush();time.sleep(.02)
        self.wfile.write(b'data: [DONE]\n\n');self.wfile.flush()
if __name__=='__main__':
    server=http.server.ThreadingHTTPServer(('127.0.0.1',int(sys.argv[1]) if len(sys.argv)>1 else 0),Handler)
    print(server.server_address[1],flush=True);server.serve_forever()
