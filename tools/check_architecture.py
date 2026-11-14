"""Checks actual package imports and acyclic dependencies; no Flutter in domain."""
import json,re
from pathlib import Path
root=Path(__file__).resolve().parents[1]
packages={p.name:p for p in (root/'packages').iterdir() if (p/'pubspec.yaml').exists()}
graph={name:set() for name in packages};errors=[]
for name,path in packages.items():
    for f in (path/'lib').rglob('*.dart'):
        source=f.read_text('utf-8-sig')
        for target,suffix in re.findall(r"(?:import|export)\s+['\"]package:([^/]+)/([^'\"]+)",source):
            if target in packages and target!=name:
                graph[name].add(target)
                if suffix.startswith('src/'):errors.append(f'{f}: internal import {target}/{suffix}')
            if name not in ['field_maps'] and target in ['flutter','flutter_riverpod','riverpod']:
                errors.append(f'{f}: forbidden presentation dependency')
        if name=='field_core' and re.search(r"import ['\"](?:dart:io|package:(http|sqlite|sqflite))",source):errors.append(f'{f}: domain depends on IO')
        if name=='field_maps' and re.search(r'earthdata\.nasa|element84\.com|planetarycomputer|normalizedDifference',source):errors.append(f'{f}: provider/science inside renderer')
def visit(node,path):
    if node in path:errors.append('Cycle: '+' -> '.join([*path,node]));return
    for child in graph[node]:visit(child,[*path,node])
for node in graph:visit(node,[])
report={'status':'PASS' if not errors else 'FAIL','dependencies':{k:sorted(v) for k,v in graph.items()},'errors':errors}
(root/'docs/evidence/architecture.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2));raise SystemExit(bool(errors))
