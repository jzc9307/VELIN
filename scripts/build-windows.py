#!/usr/bin/env python3
"""Build the self-contained Windows x64 preview. May cross-compile on macOS."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess
from windows_pe import inspect
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(args,env):subprocess.run(args,cwd=ROOT,env=env,check=True)
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--dotnet',default=shutil.which('dotnet'));args=parser.parse_args()
    if not args.dotnet:raise SystemExit('Install .NET SDK 10, or supply --dotnet /absolute/path/to/dotnet.')
    workspace=ROOT.parent if (ROOT.parent/'.velin-workspace').exists() else ROOT/'dist'
    work=workspace/'work';out=work/'windows-x64.noindex';out.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy();env.update(DOTNET_CLI_HOME=str(work/'dotnet-home'),NUGET_PACKAGES=str(work/'nuget'),DOTNET_CLI_TELEMETRY_OPTOUT='1',DOTNET_GENERATE_ASPNET_CERTIFICATE='false')
    project='Windows/VELIN/VELIN.csproj'
    run([args.dotnet,'restore',project,'-r','win-x64','--locked-mode','--source','https://api.nuget.org/v3/index.json'],env)
    run([args.dotnet,'run','--project','Windows/VELIN.Core.Tests/VELIN.Core.Tests.csproj','-c','Release'],env)
    run([args.dotnet,'publish',project,'-c','Release','-r','win-x64','--no-restore','-o',str(out),'-p:EnableCompressionInSingleFile=true'],env)
    exe=out/'VELIN.exe';data=exe.read_bytes();pe=inspect(data)
    expected=tuple(map(int,(ROOT/'VERSION').read_text().strip().split('.')))+(int((ROOT/'BUILD_NUMBER').read_text()),)
    if pe['machine']!=0x8664 or pe['subsystem']!=2 or not pe['has_icon'] or expected not in pe['file_versions']:raise SystemExit('Windows x64 GUI/icon/version metadata does not match the release.')
    # Ship the actual runtime and dependency license notices alongside the portable executable.
    assets=json.loads((ROOT/'Windows/VELIN/obj/project.assets.json').read_text())
    packages={name.lower() for name,info in assets['libraries'].items() if info.get('type')=='package' and not name.startswith('Microsoft.NET.ILLink')}
    for framework in assets['project']['frameworks'].values():
        for item in framework.get('downloadDependencies',[]):
            if item['name'].lower().startswith(('microsoft.netcore.app.runtime.win-x64','microsoft.windowsdesktop.app.runtime.win-x64','microsoft.netcore.app.host.win-x64')):
                packages.add(item['name'].lower()+'/'+item['version'].strip('[]').split(',')[0].strip())
    notices=[]
    for package in sorted(packages):
        directory=work/'nuget'/package
        for path in sorted(directory.iterdir()):
            if path.is_file() and path.name.upper() in ('LICENSE','LICENSE.TXT','LICENSE.MD','THIRD-PARTY-NOTICES.TXT','THIRD-PARTY-NOTICES','THIRDPARTYNOTICES.TXT'):
                notices.append(f'\n\n## {package} / {path.name}\n\n'+path.read_text(errors='replace'))
    (out/'THIRD-PARTY-NOTICES.txt').write_text('VELIN Windows dependencies and runtime notices\n'+''.join(notices))
    shutil.copy2(ROOT/'LICENSE',out/'LICENSE.txt');shutil.copy2(ROOT/'docs/WINDOWS.md',out/'WINDOWS.md')
    commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    manifest={'version':(ROOT/'VERSION').read_text().strip(),'build':(ROOT/'BUILD_NUMBER').read_text().strip(),'commit':commit,'sha256':hashlib.sha256(data).hexdigest(),'runtime':'win-x64','runtime_tested':False,'file_version':'.'.join(map(str,expected))}
    (work/'windows-build.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'Windows x64 preview: {exe} ({len(data):,} bytes). Cross-compiled; Windows runtime testing is still required.')
if __name__=='__main__':main()
