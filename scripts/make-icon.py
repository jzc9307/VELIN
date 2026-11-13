#!/usr/bin/env python3
"""Regenerate original VELIN icon using Apple tools; no image package dependency."""
from pathlib import Path
import subprocess,struct,tempfile
root=Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='velin-icon-') as tmp:
    subprocess.run(['xcrun','swift',str(root/'scripts/make-icon.swift'),str(root/'Resources/icon.png')],check=True)
    chunks=[]
    for typ,size in [(b'icp4',16),(b'icp5',32),(b'icp6',64),(b'ic07',128),(b'ic08',256),(b'ic09',512),(b'ic10',1024)]:
        dest=Path(tmp)/f'{size}.png'
        subprocess.run(['sips','-z',str(size),str(size),str(root/'Resources/icon.png'),'--out',str(dest)],check=True,stdout=subprocess.DEVNULL)
        data=dest.read_bytes();chunks.append(typ+struct.pack('>I',len(data)+8)+data)
    body=b''.join(chunks);(root/'Resources/VELIN.icns').write_bytes(b'icns'+struct.pack('>I',len(body)+8)+body)
