import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch
import numpy as np
import rasterio
from rasterio.transform import from_origin
from rasterio.warp import transform
import raster_worker as w

class ScienceTests(unittest.TestCase):
    def test_json_protocol_uses_utf8_with_windows_console_encoding(self):
        payload = {'schema': 1, 'scene': {'provider': 'ESA/Copernicus · Earth Search'}}
        stream = io.TextIOWrapper(
            io.BytesIO(json.dumps(payload, ensure_ascii=False).encode('utf-8')),
            encoding='cp1252',
        )
        output = io.StringIO()
        with patch('sys.stdin', stream), patch.object(w, 'process', return_value=payload) as process:
            with redirect_stdout(output):
                w.main()
        process.assert_called_once_with(payload)
        self.assertEqual(json.loads(output.getvalue()), payload)

    def test_normalized_difference_zero_invalid_negative(self):
        a=np.array([[.6,0,np.nan,-.1,.4]],dtype='float32');b=np.array([[.2,0,.2,.2,.2]],dtype='float32')
        out=w.normalized_difference(a,b,np.array([[True,True,True,True,False]]))
        self.assertAlmostEqual(float(out[0,0]),.5,places=6);self.assertTrue(np.isnan(out[0,1:]).all())
    def test_quality_sentinel_and_landsat(self):
        scl=np.arange(12);q=w.quality_flags(scl,True)
        self.assertEqual(np.where(~q['invalid'])[0].tolist(),[4,5,6]);self.assertEqual(np.where(q['cloud'])[0].tolist(),[8,9,10]);self.assertTrue(q['shadow'][3])
        self.assertEqual(w.quality_flags(np.array([0,1,2,4,8,16,32,64,128]),False)['invalid'].tolist(),[False,True,True,True,True,True,True,False,False])
    def test_statistics_polygon_and_nan(self):
        v=np.array([[1,np.nan],[3,999]],dtype='float32');s=w.statistics(v,np.array([[True,True],[True,False]]))
        self.assertEqual(s['mean'],2);self.assertEqual(s['median'],2);self.assertEqual(s['stdDev'],1);self.assertEqual(s['validPixels'],2);self.assertAlmostEqual(s['validPercent'],200/3)
    def test_georeferenced_scale_masks_resampling_and_pipeline(self):
        with tempfile.TemporaryDirectory() as folder:
            assets={}; crs='EPSG:32718'; aff=from_origin(375000,8484000,20,20)
            arrays={'scl':np.full((4,4),4,dtype='uint16'),'nir':np.full((8,8),7000,dtype='uint16'),'red':np.full((8,8),3000,dtype='uint16'),'swir16':np.full((4,4),4000,dtype='uint16')}
            arrays['scl'][0,0]=9;arrays['scl'][0,1]=3;arrays['scl'][0,2]=0
            for band,a in arrays.items():
                res=10 if a.shape[0]==8 else 20;path=Path(folder)/(band+'.tif')
                with rasterio.open(path,'w',driver='GTiff',width=a.shape[1],height=a.shape[0],count=1,dtype='uint16',crs=crs,transform=from_origin(375000,8484000,res,res),nodata=0) as ds:ds.write(a,1)
                assets[band]={'href':str(path),'raster:bands':[{'scale':.0001,'offset':-.1,'nodata':0,'spatial_resolution':res}]}
            bounds=(375000,8483920,375080,8484000)
            with patch.object(w,'signed_url',side_effect=lambda url:url):
                q=w.read_window(assets['scl'],bounds,crs,aff,(4,4),quality=True)
                self.assertEqual(q['cloud'].sum(),1);self.assertEqual(q['shadow'].sum(),1);self.assertEqual(q['missing'].sum(),1);self.assertEqual(q['invalid'].sum(),3)
                nir=w.read_window(assets['nir'],bounds,crs,aff,(4,4));red=w.read_window(assets['red'],bounds,crs,aff,(4,4))
                out=w.normalized_difference(nir,red,~q['invalid']);self.assertAlmostEqual(float(np.nanmean(out)),.5,places=6)
                lon,lat=transform(crs,'EPSG:4326',[375000,375080,375080,375000],[8484000,8484000,8483920,8483920])
                req={'scene':{'provider':'TEST FIXTURE — NOT SATELLITE DATA','stac':{'id':'fixture','collection':'sentinel-2-l2a','properties':{'datetime':'2025-01-01T00:00:00Z','s2:processing_baseline':'test'},'assets':assets}},'parcel':{'id':'test','geometry':list(map(list,zip(lon,lat)))},'observation':'ndmi','output':folder}
                r=w.process(req);self.assertAlmostEqual(r['statistics']['mean'],1/3,places=5);self.assertEqual(r['statistics']['validPixels'],13);self.assertEqual(r['resolution'],20);self.assertEqual(r['crs'],crs)
                self.assertTrue(Path(r['imagePath']).exists());self.assertTrue(Path(r['numericPath']).exists())
                again=w.process(req);self.assertEqual(again['id'],r['id'])
                sampled=w.sample({'numericPath':r['numericPath'],'longitude':lon[2],'latitude':lat[2]});self.assertIn('values',sampled)
    def test_rejects_unsupported_url(self):
        with self.assertRaises(ValueError): w.signed_url('file:///secret')
        with self.assertRaises(ValueError): w.signed_url('https://untrusted.example/file.tif')

if __name__=='__main__':unittest.main(verbosity=2)
