import importlib.util,threading,subprocess,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('mock',Path(__file__).with_name('mock_provider.py'));mock=importlib.util.module_from_spec(spec);spec.loader.exec_module(mock)
server=mock.http.server.ThreadingHTTPServer(('127.0.0.1',0),mock.Handler)
thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
try:result=subprocess.run([sys.argv[1],f'http://127.0.0.1:{server.server_address[1]}/v1']);sys.exit(result.returncode)
finally:server.shutdown();server.server_close()
