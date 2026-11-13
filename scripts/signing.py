#!/usr/bin/env python3
"""Persistent local signing. Setup is explicit; private material is never versioned.
No certificate trust-store changes are made. Imported keys permit /usr/bin/codesign.
"""
import argparse,json,os,pathlib,re,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
CONFIG=ROOT/'.local-signing.json'
LABEL='VELIN Local Development'
BUNDLE='app.velin.assistant'
def output(args):return subprocess.check_output(args,text=True).strip()
def identity():
    if not CONFIG.exists():raise SystemExit('Run python3 scripts/signing.py setup once to configure persistent local signing. Setup creates a private signing key in your login Keychain.')
    data=json.loads(CONFIG.read_text())
    if not re.fullmatch(r'[0-9a-fA-F]{40}',data.get('sha1','')):raise SystemExit('Invalid local signing fingerprint.')
    return data
def requirement(data,bundle=BUNDLE):return 'identifier "'+bundle+'" and anchor H"'+data['sha1']+'"'
def setup():
    if CONFIG.exists():identity();print('Reusing the configured VELIN signing identity.');return
    keychain=output(['security','default-keychain','-d','user']).strip('"')
    listing=output(['security','find-identity','-p','codesigning',keychain])
    existing=set(re.findall(r'\b([0-9a-fA-F]{40})\s+"'+re.escape(LABEL)+'"',listing))
    if len(existing)>1:raise SystemExit('Multiple VELIN signing identities exist. Choose the intended identity before continuing.')
    if existing:fingerprint=next(iter(existing)).upper()
    else:
        with tempfile.TemporaryDirectory(prefix='velin-signing-',suffix='.noindex',dir='/private/tmp') as directory:
            folder=pathlib.Path(directory);folder.chmod(0o700)
            private=folder/'private.pem';certificate=folder/'certificate.pem'
            mask=os.umask(0o077)
            try:
                subprocess.run(['openssl','req','-new','-newkey','rsa:3072','-nodes','-x509','-sha256','-days','3650','-subj','/CN='+LABEL+'/O=VELIN Local Development','-addext','basicConstraints=critical,CA:TRUE','-addext','keyUsage=critical,digitalSignature,keyCertSign','-addext','extendedKeyUsage=codeSigning','-keyout',str(private),'-out',str(certificate)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            finally:os.umask(mask)
            fingerprint=output(['openssl','x509','-in',str(certificate),'-noout','-fingerprint','-sha1']).split('=')[-1].replace(':','').upper()
            traditional=folder/'private-traditional.pem'
            subprocess.run(['openssl','rsa','-in',str(private),'-traditional','-out',str(traditional)],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
            traditional.chmod(0o600);private.unlink()
            subprocess.run(['security','import',str(certificate),'-k',keychain,'-t','cert','-f','pemseq'],check=True)
            try:
                subprocess.run(['security','import',str(traditional),'-k',keychain,'-t','priv','-f','openssl','-x','-T','/usr/bin/codesign'],check=True)
            except BaseException:
                subprocess.run(['security','delete-certificate','-Z',fingerprint,keychain],check=False,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
                raise
            traditional.unlink()
    CONFIG.write_text(json.dumps({'sha1':fingerprint,'keychain':keychain,'label':LABEL},indent=2)+'\n');CONFIG.chmod(0o600)
    print('Persistent local signing configured. Private key is non-extractable in login Keychain; system trust is unchanged.')
def verify(app,bundle=BUNDLE):
    data=identity();subprocess.run(['codesign','--verify','--deep','--strict','-R='+requirement(data,bundle),str(app)],check=True)
def sign(app,bundle=BUNDLE):
    data=identity();subprocess.run(['codesign','--force','--sign',data['sha1'],'--keychain',data['keychain'],'--timestamp=none','--identifier',bundle,'--requirements','=designated => '+requirement(data,bundle),str(app)],check=True);verify(app,bundle)
    print('Signed with VELIN’s persistent local identity.')
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('command',choices=['setup','sign','verify']);p.add_argument('app',nargs='?',type=pathlib.Path);p.add_argument('--bundle-id',default=BUNDLE);a=p.parse_args()
    if a.command=='setup':setup()
    elif a.app is None:p.error('App path required')
    elif a.command=='sign':sign(a.app,a.bundle_id)
    else:verify(a.app,a.bundle_id)
