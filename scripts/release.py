#!/usr/bin/env python3
"""Version and release tooling. See docs/GITHUB.md before publishing."""
import argparse, hashlib, json, pathlib, plistlib, re, subprocess, sys, tempfile, zipfile, shutil
ROOT = pathlib.Path(__file__).resolve().parents[1]
def run(args, cwd=ROOT):
    return subprocess.check_output(args, cwd=cwd, text=True).strip()
def version(): return (ROOT/'VERSION').read_text().strip()
def project(): return ROOT.parent if (ROOT.parent/'.velin-workspace').exists() else ROOT/'dist'
def catalog(): return json.loads((ROOT/'release-history.json').read_text())
def sync(history):
    (ROOT/'release-history.json').write_text(json.dumps(history, indent=2)+'\n')
    rows=['| Version | Status | macOS download |','| --- | --- | --- |']
    for entry in reversed(history):
        link=f"[DMG]({entry['url']})" if entry.get('url') else 'Not published'
        rows.append(f"| {entry['version']} | {entry['status']} | {link} |")
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
    history=catalog(); history.append({'version':v,'build':int(build),'status':'Newest · prepared','url':None,'notes':notes});sync(history)
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
        run(['hdiutil','create','-volname',f'VELIN {version()}','-srcfolder',tmp,'-ov','-format','UDZO',str(dest)])
    print(dest);return dest
def package():
    preflight()
    if run(['git','status','--porcelain']):raise SystemExit('Commit the reviewed source before packaging.')
    out=ROOT/'.release/current';out.mkdir(parents=True,exist_ok=True);v=version();app=project()/'VELIN.app'
    installer=project()/'outputs'/f'VELIN-{v}-macOS-arm64.dmg'
    if not installer.exists():installer=dmg()
    shutil.copy2(installer,out/installer.name)
    run(['ditto','-c','-k','--keepParent',str(app),str(out/f'VELIN-{v}-macOS-arm64.zip')])
    run(['git','archive','--format=zip','--prefix=VELIN/','-o',str(out/f'VELIN-{v}-source.zip'),'HEAD'])
    sums=[]
    for p in sorted(out.iterdir()):
        if p.suffix in ('.zip','.dmg'):sums.append(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.name)
    (out/'SHA256SUMS.txt').write_text('\n'.join(sums)+'\n')
    (out/'manifest.json').write_text(json.dumps({'version':v,'commit':run(['git','rev-parse','HEAD'])},indent=2)+'\n')
    print(out)
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
    assets=[str(p) for p in out.iterdir() if p.suffix in ('.dmg','.zip') or p.name=='SHA256SUMS.txt']
    existing=json.loads(run(['gh','release','view',tag,'--json','assets']))['assets'];names={a['name'] for a in existing}
    for asset in assets:
        if pathlib.Path(asset).name not in names:run(['gh','release','upload',tag,asset])
    run(['gh','release','edit',tag,'--draft=false','--latest'])
    result=json.loads(run(['gh','release','view',tag,'--json','url,assets,isDraft']))
    if result['isDraft'] or not {pathlib.Path(a).name for a in assets}.issubset({a['name'] for a in result['assets']}):raise SystemExit('Release verification failed.')
    entry['url']=next(a['url'] for a in result['assets'] if a['name'].endswith('.dmg'));entry['status']='Latest'
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
