#!/usr/bin/env python3
"""Bundle only the current version's public release notes for the About page."""
import json,pathlib,sys
root=pathlib.Path(__file__).resolve().parents[1]
version=(root/'VERSION').read_text().strip();build=int((root/'BUILD_NUMBER').read_text())
entry=next(e for e in json.loads((root/'release-history.json').read_text()) if e['version']==version)
target=pathlib.Path(sys.argv[1]);target.parent.mkdir(parents=True,exist_ok=True)
target.write_text(json.dumps({'version':version,'build':build,'notes':entry.get('notes','No release notes were provided for this build.')},ensure_ascii=False,indent=2)+'\n')
