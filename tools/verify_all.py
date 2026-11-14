"""Reproducible checks and exact command/output evidence, including native flow."""
from pathlib import Path
import json,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
checks=[]
def cli(name,*args):return ['cmd.exe','/d','/c',shutil.which(name),*args]
commands=[('analyze',cli('flutter','analyze'),ROOT),('architecture',[sys.executable,'tools/check_architecture.py'],ROOT)]
for name in ['field_core','field_nasa','field_imagery','field_storage','field_compute']:
    commands.append((name,cli('dart','test'),ROOT/'packages'/name))
commands.extend([('field_maps',cli('flutter','test'),ROOT/'packages/field_maps'),('app_widgets',cli('flutter','test'),ROOT/'apps/field_shift'),('raster_unit',[str(ROOT/'.venv/Scripts/python.exe'),'-m','unittest','discover','-s','packages/field_compute/worker','-p','test_raster.py','-v'],ROOT),('windows_integration',cli('flutter','test','integration_test/windows_flow_test.dart','-d','windows','--dart-define=REPO_ROOT='+ROOT.as_posix()),ROOT/'apps/field_shift')])
for name,args,cwd in commands:
    started=time.perf_counter();result=subprocess.run(args,cwd=cwd,text=True,encoding='utf-8',errors='replace',stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    (ROOT/f'docs/evidence/test_{name}.log').write_text(result.stdout,encoding='utf-8')
    check={'name':name,'command':args,'cwd':str(cwd),'exitCode':result.returncode,'seconds':round(time.perf_counter()-started,3),'log':f'docs/evidence/test_{name}.log'};checks.append(check)
    print(f'{name}: {"PASS" if not result.returncode else "FAIL"} ({check["seconds"]} s)',flush=True)
    if result.returncode:print(result.stdout[-3000:],flush=True)
    (ROOT/'docs/evidence/checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
if any(c['exitCode'] for c in checks):sys.exit(1)
