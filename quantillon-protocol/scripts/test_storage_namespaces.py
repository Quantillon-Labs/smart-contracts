import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('namespaces', Path(__file__).with_name('check-storage-namespaces.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class NamespaceChecks(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'src').mkdir()
        self.source = self.root / 'src/State.sol'
        self.original = '''contract State {
            bytes32 private constant STATE_STORAGE = keccak256("state.v1");
            struct StateData { uint128 balance; uint128 principal; }
            function state() internal pure returns (StateData storage data) {
                bytes32 slot = STATE_STORAGE;
                assembly { data.slot := slot }
            }
        }'''
        self.source.write_text(self.original)
    def inventory(self):
        with patch.object(m, 'ROOT', self.root):
            return m.inventory()
    def test_anchor_reuse_with_new_hash_is_rejected(self):
        old = self.inventory()
        self.source.write_text(self.original.replace('state.v1', 'state.v2'))
        self.assertTrue(m.violations(old, self.inventory()))
    def test_same_width_member_reorder_is_rejected(self):
        old = self.inventory()
        self.source.write_text(self.original.replace('uint128 balance; uint128 principal;', 'uint128 principal; uint128 balance;'))
        self.assertTrue(m.violations(old, self.inventory()))
    def test_assembly_pointer_retarget_is_rejected(self):
        old = self.inventory()
        self.source.write_text(self.original.replace('data.slot := slot', 'data.slot := 42'))
        self.assertTrue(m.violations(old, self.inventory()))
    def test_removed_reserved_namespace_is_rejected(self):
        old = self.inventory()
        self.source.unlink()
        self.assertTrue(m.violations(old, self.inventory()))

if __name__ == '__main__':
    unittest.main()
