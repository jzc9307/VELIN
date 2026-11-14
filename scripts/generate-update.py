#!/usr/bin/env python3
"""Sign release metadata using the approved local Keychain signer, never a repo key."""
import base64,hashlib,importlib.util,json,pathlib,subprocess,sys,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
def generate(folder):
    spec=importlib.util.spec_from_file_location('update_signing',ROOT/'scripts/update-signing.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    signer=module.signer();public=subprocess.check_output([str(signer),'public'],text=True).strip()
    if public!=(ROOT/'Resources/UpdatePublicKey.txt').read_text().strip():raise SystemExit('The release-signing key does not match installed apps. Do not rotate it implicitly.')
    version=(ROOT/'VERSION').read_text().strip();build=int((ROOT/'BUILD_NUMBER').read_text())
    history=json.loads((ROOT/'release-history.json').read_text());entry=next(e for e in history if e['version']==version)
    def artifact(suffix):
        name=f'VELIN-{version}-{suffix}';p=folder/name
        return {'name':name,'url':f'https://github.com/jzc9307/VELIN/releases/download/v{version}/{name}','sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size':p.stat().st_size}
    payload=json.dumps({'schema':1,'repository':'jzc9307/VELIN','version':version,'build':build,'notes':entry['notes'][:5000],'mac':artifact('macOS-arm64.zip'),'windows':artifact('Windows-x64.exe')},ensure_ascii=False,separators=(',',':')).encode()
    dest=folder/'VELIN-update.json'
    if dest.exists():
        old=json.loads(dest.read_text())
        if base64.b64decode(old['payload'])==payload:return dest
        raise SystemExit('An update descriptor already exists for different artifacts. Preserve it instead of replacing it.')
    with tempfile.NamedTemporaryFile(prefix='velin-update-payload-',suffix='.json',dir='/private/tmp') as tmp:
        tmp.write(payload);tmp.flush();signature=subprocess.check_output([str(signer),'sign',tmp.name],text=True).strip()
    dest.write_text(json.dumps({'payload':base64.b64encode(payload).decode(),'signature':signature},indent=2)+'\n')
    print('Signed update descriptor:',dest);return dest
if __name__=='__main__':generate(pathlib.Path(sys.argv[1]))
