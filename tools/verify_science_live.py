"""Explicit real-provider verification. Not part of offline unit tests."""
import json,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'packages/field_compute/worker'))
import raster_worker as worker
import rasterio

evidence=ROOT/'docs/evidence';report=[]
parcel={'id':'live-verification','geometry':[[-76.151,-13.721],[-76.146,-13.721],[-76.146,-13.716],[-76.151,-13.716]]}
for provider,variables in [('sentinel',['rgb','falseColor','swir','red','ndvi','ndmi']),('landsat',['ndvi','ndmi','temperature'])]:
    scenes=json.loads((evidence/f'{provider}_dart_live.json').read_text('utf-8'))
    for index,variable in [(0,v) for v in variables]+([(1,'ndvi')] if provider=='sentinel' else []):
        req={'schema':1,'scene':scenes[index],'parcel':parcel,'observation':variable,'output':str(evidence/'raster_verified')}
        try:
            with rasterio.Env(GDAL_DISABLE_READDIR_ON_OPEN='EMPTY_DIR',CPL_VSIL_CURL_ALLOWED_EXTENSIONS='.tif,.TIF',GDAL_HTTP_TIMEOUT='35',GDAL_HTTP_MAX_RETRY='1',GDAL_CACHEMAX=64*1024*1024):
                started=time.perf_counter();result=worker.process(req)
            (evidence/f'{provider}_{variable}_{index}_verified.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
            row={'provider':provider,'scene':result['sceneId'],'variable':variable,'status':'PASS','statistics':result['statistics'],'seconds':time.perf_counter()-started,'result':f'{provider}_{variable}_{index}_verified.json'}
        except Exception as error:
            row={'provider':provider,'variable':variable,'status':'FAIL','error':type(error).__name__}
        report.append(row);print(json.dumps(row),flush=True)
        (evidence/'science_live_report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
if any(r['status']!='PASS' for r in report):sys.exit(1)
