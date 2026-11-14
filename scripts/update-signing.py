#!/usr/bin/env python3
"""Explicit update-key setup; private P-256 bytes stay only in login Keychain."""
import hashlib,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def signer():
    work=ROOT.parent/'work' if (ROOT.parent/'.velin-workspace').exists() else ROOT/'dist/work'
    source=ROOT/'ReleaseSigner/main.swift';folder=work/'update-signing.noindex';folder.mkdir(parents=True,exist_ok=True)
    exe=folder/'VELINReleaseSigner';record=folder/'source-hash.txt'
    identity=json.loads((ROOT/'.local-signing.json').read_text())['sha1'];digest=hashlib.sha256(source.read_bytes()+identity.encode()).hexdigest()
    if not exe.exists() or not record.exists() or record.read_text()!=digest:
        subprocess.run(['xcrun','swiftc','-O','-module-cache-path',str(work/'swift-cache'),str(source),'-o',str(exe)],check=True)
        subprocess.run([sys.executable,str(ROOT/'scripts/signing.py'),'sign',str(exe),'--bundle-id','app.velin.release-signer'],check=True)
        record.write_text(digest)
    subprocess.run([sys.executable,str(ROOT/"scripts/signing.py"),"verify",str(exe),"--bundle-id","app.velin.release-signer"],check=True)
    return exe
if __name__=='__main__':
    if len(sys.argv)!=2 or sys.argv[1] not in ('setup','public'):raise SystemExit('Usage: update-signing.py setup|public')
    tool=signer()
    if sys.argv[1]=='setup' and (ROOT/'Resources/UpdatePublicKey.txt').exists():
        public=subprocess.check_output([str(tool),'public'],text=True).strip()
    else:public=subprocess.check_output([str(tool),sys.argv[1]],text=True).strip()
    if sys.argv[1]=='setup':
        path=ROOT/'Resources/UpdatePublicKey.txt'
        if path.exists() and path.read_text().strip()!=public:raise SystemExit('An existing public update key differs. Do not rotate an installed trust key implicitly.')
        path.write_text(public+'\n')
        (ROOT/'Sources/UpdateTrust.swift').write_text('import Foundation\n\nenum UpdateTrust {\n    static let publicKey = "'+public+'"\n}\n')
        print('Update-signing key is in login Keychain. Public verification key saved; no private key exported.')
    else:print(public)
