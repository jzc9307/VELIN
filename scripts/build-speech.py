#!/usr/bin/env python3
"""Build the offline worker from pinned whisper.cpp. Optional Windows cross-build."""
import argparse,hashlib,pathlib,platform,shutil,subprocess,tarfile,shlex
ROOT=pathlib.Path(__file__).resolve().parents[1]
COMMIT='d1be6fde11ac6e0407606b4e42fe72d34add8037' # whisper.cpp v1.9.5
SHA256='645445da884df6dbd52b30f82d7be7c01d1767c938714e477e786b88d529e9f4'
def main():
    p=argparse.ArgumentParser();p.add_argument('--destination',type=pathlib.Path,required=True);p.add_argument('--cpu',action='store_true');p.add_argument('--windows',action='store_true');p.add_argument('--zig',type=pathlib.Path);a=p.parse_args()
    project=ROOT.parent if (ROOT.parent/'.velin-workspace').exists() else ROOT/'dist';cache=project/'work/whisper.noindex';cache.mkdir(parents=True,exist_ok=True)
    archive=cache/'source.tar.gz';source=cache/'source'
    if not archive.exists():subprocess.run(['curl','--fail','--location','--proto','=https','--tlsv1.2','https://codeload.github.com/ggml-org/whisper.cpp/tar.gz/'+COMMIT,'-o',str(archive)],check=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA256:raise SystemExit('Whisper source integrity check failed.')
    if not source.exists():
        with tarfile.open(archive) as bundle:bundle.extractall(cache,filter='data')
        (cache/('whisper.cpp-'+COMMIT)).rename(source)
    cmake=str(project/'work/cmake-runtime.noindex/cmake/data/bin/cmake') if (project/'work/cmake-runtime.noindex/cmake/data/bin/cmake').exists() else 'cmake'
    build=cache/('windows-build' if a.windows else 'cpu-build-native' if a.cpu else 'build-native')
    args=[cmake,'-S',str(ROOT/'SpeechWorker'),'-B',str(build),'-DWHISPER_SOURCE='+str(source),'-DCMAKE_BUILD_TYPE=Release']
    if a.windows:
        if not a.zig:raise SystemExit('--windows cross-build requires --zig /path/to/zig.')
        wrappers={}
        for kind,command in [('c','cc'),('cxx','c++'),('ar','ar'),('ranlib','ranlib')]:
            path=cache/('zig-'+kind);extra=' -target x86_64-windows-gnu' if kind in ('c','cxx') else ''
            path.write_text('#!/bin/sh\nexec '+shlex.quote(str(a.zig.resolve()))+' '+command+extra+' "$@"\n');path.chmod(0o755);wrappers[kind]=path
        toolchain=cache/'windows-toolchain.cmake'
        toolchain.write_text('set(CMAKE_SYSTEM_NAME Windows)\nset(CMAKE_SYSTEM_PROCESSOR x86_64)\nset(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)\n'+''.join('set('+name+' "'+str(wrappers[kind])+'")\n' for name,kind in [('CMAKE_C_COMPILER','c'),('CMAKE_CXX_COMPILER','cxx'),('CMAKE_AR','ar'),('CMAKE_RANLIB','ranlib')]))
        args+=['-DCMAKE_TOOLCHAIN_FILE='+str(toolchain),'-DGGML_METAL=OFF','-DGGML_OPENMP=OFF','-DGGML_BLAS=OFF','-DGGML_LLAMAFILE=OFF','-DGGML_AVX=OFF','-DGGML_AVX2=OFF','-DGGML_FMA=OFF','-DGGML_F16C=OFF']
    elif platform.system()=='Windows':args+=['-DGGML_OPENMP=OFF','-DGGML_AVX=OFF','-DGGML_AVX2=OFF','-DGGML_FMA=OFF','-DGGML_F16C=OFF']
    elif platform.system()=='Darwin':args+=['-DCMAKE_OSX_DEPLOYMENT_TARGET=14.0','-DCMAKE_OSX_ARCHITECTURES=arm64','-DGGML_METAL='+('OFF' if a.cpu else 'ON')]
    subprocess.run(args,check=True);subprocess.run([cmake,'--build',str(build),'--config','Release','--target','VelinSpeech','--parallel','4'],check=True)
    name='VelinSpeech.exe' if a.windows or platform.system()=='Windows' else 'VelinSpeech';binary=build/name
    if not binary.exists():binary=build/'Release'/name
    a.destination.mkdir(parents=True,exist_ok=True);shutil.copy2(binary,a.destination/name);shutil.copy2(source/'LICENSE',a.destination/'WHISPER-LICENSE.txt')
    print('Built pinned local speech worker: '+str(a.destination/name))
if __name__=='__main__':main()
