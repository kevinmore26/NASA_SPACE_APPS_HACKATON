"""NASA Field Shift raster protocol v1. Real, bounded COG windows via GDAL.

No map tiles enter this module. GDAL reprojection averages reflectance when
coarsening; classification flags use max (conservative any-invalid coverage).
Statistics use pixel centres inside the actual polygon; no fractional weighting.
"""
import hashlib
import json
import math
import os
import re
import shutil
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

# GDAL/PROJ resource directories in the standalone Windows distribution.
if getattr(sys,'frozen',False):
    bundle=Path(sys._MEIPASS)
    os.environ.setdefault('GDAL_DATA',str(bundle/'rasterio/gdal_data'))
    os.environ.setdefault('PROJ_DATA',str(bundle/'rasterio/proj_data'))

import certifi
os.environ.setdefault('SSL_CERT_FILE',certifi.where())
import numpy as np
import rasterio
from PIL import Image
from rasterio.enums import Resampling
from rasterio.features import geometry_mask
from rasterio.transform import from_origin, from_bounds
from rasterio.warp import transform_bounds, transform_geom, reproject, transform
from rasterio.windows import from_bounds as window_from_bounds, Window

METHOD = 'field-raster-1.0.2'
MAX_CELLS = 1024 * 1024

def trim_results(root, keep, budget=512*1024*1024):
    """Evict only generated hash directories directly inside the supplied cache."""
    root=Path(root).resolve(); folders=[]
    for child in root.iterdir():
        if child.is_dir() and not child.is_symlink() and re.fullmatch(r'[0-9a-f]{64}',child.name) and child.resolve().parent==root:
            size=sum(p.stat().st_size for p in child.iterdir() if p.is_file())
            folders.append((child,child.stat().st_mtime,size))
    size=sum(x[2] for x in folders)
    for child,_,count in sorted(folders,key=lambda x:x[1]):
        if size<=budget: break
        if child.name==keep: continue
        if child.resolve().parent!=root: raise ValueError('Ruta de caché inválida.')
        shutil.rmtree(child);size-=count

def normalized_difference(a, b, valid):
    denominator = a + b
    valid = valid & np.isfinite(a) & np.isfinite(b) & (a >= 0) & (b >= 0) & (np.abs(denominator) > 1e-8)
    out = np.full(a.shape, np.nan, dtype='float32')
    np.divide(a-b, denominator, out=out, where=valid)
    return out

def quality_flags(raw, sentinel):
    if sentinel:
        return {'cloud': np.isin(raw, [8,9,10]), 'shadow': raw == 3,
                'invalid': ~np.isin(raw,[4,5,6]), 'missing': raw == 0}
    r=raw.astype('uint16')
    return {'cloud': (r & ((1<<1)|(1<<2)|(1<<3))) != 0,
            'shadow': (r & (1<<4)) != 0,
            'invalid': (r & 63) != 0, 'missing': (r & 1) != 0}

def statistics(values, inside):
    samples=values[inside & np.isfinite(values)]
    total=int(np.count_nonzero(inside)); count=int(samples.size)
    result={'validPixels':count,'totalPixels':total,'validPercent':100*count/total if total else 0,
            'mean':None,'min':None,'max':None,'median':None,'stdDev':None}
    if count:
        result.update(mean=float(np.mean(samples,dtype='float64')),min=float(samples.min()),max=float(samples.max()),
                      median=float(np.median(samples)),stdDev=float(np.std(samples,dtype='float64')))
    return result

def signed_url(url):
    parsed=urllib.parse.urlparse(url)
    if parsed.scheme!='https': raise ValueError('Solo se admiten activos HTTPS.')
    if parsed.hostname and parsed.hostname.endswith('.blob.core.windows.net'):
        endpoint='https://planetarycomputer.microsoft.com/api/sas/v1/sign?'+urllib.parse.urlencode({'href':url})
        with urllib.request.urlopen(endpoint,timeout=30) as r: return json.load(r)['href']
    if parsed.hostname not in ['sentinel-cogs.s3.us-west-2.amazonaws.com','sentinel-cogs.s3.amazonaws.com']:
        raise ValueError('Proveedor raster no autorizado por este adaptador.')
    return url

def read_window(asset, bounds, dst_crs, dst_transform, shape, quality=False, sentinel=True):
    """Read only intersecting native-resolution source window, then reproject."""
    href=signed_url(asset['href'])
    with rasterio.open(href) as src:
        if src.crs is None: raise ValueError('La banda carece de CRS.')
        b=transform_bounds(dst_crs,src.crs,*bounds,densify_pts=21)
        win=window_from_bounds(*b,transform=src.transform).round_offsets()
        win=Window(win.col_off-2,win.row_off-2,math.ceil(win.width)+4,math.ceil(win.height)+4)
        try: win=win.intersection(Window(0,0,src.width,src.height))
        except rasterio.errors.WindowError: raise ValueError('La escena no cubre el terreno.')
        if win.width*win.height>MAX_CELLS*9: raise ValueError('Ventana de origen demasiado grande. Reduce el terreno.')
        raw=src.read(1,window=win)
        src_transform=src.window_transform(win)
        if quality:
            flags=quality_flags(raw,sentinel)
            result={}
            for name,flag in flags.items():
                target=np.full(shape,1 if name in ['invalid','missing'] else 0,dtype='uint8')
                reproject(flag.astype('uint8'),target,src_transform=src_transform,src_crs=src.crs,
                          dst_transform=dst_transform,dst_crs=dst_crs,resampling=Resampling.max,src_nodata=255,
                          dst_nodata=255)
                result[name]=(target != 0) if name in ['invalid','missing'] else (target == 1)
            return result
        meta=asset.get('raster:bands',[{}])[0]
        if 'scale' not in meta or 'offset' not in meta:
            raise ValueError('Falta escala/offset verificable en STAC.')
        nodata=meta.get('nodata',src.nodata)
        valid=src.read_masks(1,window=win)>0
        if nodata is not None: valid &= raw != nodata
        values=raw.astype('float32')*meta['scale']+meta['offset']
        values[~valid]=np.nan
        target=np.full(shape,np.nan,dtype='float32')
        reproject(values,target,src_transform=src_transform,src_crs=src.crs,src_nodata=np.nan,
                  dst_transform=dst_transform,dst_crs=dst_crs,dst_nodata=np.nan,resampling=Resampling.average)
        return target

def read_saturation(asset,bounds,crs,affine,shape):
    # Any QA_RADSAT bit invalidates the destination pixel, conservative for all bands.
    with rasterio.open(signed_url(asset['href'])) as src:
        b=transform_bounds(crs,src.crs,*bounds,densify_pts=21)
        win=window_from_bounds(*b,transform=src.transform).round_offsets().round_lengths()
        win=win.intersection(Window(0,0,src.width,src.height))
        raw=src.read(1,window=win)
        out=np.ones(shape,dtype='uint8')
        reproject((raw!=0).astype('uint8'),out,src_transform=src.window_transform(win),src_crs=src.crs,
                  dst_transform=affine,dst_crs=crs,resampling=Resampling.max,src_nodata=255,dst_nodata=255)
        return out.astype(bool)

def process(req):
    started=time.perf_counter()
    scene=req['scene']; item=scene['stac']; parcel=req['parcel']; variable=req['observation']
    props=item['properties']; assets=item['assets']; sentinel=item['collection'].startswith('sentinel-2')
    if not sentinel and props.get('platform') not in ['landsat-8','landsat-9']:
        raise ValueError('Por ahora solo se procesan Landsat 8/9. Selecciona otra escena.')
    polygon={'type':'Polygon','coordinates':[[*parcel['geometry'],parcel['geometry'][0]]]}
    fingerprint=hashlib.sha256(json.dumps(polygon,sort_keys=True).encode()).hexdigest()
    key=hashlib.sha256(json.dumps({'item':item,'polygon':polygon,'variable':variable,'method':METHOD},sort_keys=True).encode()).hexdigest()
    folder=Path(req['output'])/key; result_file=folder/'result.json'
    if result_file.exists():
        cached=json.loads(result_file.read_text('utf-8')); cached['parcelId']=parcel['id']; return cached
    points=parcel['geometry']; lon=sum(p[0] for p in points)/len(points); lat=sum(p[1] for p in points)/len(points)
    if max(p[0] for p in points)-min(p[0] for p in points)>1 or max(p[1] for p in points)-min(p[1] for p in points)>1:
        raise ValueError('Reduce el área: máximo un grado por lado.')
    epsg=(32600 if lat>=0 else 32700)+min(60,int((lon+180)/6)+1)
    crs=f'EPSG:{epsg}'
    resolution=20 if sentinel else (100 if variable=='temperature' else 30)
    projected=transform_geom('EPSG:4326',crs,polygon)
    coords=projected['coordinates'][0]
    left=math.floor(min(p[0] for p in coords)/resolution)*resolution
    right=math.ceil(max(p[0] for p in coords)/resolution)*resolution
    bottom=math.floor(min(p[1] for p in coords)/resolution)*resolution
    top=math.ceil(max(p[1] for p in coords)/resolution)*resolution
    width=max(1,round((right-left)/resolution));height=max(1,round((top-bottom)/resolution))
    if width*height>MAX_CELLS or width>4096 or height>4096: raise ValueError('Terreno demasiado grande para análisis local. Divide el área.')
    affine=from_origin(left,top,resolution,resolution); shape=(height,width);bounds=(left,bottom,right,top)
    inside=geometry_mask([projected],out_shape=shape,transform=affine,invert=True,all_touched=False)
    nir='nir' if sentinel else 'nir08'
    bands={'rgb':['red','green','blue'],'falseColor':[nir,'red','green'],'swir':['swir16',nir,'red'],
           'red':['red'],'ndvi':[nir,'red'],'ndmi':[nir,'swir16'],'temperature':['lwir11']}[variable]
    if any(b not in assets for b in bands): raise ValueError('Esta escena no ofrece todas las bandas necesarias.')
    if variable=='temperature' and sentinel: raise ValueError('Sentinel-2 no mide temperatura superficial.')
    qa_key='scl' if sentinel else 'qa_pixel'
    if qa_key not in assets: raise ValueError('Falta máscara de calidad; no se calcula sin ella.')
    qa=read_window(assets[qa_key],bounds,crs,affine,shape,quality=True,sentinel=sentinel)
    if not sentinel:
        if 'qa_radsat' not in assets: raise ValueError('Falta QA_RADSAT.')
        qa['invalid'] |= read_saturation(assets['qa_radsat'],bounds,crs,affine,shape)
    valid=inside & ~qa['invalid']
    data=[read_window(assets[b],bounds,crs,affine,shape) for b in bands]
    for b in data: valid &= np.isfinite(b)
    if variable in ['ndvi','ndmi']:
        values=normalized_difference(data[0],data[1],valid)[None,:,:]
    else:
        values=np.stack(data)
        if variable=='temperature': values-=273.15
        values[:,~valid]=np.nan
    valid=inside & np.all(np.isfinite(values),axis=0)
    stats=statistics(values[0],inside)
    stats['cloudPixels']=int(np.count_nonzero(inside & qa['cloud']))
    stats['shadowPixels']=int(np.count_nonzero(inside & qa['shadow']))
    stats['missingPixels']=int(np.count_nonzero(inside & qa['missing']))
    folder.mkdir(parents=True,exist_ok=True)
    numeric=folder/'values.tif'
    with rasterio.open(numeric,'w',driver='GTiff',height=height,width=width,count=values.shape[0],dtype='float32',crs=crs,transform=affine,nodata=np.nan,compress='deflate') as dst:
        dst.write(values)
    # PNG is projected to Web Mercator; geographic bounds are for map placement only.
    mb=transform_bounds(crs,'EPSG:3857',*bounds,densify_pts=21)
    iw=width; ih=height; image_transform=from_bounds(*mb,iw,ih)
    preview=np.full((values.shape[0],ih,iw),np.nan,dtype='float32')
    for i,b in enumerate(values):
        reproject(b,preview[i],src_transform=affine,src_crs=crs,src_nodata=np.nan,dst_transform=image_transform,dst_crs='EPSG:3857',dst_nodata=np.nan,resampling=Resampling.nearest)
    pv=np.all(np.isfinite(preview),axis=0)
    safe=np.nan_to_num(preview,nan=0)
    if variable in ['ndvi','ndmi','temperature']:
        lo,hi=(-10,60) if variable=='temperature' else (-1,1)
        t=np.clip((safe[0]-lo)/(hi-lo),0,1)
        rgb=np.stack([210*(1-t)+30*t,95*(1-t)+145*t,45*(1-t)+85*t],axis=-1).astype('uint8')
    else:
        rgb=(np.clip(safe/0.3,0,1)*255).astype('uint8')
        if rgb.shape[0]==1: rgb=np.repeat(rgb,3,axis=0)
        rgb=np.moveaxis(rgb,0,-1)
    rgba=np.dstack([rgb,pv.astype('uint8')*255])
    for name,color in [('cloud',[210,215,225,255]),('shadow',[85,75,110,255])]:
        q=np.zeros((ih,iw),dtype='uint8')
        reproject((qa[name]&inside).astype('uint8'),q,src_transform=affine,src_crs=crs,dst_transform=image_transform,dst_crs='EPSG:3857',resampling=Resampling.nearest,src_nodata=255,dst_nodata=255)
        rgba[q==1]=color
    image_path=folder/'preview.png';Image.fromarray(rgba).save(image_path)
    geographic=transform_bounds('EPSG:3857','EPSG:4326',*mb)
    source_meta={b:{k:v for k,v in assets[b].items() if k in ['href','raster:bands','gsd','eo:bands']} for b in [*bands,qa_key]}
    result={'schema':1,'id':key,'sceneId':item['id'],'parcelId':parcel['id'],'parcelFingerprint':fingerprint,
            'observation':variable,'provider':scene['provider'],'collection':item['collection'],
            'productVersion':props.get('s2:processing_baseline',props.get('landsat:collection_number','unknown')),
            'acquired':props['datetime'],'resolution':resolution,'crs':crs,'transform':list(affine)[:6],
            'imageCrs':'EPSG:3857','bounds':list(geographic),'geometry':polygon,'statistics':stats,
            'imagePath':str(image_path.resolve()),'numericPath':str(numeric.resolve()),'method':METHOD,
            'unit':'°C' if variable=='temperature' else ('unitless index' if variable in ['ndvi','ndmi'] else 'surface reflectance'),
            'bands':bands,'assets':source_meta,'quality':'SCL 4,5,6 only' if sentinel else 'QA_PIXEL bits 0–5 excluded; QA_RADSAT any bit excluded',
            'resampling':'average reflectance; conservative max invalid QA; pixel-centre polygon inclusion',
            'uncertainty':'No quantitative uncertainty estimated. Mixed edge pixels; atmospheric residuals and mask errors remain. Not an agronomic diagnosis.',
            'warnings':(['Pocos píxeles: interpretación parcelaria poco fiable.'] if stats['validPixels']<9 else [])+(['Sin píxeles válidos para este terreno y fecha.'] if not stats['validPixels'] else []),
            'elapsedSeconds':time.perf_counter()-started}
    result_file.write_text(json.dumps(result,allow_nan=False),encoding='utf-8')
    trim_results(req['output'],key)
    return result

def sample(req):
    with rasterio.open(req['numericPath']) as src:
        x,y=transform('EPSG:4326',src.crs,[req['longitude']],[req['latitude']])
        row,col=src.index(x[0],y[0])
        if row<0 or col<0 or row>=src.height or col>=src.width: return {'values':None,'reason':'Fuera del resultado.'}
        values=src.read(window=Window(col,row,1,1))[:,0,0]
        return {'values':[float(v) if np.isfinite(v) else None for v in values],'row':row,'column':col}

def main():
    # The desktop process sends UTF-8 JSON on all platforms.
    req=json.load(sys.stdin.buffer)
    if req.get('schema')!=1: raise ValueError('Protocolo incompatible.')
    env=dict(GDAL_DISABLE_READDIR_ON_OPEN='EMPTY_DIR',CPL_VSIL_CURL_ALLOWED_EXTENSIONS='.tif,.TIF',GDAL_HTTP_TIMEOUT='35',GDAL_HTTP_MAX_RETRY='1',GDAL_CACHEMAX=64*1024*1024,VSI_CACHE=False)
    with rasterio.Env(**env):
        result=sample(req) if req.get('command')=='sample' else process(req)
    print(json.dumps(result,allow_nan=False))

if __name__=='__main__':
    try: main()
    except Exception as error:
        # Do not expose signed URLs or credentials from GDAL errors.
        message=str(error)
        if 'http' in message.lower() or 'sig=' in message.lower(): message='No se pudo leer el recurso remoto. Comprueba conexión y disponibilidad del activo.'
        print(json.dumps({'error':message}),file=sys.stderr);sys.exit(1)
