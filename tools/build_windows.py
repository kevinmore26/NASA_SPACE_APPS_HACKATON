"""Build/package without changing the machine's PowerShell execution policy."""
from pathlib import Path
import glob,shutil,subprocess,sys
ROOT=Path(__file__).resolve().parents[1]
def run(args,cwd):
    result=subprocess.run(args,cwd=cwd,text=True,encoding='utf-8',errors='replace',stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    with (ROOT/'docs/evidence/build_windows.log').open('a',encoding='utf-8') as log:log.write(result.stdout+'\n')
    print(result.stdout[-1500:],flush=True)
    if result.returncode:raise SystemExit(result.returncode)
run([str(ROOT/'.venv/Scripts/python.exe'),'-m','PyInstaller','--noconfirm','--distpath','build/worker','--workpath','build/pyinstaller','tools/raster_worker.spec'],ROOT)
run(['cmd.exe','/d','/c',shutil.which('flutter'),'build','windows','--release'],ROOT/'apps/field_shift')
release=ROOT/'apps/field_shift/build/windows/x64/runner/Release'
shutil.copytree(ROOT/'build/worker/raster_worker',release/'workers/raster_worker',dirs_exist_ok=True)
crt=sorted(glob.glob('C:/Program Files/Microsoft Visual Studio/*/*/VC/Redist/MSVC/*/x64/Microsoft.VC*.CRT'))
if not crt:raise RuntimeError('No se encontró runtime redistribuible MSVC.')
for dll in Path(crt[-1]).glob('*.dll'):shutil.copy2(dll,release/dll.name)
shutil.copy2(ROOT/'docs/USO_WINDOWS.md',release/'USO_WINDOWS.md')
bundle=ROOT/'dist/NASA_Field_Shift_Windows_0.2.2'
shutil.copytree(release,bundle,dirs_exist_ok=True)
print(bundle/'field_shift.exe')
