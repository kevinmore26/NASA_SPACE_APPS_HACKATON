"""HTTP interface to the existing Field Shift raster worker and data providers."""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
from contextlib import contextmanager
from datetime import date, datetime, timedelta
from pathlib import Path
from threading import BoundedSemaphore
from typing import Annotated, Literal
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, FiniteFloat

ROOT = Path(__file__).resolve().parents[2]
WORKER = ROOT / 'packages/field_compute/worker/raster_worker.py'
STAC = {
    'sentinel-2-l2a': (
        'https://earth-search.aws.element84.com/v1',
        'ESA/Copernicus · Earth Search',
    ),
    'landsat-c2-l2': (
        'https://planetarycomputer.microsoft.com/api/stac/v1',
        'USGS/NASA · Planetary Computer',
    ),
}
POWER = 'https://power.larc.nasa.gov/api/temporal/daily/point'
CACHE = tempfile.TemporaryDirectory(prefix='field-shift-results-')
ANALYSIS_SLOT = BoundedSemaphore(1)
MAX_UPSTREAM_BYTES = 16 * 1024 * 1024

app = FastAPI(title='NASA Field Shift')
origins = [
    origin.strip()
    for origin in os.environ.get('FIELD_SHIFT_WEB_ORIGIN', '').split(',')
    if origin.strip()
]
if origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_methods=['GET', 'POST'],
        allow_headers=['Content-Type'],
    )


class CatalogSearch(BaseModel):
    bbox: tuple[FiniteFloat, FiniteFloat, FiniteFloat, FiniteFloat]
    datetime: str = Field(max_length=100)
    query: dict[str, dict[str, FiniteFloat]] = Field(default_factory=dict)


class RasterRequest(BaseModel):
    collection: Literal['sentinel-2-l2a', 'landsat-c2-l2']
    sceneId: str = Field(min_length=1, max_length=160, pattern=r'^[A-Za-z0-9._-]+$')
    parcelId: str = Field(min_length=1, max_length=128)
    geometry: list[tuple[FiniteFloat, FiniteFloat]] = Field(min_length=3, max_length=256)
    observation: Literal['rgb', 'falseColor', 'swir', 'red', 'ndvi', 'ndmi', 'temperature']


class PixelRequest(BaseModel):
    longitude: FiniteFloat = Field(ge=-180, le=180)
    latitude: FiniteFloat = Field(ge=-85, le=85)


@contextmanager
def raster_slot():
    if not ANALYSIS_SLOT.acquire(blocking=False):
        raise HTTPException(429, 'A field analysis is in progress. Try again shortly.')
    try:
        yield
    finally:
        ANALYSIS_SLOT.release()


def upstream_json(url, body=None):
    headers = {'User-Agent': 'NASAFieldShift/0.2.2', 'Accept': 'application/json'}
    payload = None
    if body is not None:
        headers['Content-Type'] = 'application/json'
        payload = json.dumps(body).encode('utf-8')
    try:
        with urlopen(Request(url, data=payload, headers=headers), timeout=28) as response:
            content = response.read(MAX_UPSTREAM_BYTES + 1)
        if len(content) > MAX_UPSTREAM_BYTES:
            raise HTTPException(502, 'Data provider returned too much data.')
        return json.loads(content)
    except HTTPError as error:
        status = 404 if error.code == 404 else 502
        raise HTTPException(status, 'The data provider could not return this request.') from error
    except (URLError, ValueError, TimeoutError, OSError) as error:
        raise HTTPException(502, 'The data provider did not respond.') from error


def run_worker(payload):
    try:
        result = subprocess.run(
            [sys.executable, str(WORKER)],
            input=json.dumps({'schema': 1, **payload}).encode('utf-8'),
            capture_output=True,
            timeout=180,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        raise HTTPException(504, 'The satellite image took too long to process.') from error
    if result.returncode:
        try:
            detail = json.loads(result.stderr.decode().splitlines()[-1])['error']
        except (ValueError, IndexError, KeyError, TypeError):
            detail = 'The worker could not process this scene.'
        raise HTTPException(422, detail)
    try:
        return json.loads(result.stdout)
    except ValueError as error:
        raise HTTPException(502, 'The satellite worker returned an invalid result.') from error


@app.get('/health')
def health():
    return {'status': 'ok'}


@app.post('/api/catalog/{provider}')
def catalog(provider: Literal['sentinel', 'landsat'], search: CatalogSearch):
    west, south, east, north = search.bbox
    if not (-180 <= west < east <= 180 and -85 <= south < north <= 85):
        raise HTTPException(422, 'Invalid parcel bounds.')
    if east - west > 1 or north - south > 1:
        raise HTTPException(422, 'Choose a field within a one-degree box.')
    try:
        start, end = (datetime.fromisoformat(value) for value in search.datetime.split('/'))
        if end < start:
            raise ValueError()
    except (ValueError, TypeError) as error:
        raise HTTPException(422, 'Invalid image dates.') from error
    clouds = search.query.get('eo:cloud_cover', {}).get('lte', 80)
    if not 0 <= clouds <= 100:
        raise HTTPException(422, 'The cloud limit must be between 0 and 100.')
    collection = 'sentinel-2-l2a' if provider == 'sentinel' else 'landsat-c2-l2'
    return upstream_json(STAC[collection][0] + '/search', {
        'collections': [collection],
        'bbox': search.bbox,
        'datetime': search.datetime,
        'limit': 30,
        'query': {'eo:cloud_cover': {'lte': clouds}},
    })


@app.get('/api/weather')
def weather(
    longitude: Annotated[float, Query(ge=-180, le=180)],
    latitude: Annotated[float, Query(ge=-85, le=85)],
    start: Annotated[str, Query(pattern=r'^\d{8}$')],
    end: Annotated[str, Query(pattern=r'^\d{8}$')],
):
    try:
        period = date.fromisoformat(end) - date.fromisoformat(start)
        if not timedelta(0) <= period <= timedelta(days=366):
            raise ValueError()
    except ValueError as error:
        raise HTTPException(422, 'Choose up to one year of weather data.') from error
    query = urlencode({
        'longitude': longitude,
        'latitude': latitude,
        'start': start,
        'end': end,
        'parameters': 'T2M,PRECTOTCORR,RH2M,ALLSKY_SFC_SW_DWN',
        'community': 'AG',
        'format': 'JSON',
        'time-standard': 'UTC',
    })
    return upstream_json(f'{POWER}?{query}')


@app.post('/api/raster')
def analyze(request: RasterRequest):
    geometry = request.geometry
    if len(set(geometry)) != len(geometry) or any(
        not (-180 <= lon <= 180 and -85 <= lat <= 85) for lon, lat in geometry
    ):
        raise HTTPException(422, 'Invalid field boundary.')
    lon, lat = zip(*geometry)
    if max(lon) - min(lon) > 1 or max(lat) - min(lat) > 1:
        raise HTTPException(422, 'Choose a smaller field.')
    if request.collection == 'sentinel-2-l2a' and request.observation == 'temperature':
        raise HTTPException(422, 'Choose a Landsat scene for surface temperature.')
    with raster_slot():
        endpoint, provider = STAC[request.collection]
        path = f'/collections/{request.collection}/items/{quote(request.sceneId, safe="")}'
        scene = upstream_json(endpoint + path)
        if scene.get('collection') != request.collection or scene.get('id') != request.sceneId:
            raise HTTPException(502, 'The catalog returned a different satellite image.')
        result = run_worker({
            'scene': {'provider': provider, 'stac': scene},
            'parcel': {'id': request.parcelId, 'geometry': geometry},
            'observation': request.observation,
            'output': CACHE.name,
        })
        png = (Path(CACHE.name) / result['id'] / 'preview.png').read_bytes()
        result['imagePath'] = 'data:image/png;base64,' + base64.b64encode(png).decode('ascii')
        result.pop('numericPath', None)
        return result


@app.post('/api/raster/{result_id}/sample')
def sample(result_id: str, point: PixelRequest):
    if not re.fullmatch(r'[a-f0-9]{64}', result_id):
        raise HTTPException(422, 'Invalid observation ID.')
    with raster_slot():
        raster = Path(CACHE.name) / result_id / 'values.tif'
        if not raster.is_file():
            return {
                'values': None,
                'reason': 'Pixel values expired from the server cache. Analyze the scene again.',
            }
        return run_worker({
            'command': 'sample',
            'numericPath': str(raster),
            'longitude': point.longitude,
            'latitude': point.latitude,
        })


public_files = os.environ.get('FIELD_SHIFT_WEB_ROOT')
if public_files:
    app.mount('/', StaticFiles(directory=public_files, html=True), name='web')
