"""Exercise the actual docs workflow's destructive rebuild with offline tool stubs."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import textwrap
import unittest


class GuidePublicationTest(unittest.TestCase):
    def test_consolidation_survives_rebuild_and_is_navigable(self):
        root = Path(__file__).resolve().parents[2]
        workflow = (root / '.github/workflows/forge-docs.yml').read_text()
        step = workflow.split('      - name: Generate docs with correct GitHub URLs\n', 1)[1]
        block = step.split('        run: |\n', 1)[1].split('\n      - name:', 1)[0]
        script = textwrap.dedent(block)
        self.assertIn('rm -rf docs', script)
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            docs = repo / 'quantillon-protocol/docs'
            docs.mkdir(parents=True)
            guide = 'Signed-Quotes-Consolidation.md'
            content = (root / 'quantillon-protocol/docs' / guide).read_text()
            (docs / guide).write_text(content)
            bin_dir = repo / 'bin'
            bin_dir.mkdir()
            stubs = {
                'git': 'echo https://example.invalid/offline.git\n',
                'forge': 'mkdir -p docs/src; printf "# Summary\\n- [Home](README.md)\\n" > docs/src/SUMMARY.md\n',
                'mdbook': 'mkdir -p docs/book; echo offline > docs/book/index.html\n',
            }
            for name, body in stubs.items():
                tool = bin_dir / name
                tool.write_text('#!/bin/sh\nset -eu\n' + body)
                tool.chmod(0o700)
            # Isolate the workflow's scratch path as well as its output directory.
            script = script.replace('/tmp/custom-docs', str(repo / 'custom-docs'))
            subprocess.run(['bash', '-euo', 'pipefail', '-c', script], cwd=repo,
                           env={**os.environ, 'PATH': f'{bin_dir}:{os.environ["PATH"]}'},
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertEqual((docs / 'src' / guide).read_text(), content)
            self.assertRegex((docs / 'src/SUMMARY.md').read_text(),
                             re.escape(f']({guide})'))


if __name__ == '__main__':
    unittest.main()
