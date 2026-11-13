#!/usr/bin/env python3
"""Local signed XPC security checks; no real credential data is requested."""
import hashlib,pathlib,plistlib,re,shutil,subprocess,tempfile
ROOT=pathlib.Path(__file__).resolve().parents[1]
CACHE=ROOT.parent/'work' if (ROOT.parent/'.velin-workspace').exists() else ROOT/'work'
def run(args):return subprocess.run(args,check=True,text=True,capture_output=True)
def cdhash(app):return re.search(r'CDHash=(\w+)',run(['codesign','-d','--verbose=4',str(app)]).stderr).group(1)
with tempfile.TemporaryDirectory(prefix='velin-credential-check-',suffix='.noindex',dir='/private/tmp') as tmp:
    for name,identifier in [('Allowed','app.velin.assistant'),('Rejected','app.velin.untrusted-probe')]:
        app=pathlib.Path(tmp)/(name+'.app');(app/'Contents/MacOS').mkdir(parents=True)
        (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':identifier,'CFBundleExecutable':'Probe','CFBundlePackageType':'APPL','CFBundleVersion':'1'}))
        run(['xcrun','swiftc','-swift-version','5','-O','-parse-as-library','-module-cache-path',str(CACHE/'swift-cache'),str(ROOT/'Sources/CredentialProtocol.swift'),str(ROOT/'Tests/CredentialProbe.swift'),'-o',str(app/'Contents/MacOS/Probe')])
        run(['python3',str(ROOT/'scripts/build-credentials.py'),str(app),str(CACHE)])
        run(['python3',str(ROOT/'scripts/signing.py'),'sign',str(app),'--bundle-id',identifier])
        result=subprocess.run([str(app/'Contents/MacOS/Probe')],check=True,text=True,capture_output=True,timeout=15)
        print('PASS:',name,'credential client:',result.stdout.strip())
        if name=='Allowed':
            helper=app/'Contents/XPCServices/VELINKeychain.xpc/Contents/MacOS/VELINKeychain'
            before=hashlib.sha256(helper.read_bytes()).hexdigest();old=cdhash(app)
            (app/'Contents/Resources').mkdir();(app/'Contents/Resources/new-main-version.txt').write_text('Changed main-app resource; credential component stays unchanged.\n')
            run(['python3',str(ROOT/'scripts/signing.py'),'sign',str(app),'--bundle-id',identifier])
            assert old!=cdhash(app) and before==hashlib.sha256(helper.read_bytes()).hexdigest()
            subprocess.run([str(app/'Contents/MacOS/Probe')],check=True,capture_output=True,timeout=15)
            print('PASS: changed main-app CDHash retains the identical working credential component')
print('3 signed credential runtime checks passed; no real key values accessed.')
