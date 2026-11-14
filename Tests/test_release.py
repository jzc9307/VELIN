import importlib.util,json,pathlib,plistlib,shutil,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('release',ROOT/'scripts/release.py');release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
class Releases(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=pathlib.Path(self.temp.name)
        for name in ['VERSION','BUILD_NUMBER','README.md','CHANGELOG.md','release-history.json','Resources/Info.plist','Resources/UpdatePublicKey.txt','Sources/UpdateTrust.swift']:
            dest=self.root/name;dest.parent.mkdir(exist_ok=True);shutil.copy2(ROOT/name,dest)
        (self.root/'docs').mkdir();self.old=release.ROOT;release.ROOT=self.root;self.addCleanup(setattr,release,'ROOT',self.old)
    def test_metadata(self):release.check()
    def test_patch_and_idempotent_prepare(self):
        (self.root/'CHANGELOG.md').write_text('# Changelog\n\n## [Unreleased]\n\n- Improve connection switching.\n\n## [0.1.0]\n\n- Initial.\n')
        original=release.version();bits=original.split('.');bits[2]=str(int(bits[2])+1);expected='.'.join(bits)
        original_build=int((self.root/'BUILD_NUMBER').read_text())
        release.prepare();self.assertEqual(release.version(),expected);release.prepare();self.assertEqual(release.version(),expected)
        self.assertEqual(plistlib.loads((self.root/'Resources/Info.plist').read_bytes())['CFBundleVersion'],str(original_build+1))
        self.assertIn(original,(self.root/'README.md').read_text());self.assertIn(expected,(self.root/'README.md').read_text())
        self.assertIn('## ['+expected+']',(self.root/'CHANGELOG.md').read_text());self.assertIn('Improve connection switching',json.loads((self.root/'release-history.json').read_text())[-1]['notes'])
    def test_empty_notes_rejected(self):
        (self.root/'CHANGELOG.md').write_text('## [Unreleased]\n\nNo pending changes.\n');self.assertRaises(SystemExit,release.prepare)
    def test_mismatch_detected(self):
        (self.root/'BUILD_NUMBER').write_text('999\n');self.assertRaises(AssertionError,release.check)
    def test_no_invented_download(self):
        history=release.catalog();published=[e.get('url') for e in history if e.get('url')];release.sync(history)
        text=(self.root/'README.md').read_text();self.assertIn('Not published',text)
        for link in published:self.assertIn(link,text)
        for entry in history:
            if not entry.get('url'):
                row=next(line for line in text.splitlines() if line.startswith('| '+entry['version']+' |'));self.assertNotIn('https://',row)
if __name__=='__main__':unittest.main()
