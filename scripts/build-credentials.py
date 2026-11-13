#!/usr/bin/env python3
"""Build/reuse the stable signed credential component, separate from UI changes."""
import hashlib,json,pathlib,subprocess,sys,tempfile,shutil
ROOT=pathlib.Path(__file__).resolve().parents[1]
app=pathlib.Path(sys.argv[1]);cache=pathlib.Path(sys.argv[2]);check='--check' in sys.argv
inputs=['Sources/CredentialProtocol.swift','Sources/RawKeychain.swift','Sources/CredentialBroker/main.swift','Resources/CredentialBroker/Info.plist']
identity='' if check else json.loads((ROOT/'.local-signing.json').read_text())['sha1']
version=subprocess.check_output(['xcrun','swiftc','--version'])
fingerprint=hashlib.sha256(b''.join((ROOT/p).read_bytes() for p in inputs)+version+identity.encode()+b'LC_UUID-required-v1').hexdigest()
folder=cache/'credential-broker.noindex';broker=folder/'VELINKeychain.xpc';record=folder/'source-hash.txt'
if check or not record.exists() or record.read_text().strip()!=fingerprint:
    with tempfile.TemporaryDirectory(prefix='velin-credentials-',suffix='.noindex',dir='/private/tmp') as tmp:
        built=pathlib.Path(tmp)/'VELINKeychain.xpc';(built/'Contents/MacOS').mkdir(parents=True)
        shutil.copy2(ROOT/inputs[-1],built/'Contents/Info.plist')
        subprocess.run(['xcrun','swiftc','-swift-version','5','-O','-module-cache-path',str(cache/'swift-cache'),'-target','arm64-apple-macos14','-module-name','VELINCredentials',*[str(ROOT/p) for p in inputs[:-1]],'-o',str(built/'Contents/MacOS/VELINKeychain')],check=True)
        if check:
            dest=app/'Contents/XPCServices/VELINKeychain.xpc';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copytree(built,dest)
            print('Credential component compiled for validation; signed continuity cache preserved.')
            sys.exit(0)
        subprocess.run(['python3',str(ROOT/'scripts/signing.py'),'sign',str(built),'--bundle-id','app.velin.assistant.credentials'],check=True)
        if folder.exists():shutil.rmtree(folder)
        folder.mkdir(parents=True);shutil.copytree(built,broker);record.write_text(fingerprint+'\n')
if not check:subprocess.run(['python3',str(ROOT/'scripts/signing.py'),'verify',str(broker),'--bundle-id','app.velin.assistant.credentials'],check=True)
dest=app/'Contents/XPCServices/VELINKeychain.xpc';dest.parent.mkdir(parents=True,exist_ok=True);shutil.copytree(broker,dest)
print('Credential component reused unchanged.' if not check else 'Credential component compiled for validation.')
