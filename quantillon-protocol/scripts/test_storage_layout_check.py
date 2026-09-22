import copy
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('layout_check', Path(__file__).with_name('storage-layout-check.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class StorageChecks(unittest.TestCase):
    def setUp(self):
        self.layout = {'storage': [{'slot':'0','offset':0,'type':'map1'}], 'types': {
            'map1': {'encoding':'mapping','label':'mapping(address => struct State)','numberOfBytes':'32','key':'address','value':'struct1'},
            'address': {'encoding':'inplace','label':'address','numberOfBytes':'20'},
            'uint': {'encoding':'inplace','label':'uint128','numberOfBytes':'16'},
            'struct1': {'encoding':'inplace','label':'struct State','numberOfBytes':'32','members':[
                {'slot':'0','offset':0,'type':'uint'}, {'slot':'0','offset':16,'type':'uint'}]}}}
    def test_member_move_with_unchanged_outer_size_is_rejected(self):
        changed=copy.deepcopy(self.layout); changed['types']['struct1']['members'][1]['offset']=8
        self.assertEqual(m.compare(m.canonical_layout(self.layout),m.canonical_layout(changed)),['0:0'])
    def test_mapping_key_change_is_rejected(self):
        changed=copy.deepcopy(self.layout); changed['types']['map1']['key']='uint'
        self.assertTrue(m.compare(m.canonical_layout(self.layout),m.canonical_layout(changed)))
    def test_same_type_member_reorder_is_rejected(self):
        self.layout['types']['struct1']['members'][0]['label']='balance'
        self.layout['types']['struct1']['members'][1]['label']='principal'
        changed=copy.deepcopy(self.layout)
        changed['types']['struct1']['members'][0]['label']='principal'
        changed['types']['struct1']['members'][1]['label']='balance'
        self.assertTrue(m.compare(m.canonical_layout(self.layout),m.canonical_layout(changed)))
    def test_top_level_append_is_allowed(self):
        changed=copy.deepcopy(self.layout);changed['storage'].append({'slot':'1','offset':0,'type':'address'})
        self.assertEqual(m.compare(m.canonical_layout(self.layout),m.canonical_layout(changed)),[])
    def test_ast_id_changes_are_ignored(self):
        changed=copy.deepcopy(self.layout);changed['types']['struct999']=changed['types'].pop('struct1');changed['types']['map1']['value']='struct999'
        self.assertEqual(m.canonical_layout(self.layout),m.canonical_layout(changed))
    def test_array_element_change_is_rejected(self):
        self.layout['types']['map1']={'encoding':'dynamic_array','label':'struct State[]','numberOfBytes':'32','base':'struct1'}
        changed=copy.deepcopy(self.layout);changed['types']['struct1']['members'][0]['type']='address'
        self.assertTrue(m.compare(m.canonical_layout(self.layout),m.canonical_layout(changed)))
if __name__ == '__main__': unittest.main()
