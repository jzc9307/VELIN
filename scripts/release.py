#!/usr/bin/env python3
"""Version and release tooling. See docs/GITHUB.md before publishing."""
import argparse, base64, hashlib, json, pathlib, plistlib, re, subprocess, sys, tempfile, zipfile, shutil
ROOT = pathlib.Path(__file__).resolve().parents[1]
def run(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()
def version(): return (ROOT/'VERSION').read_text().strip()
def project(): return ROOT.parent if (ROOT.parent/'.velin-workspace').exists() else ROOT/'dist'
def catalog(): return json.loads((ROOT/'release-history.json').read_text())
def sync(history):
    (ROOT/'release-history.json').write_text(json.dumps(history, indent=2)+'\n')
    rows=['| Version | Status | macOS · Apple Silicon | Windows · x64 |','| --- | --- | --- | --- |']
    for entry in reversed(history):
        link=f"[DMG]({entry['url']})" if entry.get('url') else 'Not published'
        windows=f"[EXE · preview]({entry['windows_url']})" if entry.get('windows_url') else ('Preview · not published' if entry.get('windows_preview') else 'Not available')
        rows.append(f"| {entry['version']} | {entry['status']} | {link} | {windows} |")
    table='\n'.join(rows)
    p=ROOT/'README.md'; text=p.read_text(); a='<!-- VERSIONS:START -->'; b='<!-- VERSIONS:END -->'
    p.write_text(text[:text.index(a)+len(a)]+'\n'+table+'\n'+text[text.index(b):])
    (ROOT/'docs/RELEASES.md').write_text('# All versions\n\n'+table+'\n')
def check():
    v=version(); build=(ROOT/'BUILD_NUMBER').read_text().strip()
    assert re.fullmatch(r'\d+\.\d+\.\d+(?:-(?:alpha|beta|rc)\.\d+)?',v), 'Invalid semantic version'
    info=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes())
    assert info['CFBundleShortVersionString']==v and info['CFBundleVersion']==build, 'App metadata is out of sync'
    assert any(x['version']==v for x in catalog()), 'Current version missing from catalog'
    public=(ROOT/'Resources/UpdatePublicKey.txt').read_text().strip()
    raw=base64.b64decode(public,validate=True)
    assert len(raw)==65 and raw[0]==4, 'Invalid update verification key'
    assert ('static let publicKey = '+json.dumps(public)) in (ROOT/'Sources/UpdateTrust.swift').read_text(), 'Mac and Windows update verification keys differ'
    print(f'VELIN {v} (build {build})')
def prepare(bump='patch'):
    pending=ROOT/'.release/prepared.json'
    if pending.exists():
        print('A release is already prepared. Finish it rather than bumping again.'); return
    bits=version().split('-')[0].split('.'); index={'major':0,'minor':1,'patch':2}[bump]; bits[index]=str(int(bits[index])+1)
    for i in range(index+1,3):bits[i]='0'
    v='.'.join(bits); build=str(int((ROOT/'BUILD_NUMBER').read_text())+1)
    notes=(ROOT/'CHANGELOG.md').read_text().split('## [Unreleased]',1)[1].split('\n## ',1)[0].strip()
    if not notes or notes=='No pending changes.': raise SystemExit('Add real user-facing notes under [Unreleased] first.')
    (ROOT/'VERSION').write_text(v+'\n'); (ROOT/'BUILD_NUMBER').write_text(build+'\n')
    info=plistlib.loads((ROOT/'Resources/Info.plist').read_bytes()); info['CFBundleShortVersionString']=v; info['CFBundleVersion']=build
    (ROOT/'Resources/Info.plist').write_bytes(plistlib.dumps(info))
    history=catalog()
    for old in history:
        if not old.get('url'):old['status']='Local · archived'
    history.append({'version':v,'build':int(build),'status':'Newest · prepared','url':None,'windows_preview':(ROOT/'Windows/VELIN').exists(),'notes':notes});sync(history)
    p=ROOT/'CHANGELOG.md';p.write_text(p.read_text().replace('## [Unreleased]\n'+p.read_text().split('## [Unreleased]\n',1)[1].split('\n## ',1)[0],f'## [Unreleased]\n\nNo pending changes.\n\n## [{v}]\n\n{notes}\n',1))
    pending.parent.mkdir(exist_ok=True);pending.write_text(json.dumps({'version':v,'build':build})+'\n');check()
def preflight():
    check()
    files=run(['git','ls-files','--cached','--others','--exclude-standard']).splitlines()
    secret=re.compile(rb'(?:sk-(?:proj-|ant-)?[a-zA-Z0-9_-]{20,}|AIza[0-9A-Za-z_-]{30,})')
    for name in files:
        path=ROOT/name
        if not path.is_file():continue
        if path.stat().st_size>20_000_000:raise SystemExit(f'Large file requires review: {name}')
        if name.endswith('.env') or '/.env' in name and not name.endswith('.example'):raise SystemExit(f'Environment file requires review: {name}')
        if secret.search(path.read_bytes()):raise SystemExit(f'Possible credential requires review: {name}')
    print('Source preflight passed. Review the Git diff before committing.')
def dmg():
    app=project()/'VELIN.app';out=project()/'outputs';out.mkdir(parents=True,exist_ok=True)
    if not app.exists():raise SystemExit('Build the app first.')
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString']!=version():raise SystemExit('Rebuild the app for the current version.')
    run(['codesign','--verify','--deep','--strict',str(app)])
    dest=out/f'VELIN-{version()}-macOS-arm64.dmg'
    if dest.exists():raise SystemExit(f'Installer already exists: {dest}. Preserve versioned artifacts.')
    with tempfile.TemporaryDirectory(prefix='velin-dmg-') as tmp:
        run(['ditto','--noextattr','--norsrc',str(app),tmp+'/VELIN.app']);pathlib.Path(tmp,'Applications').symlink_to('/Applications')
        pathlib.Path(tmp,'INSTALL.txt').write_text('VELIN '+version()+'\n\nDrag VELIN.app to Applications, then eject this disk image.\nOpen VELIN from Applications and follow setup.\nThe app is free. AI API usage is billed by your chosen provider.\nThis local release is self-signed and not Apple-notarized.\n')
        run(['hdiutil','create','-volname',f'VELIN {version()}','-srcfolder',tmp,'-ov','-format','UDZO',str(dest)])
    print(dest);return dest
def package():
    preflight()
    if run(['git','status','--porcelain']):raise SystemExit('Commit the reviewed source before packaging.')
    out=ROOT/'.release/current';v=version();app=project()/'VELIN.app'
    export=project()/'outputs'/('v'+v)
    if (export/'manifest.json').exists():
        manifest=json.loads((export/'manifest.json').read_text())
        if manifest.get('commit')!=run(['git','rev-parse','HEAD']):raise SystemExit('This version already has a packaged archive from another commit. Preserve it; do not overwrite versioned artifacts.')
        for line in (export/'SHA256SUMS.txt').read_text().splitlines():
            digest,name=line.split('  ',1)
            if pathlib.Path(name).name!=name or hashlib.sha256((export/name).read_bytes()).hexdigest()!=digest:raise SystemExit('Existing package checksum mismatch. Inspect the archive before proceeding.')
        print('Reusing verified package: '+str(export));return
    if out.exists():
        allowed=lambda p:p.is_file() and (p.name in ('SHA256SUMS.txt','manifest.json','NOTES.md','VELIN-update.json') or re.fullmatch(r'VELIN-[0-9.]+-(?:macOS-arm64|Windows-x64|source)\.(?:zip|dmg|exe)',p.name))
        if not all(allowed(p) for p in out.iterdir()):raise SystemExit('Unexpected release-staging files; review them before packaging.')
        shutil.rmtree(out)
    out.mkdir(parents=True)
    info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString']!=v or info['CFBundleVersion']!=(ROOT/'BUILD_NUMBER').read_text().strip():raise SystemExit('Rebuild the app for this version/build.')
    run(['codesign','--verify','--deep','--strict',str(app)])
    installer=project()/'outputs'/f'VELIN-{v}-macOS-arm64.dmg'
    if not installer.exists():installer=dmg()
    shutil.copy2(installer,out/installer.name)
    run(['ditto','-c','-k','--keepParent',str(app),str(out/f'VELIN-{v}-macOS-arm64.zip')])
    run(['git','archive','--format=zip','--prefix=VELIN/','-o',str(out/f'VELIN-{v}-source.zip'),'HEAD'])
    windows=ROOT/'Windows/VELIN'
    if windows.exists():
        record=project()/'work/windows-build.json';build_dir=project()/'work/windows-x64.noindex'
        if not record.exists():raise SystemExit('Build the Windows preview with scripts/build-windows.py first.')
        metadata=json.loads(record.read_text());exe=build_dir/'VELIN.exe'
        if metadata.get('version')!=v or metadata.get('build')!=(ROOT/'BUILD_NUMBER').read_text().strip() or metadata.get('commit')!=run(['git','rev-parse','HEAD']):raise SystemExit('Rebuild Windows from this clean release commit.')
        if not exe.exists() or metadata.get('sha256')!=hashlib.sha256(exe.read_bytes()).hexdigest():raise SystemExit('Windows executable checksum mismatch.')
        worker=build_dir/'VelinSpeech.exe'
        if not worker.exists() or metadata.get('speech_worker_sha256')!=hashlib.sha256(worker.read_bytes()).hexdigest():raise SystemExit('Windows speech worker checksum mismatch.')
        shutil.copy2(exe,out/f'VELIN-{v}-Windows-x64.exe')
        with zipfile.ZipFile(out/f'VELIN-{v}-Windows-x64.zip','w',zipfile.ZIP_DEFLATED) as archive:
            for name in ['VELIN.exe','VelinSpeech.exe','WHISPER-LICENSE.txt','WINDOWS.md','THIRD-PARTY-NOTICES.txt','LICENSE.txt']:archive.write(build_dir/name,'VELIN/'+name)
    run([sys.executable,str(ROOT/'scripts/generate-update.py'),str(out)])
    sums=[]
    for p in sorted(out.iterdir()):
        if p.suffix in ('.zip','.dmg','.exe') or p.name=='VELIN-update.json':sums.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name)
    (out/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n')
    (out/'manifest.json').write_text(json.dumps({'version':v,'build':(ROOT/'BUILD_NUMBER').read_text().strip(),'commit':run(['git','rev-parse','HEAD']),'platforms':['macOS-arm64','Windows-x64-preview'],'windows_runtime_tested':False},indent=2)+'\n')
    entry=next(x for x in catalog() if x['version']==v)
    notes='# VELIN '+v+'\n\n**Free and open source. No VELIN subscription.** AI provider API usage is billed separately.\n\n'+entry.get('notes','')+'\n\nApple Silicon · macOS 14+. Continuous local speech requires macOS 27 and a supported language; other systems use the legacy path. This build is locally self-signed, not Developer ID signed or Apple-notarized.\n\nWindows 11 x64 preview: portable, self-contained EXE (ZIP includes guide and notices). Unsigned; cross-compiled on macOS. Windows runtime/audio/UI testing remains required; it is not full Mac feature parity.\n'
    (out/'NOTES.md').write_text(notes)
    export=project()/'outputs'/('v'+v);export.mkdir(parents=True,exist_ok=True)
    for item in out.iterdir():shutil.copy2(item,export/item.name)
    if hashlib.sha256(installer.read_bytes()).digest()==hashlib.sha256((export/installer.name).read_bytes()).digest():installer.unlink()
    print(export)
def publish(dry=False):
    check();out=ROOT/'.release/current';manifest=json.loads((out/'manifest.json').read_text())
    if manifest['commit']!=run(['git','rev-parse','HEAD']) or run(['git','status','--porcelain']):raise SystemExit('Package must match the current clean commit.')
    remote=run(['git','remote','get-url','origin'])
    if not re.fullmatch(r'(?:https://github.com/|git@github.com:)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?',remote):raise SystemExit('Set the intended GitHub origin first.')
    v=version();tag='v'+v;history=catalog();entry=next(x for x in history if x['version']==v)
    if entry.get('url'):raise SystemExit('This version is already published. Preserve it and prepare a new version.')
    if dry:print(f'Will push main and annotated {tag}, upload DMG/ZIP/source/checksums to a draft, then publish it as Latest. Origin: {remote}');return
    if run(['git','branch','--show-current'])!='main':raise SystemExit('Publish from main.')
    run(['gh','auth','status'])
    remote_tag=run(['git','ls-remote','--tags','origin',f'refs/tags/{tag}^{{}}'])
    if remote_tag and not remote_tag.startswith(manifest['commit']):raise SystemExit('Remote tag exists for a different commit. Never overwrite a published version.')
    tags=run(['git','tag','--list',tag])
    if not tags:run(['git','tag','-a',tag,'-m',f'VELIN {v}'])
    if run(['git','rev-list','-n','1',tag])!=manifest['commit']:raise SystemExit('Local tag does not match packaged source.')
    run(['git','push','origin','main',tag])
    result=subprocess.run(['gh','release','view',tag,'--json','isDraft,url'],cwd=ROOT,capture_output=True,text=True)
    if result.returncode:
        notes=out/'NOTES.md';notes.write_text(entry.get('notes','Initial VELIN release.'))
        run(['gh','release','create',tag,'--draft','--title',f'VELIN {v}','--notes-file',str(notes)])
    elif not json.loads(result.stdout)['isDraft']:raise SystemExit('Release already published. Inspect it before proceeding; assets were not overwritten.')
    assets=[str(p) for p in out.iterdir() if p.suffix in ('.dmg','.zip','.exe') or p.name in ('SHA256SUMS.txt','VELIN-update.json')]
    existing=json.loads(run(['gh','release','view',tag,'--json','assets']))['assets'];names={a['name'] for a in existing}
    for asset in assets:
        if pathlib.Path(asset).name not in names:run(['gh','release','upload',tag,asset])
    run(['gh','release','edit',tag,'--draft=false','--latest'])
    result=json.loads(run(['gh','release','view',tag,'--json','url,assets,isDraft']))
    if result['isDraft'] or not {pathlib.Path(a).name for a in assets}.issubset({a['name'] for a in result['assets']}):raise SystemExit('Release verification failed.')
    entry['url']=next(a['url'] for a in result['assets'] if a['name'].endswith('.dmg'));entry['status']='Latest';entry['windows_url']=next((a['url'] for a in result['assets'] if a['name'].endswith('-Windows-x64.exe')),None)
    for old in history:
        if old!=entry and old.get('url'):old['status']='Published'
    sync(history);run(['git','add','README.md','release-history.json','docs/RELEASES.md']);run(['git','commit','-m',f'Record published VELIN {v} download']);run(['git','push','origin','main'])
    (ROOT/'.release/prepared.json').unlink(missing_ok=True);print(result['url'])
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('command',choices=['check','plan','prepare','preflight','dmg','package','publish']);parser.add_argument('--bump',choices=['patch','minor','major'],default='patch');parser.add_argument('--dry-run',action='store_true');args=parser.parse_args()
    if args.command=='check':check()
    elif args.command=='plan':print('Current:',version(),'Next patch:','.'.join(version().split('.')[:2]+[str(int(version().split('.')[-1])+1)]))
    elif args.command=='prepare':prepare(args.bump)
    elif args.command=='preflight':preflight()
    elif args.command=='dmg':dmg()
    elif args.command=='package':package()
    else:publish(args.dry_run)
