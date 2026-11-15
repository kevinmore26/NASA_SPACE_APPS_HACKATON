"""Reusable crop suitability recommender for Python web backends."""
from pathlib import Path
from datetime import datetime, timedelta, timezone
import hashlib, json, re, time
import numpy as np
import pandas as pd
import requests

API="https://power.larc.nasa.gov/api/temporal/daily/point"
ECO="https://raw.githubusercontent.com/openCLIM/ecocrop/main/EcoCrop_DB.csv"
PARAMS=["T2M","T2M_MIN","T2M_MAX","PRECTOTCORR","RH2M","ALLSKY_SFC_SW_DWN","WS10M"]
SOIL=["soil_ph","soil_texture","soil_depth","soil_ec_ds_m","soil_drainage"]



class CropRecommender:
    """Rule-based EcoCrop scoring. Instantiate with GPS, then call recommend()."""
    def __init__(self, latitude, longitude, *, radius_km=40, ring_points=8,
                 test_points=None, start_date="20150101", end_date="20241231",
                 cache_ttl_days=30, soil=None, irrigation_mm_per_cycle=None,
                 data_dir=None, save_outputs=False, timeout=180, zone_name="Zona agrícola"):
        self.lat,self.lon=float(latitude),float(longitude)
        self.radius,self.ring=float(radius_km),int(ring_points)
        self.tests=test_points or []; self.start,self.end=start_date,end_date
        self.ttl=int(cache_ttl_days); self.soil=soil or {}
        self.irrigation=irrigation_mm_per_cycle; self.save_outputs=save_outputs; self.timeout=timeout
        self.zone_name=str(zone_name).strip() or "Zona agrícola"
        self.data=Path(data_dir) if data_dir else Path(__file__).resolve().parent/"data"
        self.cache=self.data/"power_cache"; self.cache.mkdir(parents=True,exist_ok=True)
        self.ecofile=self.data/"EcoCrop_DB.csv"; self.http=requests.Session()
        if not -90<=self.lat<=90 or not -180<=self.lon<=180: raise ValueError("GPS inválido.")
        if self.radius<=0 or self.ring<0 or self.ttl<0: raise ValueError("Radio, anillo o TTL inválido.")
        datetime.strptime(self.start,"%Y%m%d"); datetime.strptime(self.end,"%Y%m%d")
        if self.end<=self.start: raise ValueError("Rango de fechas inválido.")

    @staticmethod
    def _dist(a,b,c,d):
        r=6371.0088; p=np.radians(a); q=np.radians(c)
        x=np.sin(np.radians(c-a)/2)**2+np.cos(p)*np.cos(q)*np.sin(np.radians(d-b)/2)**2
        return float(2*r*np.arcsin(np.sqrt(x)))

    @staticmethod
    def _destination(lat,lon,dist,bearing):
        r=6371.0088; p,l,b=np.radians([lat,lon,bearing]); d=dist/r
        q=np.arcsin(np.sin(p)*np.cos(d)+np.cos(p)*np.sin(d)*np.cos(b))
        z=l+np.arctan2(np.sin(b)*np.sin(d)*np.cos(p),np.cos(d)-np.sin(p)*np.sin(q))
        return float(np.degrees(q)),float((np.degrees(z)+540)%360-180)

    def _points(self):
        pts=[{"id":"centro","lat":self.lat,"lon":self.lon,"distance_km":0.,"source":"centro"}]
        for i in range(self.ring):
            bearing=360*i/self.ring; lat,lon=self._destination(self.lat,self.lon,self.radius,bearing)
            pts.append({"id":f"anillo_{bearing:03.0f}","lat":lat,"lon":lon,"distance_km":self.radius,"source":"anillo"})
        for i,p in enumerate(self.tests,1):
            lat,lon=float(p["lat"]),float(p["lon"]); dist=self._dist(self.lat,self.lon,lat,lon)
            if dist>self.radius+.05: raise ValueError(f"Punto {p.get('id',i)} queda fuera del radio: {dist:.1f} km.")
            row={"id":str(p.get("id",f"prueba_{i}")),"lat":lat,"lon":lon,"distance_km":round(dist,2),"source":"prueba"}
            row.update({k:p.get(k) for k in SOIL}); pts.append(row)
        out=[]; seen=set()
        for p in pts:
            key=round(p["lat"],6),round(p["lon"],6)
            if key not in seen: seen.add(key); p["id"]=f"punto_{len(out)+1}_{p['id']}"; out.append(p)
        return out

    def _weather(self,p):
        key=hashlib.sha1(f"{p['lat']:.5f},{p['lon']:.5f},{self.start},{self.end}".encode()).hexdigest()[:20]
        csv=self.cache/f"power_{key}.csv"; meta=self.cache/f"power_{key}.json"
        if csv.exists() and meta.exists():
            age=datetime.now(timezone.utc)-datetime.fromtimestamp(csv.stat().st_mtime,timezone.utc)
            if age<=timedelta(days=self.ttl): return pd.read_csv(csv,index_col=0,parse_dates=True)
        q={"parameters":",".join(PARAMS),"community":"AG","longitude":p["lon"],"latitude":p["lat"],
           "start":self.start,"end":self.end,"format":"JSON","time-standard":"UTC"}
        r=self.http.get(API,params=q,timeout=self.timeout); r.raise_for_status(); data=r.json()
        values=data.get("properties",{}).get("parameter",{})
        if any(k not in values for k in PARAMS): raise RuntimeError("Respuesta incompleta de NASA POWER.")
        df=pd.DataFrame(values); df.index=pd.to_datetime(df.index,format="%Y%m%d",errors="coerce")
        df.index.name="date"; df=df.apply(pd.to_numeric,errors="coerce")
        df=df.replace(data.get("header",{}).get("fill_value",-999),np.nan).dropna(subset=PARAMS)
        df.to_csv(csv,encoding="utf-8"); meta.write_text(json.dumps(data.get("header",{})),encoding="utf-8")
        return df

    def clear_cache(self, delete_all=False):
        """Delete expired cache entries or all cached NASA responses."""
        cutoff=datetime.now(timezone.utc)-timedelta(days=self.ttl); n=0
        for f in self.cache.glob("power_*"):
            if delete_all or datetime.fromtimestamp(f.stat().st_mtime,timezone.utc)<cutoff:
                f.unlink(missing_ok=True); n+=1
        return n

    def _crops(self):
        if not self.ecofile.exists():
            r=self.http.get(ECO,timeout=self.timeout); r.raise_for_status()
            self.data.mkdir(parents=True,exist_ok=True); self.ecofile.write_bytes(r.content)
        try:
            df = pd.read_csv(self.ecofile, low_memory=False, encoding='latin-1', sep=",")
        except UnicodeDecodeError:
            df = pd.read_csv(self.ecofile, low_memory=False, encoding='ascii', sep=",")
        df.columns = [str(c).strip().lstrip("\ufeff").upper() for c in df.columns]
        req=["TMIN","TOPMN","TOPMX","TMAX","ROPMN","ROPMX","RMIN","RMAX","GMIN","GMAX"]
        missing = [k for k in req if k not in df.columns]
        if missing:
            detected = ", ".join(map(str, df.columns[:20]))
            raise ValueError(
                f"No se reconocieron columnas EcoCrop en {self.ecofile}. "
                f"Faltan: {missing}. Encabezado detectado: {detected}"
            )
        for k in req+["PHMIN","PHOPMN","PHOPMX","PHMAX","KTMP"]:
            if k in df: df[k]=pd.to_numeric(df[k],errors="coerce")
        name="COMNAME" if "COMNAME" in df else "SCIENTIFICNAME"
        if name not in df: raise ValueError("EcoCrop no tiene nombres de cultivos.")
        cat=df.get("CAT",pd.Series("",index=df.index)).fillna("").astype(str).str.lower()
        df=df[cat.str.contains(r"cereals & pseudocereals|pulses \(grain legumes\)|roots/tubers|vegetables|fruits & nuts",regex=True)].copy()
        df["_name"]=df[name].fillna("").astype(str).str.split(",").str[0].str.strip()
        df=df[df["_name"].ne("")&df[req].notna().all(axis=1)].copy()
        ok=(df.TMIN<df.TOPMN)&(df.TOPMN<=df.TOPMX)&(df.TOPMX<df.TMAX)&(df.RMIN<df.ROPMN)&(df.ROPMN<=df.ROPMX)&(df.ROPMX<df.RMAX)&(df.GMIN>=1)&(df.GMAX<=365)&(df.GMIN<=df.GMAX)
        return df[ok]

    @staticmethod
    def _score(x,lo,ol,oh,hi):
        x=np.asarray(x,dtype=float)
        try: lo,ol,oh,hi=map(float,(lo,ol,oh,hi))
        except (ValueError,TypeError): return np.full(x.shape,np.nan)
        if not np.isfinite([lo,ol,oh,hi]).all() or not lo<ol<=oh<hi:return np.full(x.shape,np.nan)
        y=np.zeros(x.shape); m=np.isfinite(x)&(x>lo)&(x<ol); y[m]=100*(x[m]-lo)/(ol-lo)
        m=np.isfinite(x)&(x>=ol)&(x<=oh); y[m]=100
        m=np.isfinite(x)&(x>oh)&(x<hi); y[m]=100*(hi-x[m])/(hi-oh)
        return y

    @staticmethod
    def _txt(row,k):
        v=row.get(k,""); return "" if pd.isna(v) else str(v).strip().lower()

    def _soil_score(self,c,p):
        values={**self.soil,**{k:p.get(k) for k in SOIL if p.get(k) is not None}}; out={}
        if values.get("soil_ph") is not None and all(pd.notna(c.get(k,np.nan)) for k in ["PHMIN","PHOPMN","PHOPMX","PHMAX"]):
            out["score_ph"]=float(self._score([values["soil_ph"]],c.PHMIN,c.PHOPMN,c.PHOPMX,c.PHMAX)[0])
        if values.get("soil_texture") is not None:
            norm=lambda v:{"sandy":"light","coarse":"light","loamy":"medium","loam":"medium","clay":"heavy","clayey":"heavy"}.get(str(v).lower(),str(v).lower())
            obs,ideal,tol=norm(values["soil_texture"]),norm(self._txt(c,"TEXT")),norm(self._txt(c,"TEXTR"))
            if ideal or tol:out["score_textura"]=100. if obs==ideal or ideal=="wide" else 70. if obs==tol or tol=="wide" else 0.
        if values.get("soil_depth") is not None:
            ranks={"shallow":1,"medium":2,"deep":3}; obs=ranks.get(str(values["soil_depth"]).lower(),0)
            ideal=next((ranks[k] for k in ranks if k in self._txt(c,"DEP")),0); tol=next((ranks[k] for k in ranks if k in self._txt(c,"DEPR")),0)
            if obs and ideal:out["score_profundidad"]=100. if obs>=ideal else 60. if obs>=tol>0 else 0.
        if values.get("soil_ec_ds_m") is not None:
            def max_ec(v):
                s=str(v).lower(); ns=[float(z) for z in re.findall(r"\d+(?:\.\d+)?",s)]
                if ">" in s and ns:return float("inf")
                if ns:return max(ns)
                if "high" in s:return float("inf")
                if "medium" in s:return 10.
                if "low" in s:return 4.
                return np.nan
            ideal,tol=max_ec(c.get("SAL","")),max_ec(c.get("SALR",""))
            if np.isfinite(tol) or np.isinf(tol):
                ec=float(values["soil_ec_ds_m"]);out["score_salinizacion"]=100. if ec<=ideal else 60. if ec<=tol else 0.
        if values.get("soil_drainage") is not None:
            obs=str(values["soil_drainage"]).lower();ideal,tol=self._txt(c,"DRA"),self._txt(c,"DRAR")
            key="poorly" if "poor" in obs else "excessive" if "excess" in obs else "well"
            if ideal or tol:out["score_drenaje"]=100. if key in ideal else 60. if key in tol else 0.
        return out

    def _score_point(self,p,weather,crops):
        daily=weather.sort_index().copy();daily=daily[~daily.index.duplicated()].reindex(pd.date_range(daily.index.min(),daily.index.max(),freq="D"))
        years=daily.index.year.to_numpy(); rows=[]
        for _,c in crops.iterrows():
            soils=self._soil_score(c,p); floor=min(soils.values()) if soils else 100.
            durations=sorted({int(round(c.GMIN)),int(round((c.GMIN+c.GMAX)/2)),int(round(c.GMAX))})
            actuals={}; conditions={}; rep=None
            for d in durations:
                if d>len(daily):continue
                temp=daily.T2M.rolling(d,min_periods=d).mean().to_numpy()
                rain=daily.PRECTOTCORR.rolling(d,min_periods=d).sum().to_numpy()
                tmin=daily.T2M_MIN.rolling(d,min_periods=d).min().to_numpy()
                starts=np.arange(0,len(daily)-d+1,7,dtype=int);ends=starts+d-1
                mask=years[starts]==years[ends];starts,ends=starts[mask],ends[mask]
                ts=self._score(temp[ends],c.TMIN,c.TOPMN,c.TOPMX,c.TMAX)
                rs=self._score(rain[ends]+float(self.irrigation or 0),c.RMIN,c.ROPMN,c.ROPMX,c.RMAX)
                if pd.notna(c.get("KTMP",np.nan)):ts[tmin[ends]<float(c.KTMP)]=0
                hot=(daily.T2M_MAX.to_numpy()>float(c.TMAX)).astype(int);prefix=np.r_[0,np.cumsum(hot)]
                ts=np.maximum(0,ts-(prefix[starts+d]-prefix[starts]))
                act=np.minimum(np.minimum(ts,rs),floor);con=np.minimum(ts,floor)
                for yr in np.unique(years[starts]):
                    ix=np.flatnonzero(years[starts]==yr);y=int(yr)
                    if np.isfinite(act[ix]).any():actuals[y]=max(actuals.get(y,0),float(np.nanmax(act[ix])))
                    if np.isfinite(con[ix]).any():
                        j=int(ix[np.nanargmax(con[ix])]); val=float(con[j])
                        if val>conditions.get(y,-1):conditions[y]=val;rep=(j,starts,d,ts,rs,rain[ends])
            if not conditions:continue
            j,starts,d,ts,rs,rains=rep;mm=float(rains[j])
            rows.append({"punto_id":p["id"],"lat":p["lat"],"lon":p["lon"],"distancia_centro_km":p["distance_km"],
              "cultivo_comun":c["_name"],"nombre_cientifico":c.get("SCIENTIFICNAME",""),"categoria":c.get("CAT",""),
              "score_actual_0_100":float(np.mean(list(actuals.values()))) if actuals else 0.,
              "score_condicional_agua_0_100":float(np.mean(list(conditions.values()))),
              "score_temperatura":float(ts[j]),"score_lluvia":float(rs[j]),"lluvia_ciclo_mm":mm,
              "deficit_hasta_minimo_ecocrop_mm":max(0.,float(c.RMIN)-mm),
              "inicio_ciclo":daily.index[starts[j]].strftime("%m-%d"),"ciclo_dias":d,**soils})
        return rows

    def recommend(self):
        """Return JSON-ready rankings, per-point details, climate summary and metadata."""
        points=self._points();crops=self._crops();records=[]
        weather={}
        for p in points:
            weather[p["id"]]=self._weather(p)
            records.extend(self._score_point(p,weather[p["id"]],crops));time.sleep(.15)
        if not records:raise RuntimeError("No hay cultivos evaluables.")
        detail=pd.DataFrame(records);keys=["cultivo_comun","nombre_cientifico","categoria"]
        summary=detail.groupby(keys,as_index=False).agg(
          score_escenario_actual_0_100=("score_actual_0_100","mean"),
          score_condicional_con_agua_0_100=("score_condicional_agua_0_100","mean"),
          score_min_puntos=("score_actual_0_100","min"),score_max_puntos=("score_actual_0_100","max"),
          puntos_con_score_positivo=("score_actual_0_100",lambda x:int((x>0).sum())),
          puntos_evaluados=("punto_id","nunique"),deficit_medio_hasta_minimo_ecocrop_mm=("deficit_hasta_minimo_ecocrop_mm","mean"))
        for key in ["score_ph","score_textura","score_profundidad","score_salinizacion","score_drenaje"]:
            if key in detail:
                mean=detail.groupby(keys)[key].mean();summary[key]=summary.set_index(keys).index.map(mean)
        summary["fraccion_puntos_con_score_positivo"]=summary.puntos_con_score_positivo/summary.puntos_evaluados
        summary=summary.sort_values(["score_escenario_actual_0_100","fraccion_puntos_con_score_positivo","score_condicional_con_agua_0_100"],ascending=False).reset_index(drop=True)
        summary.insert(0,"puesto",np.arange(1,len(summary)+1))
        yes=summary[summary.score_escenario_actual_0_100>0].copy();no_soil=not self.soil and not any(any(p.get(k) is not None for k in SOIL) for p in self.tests)
        alternatives=[]
        if yes.empty:
            alt=summary.sort_values(["score_condicional_con_agua_0_100","score_max_puntos"],ascending=False).head(5).copy()
            alt["estado"]="NO ÓPTIMO - validar antes de sembrar"
            def advice(r):
                a=[]
                if r.deficit_medio_hasta_minimo_ecocrop_mm>0:a.append("Confirmar disponibilidad y calidad de agua y revisar calendario.")
                if no_soil:a.append("Analizar por punto pH, salinidad, textura, profundidad y drenaje; no aplicar enmiendas a ciegas.")
                if pd.notna(r.get("score_ph")) and r.score_ph<60:a.append("Solicitar al laboratorio corrección de pH según diagnóstico; sin dosis automática.")
                if pd.notna(r.get("score_salinizacion")) and r.score_salinizacion<60:a.append("Analizar agua/suelo y confirmar drenaje antes de cualquier lavado de sales.")
                if pd.notna(r.get("score_drenaje")) and r.score_drenaje<60:a.append("Revisar anegamiento y drenaje con asesoría local.")
                if pd.notna(r.get("score_textura")) and r.score_textura<60:a.append("Elegir cultivo compatible y evaluar cobertura/materia orgánica localmente.")
                if pd.notna(r.get("score_profundidad")) and r.score_profundidad<60:a.append("Verificar capas limitantes y elegir raíces compatibles.")
                a.append("Alternativa NO ÓPTIMA; probar en pequeña parcela.");return " ".join(a)
            alt["manejo_a_evaluar"]=alt.apply(advice,axis=1);alternatives=alt.to_dict("records");recommendations=[]
        else:
            yes["estado"]="CANDIDATO PROVISIONAL";recommendations=yes.to_dict("records")
        monthly=[]
        for pid,df in weather.items():
            m=df.groupby([df.index.year,df.index.month]).agg(temp_mean_c=("T2M","mean"),rain_mm=("PRECTOTCORR","sum"),
              humidity_mean_pct=("RH2M","mean"),solar_mean=("ALLSKY_SFC_SW_DWN","mean"),wind_mean=("WS10M","mean"))
            monthly.append(m.reset_index(names=["anio","mes"]))
        climate=pd.concat(monthly,ignore_index=True).groupby("mes").mean(numeric_only=True).reset_index()
        result={"recommendations":recommendations,"alternatives_not_optimal":alternatives,
          "by_point":detail.to_dict("records"),"points":points,"monthly_climate":climate.to_dict("records"),
          "metadata":{"zone_name":self.zone_name,"center":{"latitude":self.lat,"longitude":self.lon},"radius_km":self.radius,
            "period":{"start":self.start,"end":self.end},"algorithm":"EcoCrop rule-based scoring; no trained ML model",
            "source":"NASA POWER Daily API","note":"Climate estimates are regional, not field measurements or yield predictions."}}
        result=_clean(result)
        if self.save_outputs:
            pd.DataFrame(recommendations or alternatives).to_csv(self.data/"recomendaciones_cultivos.csv",index=False,encoding="utf-8-sig")
            detail.to_csv(self.data/"recomendaciones_por_punto.csv",index=False,encoding="utf-8-sig")
        return result

def _clean(x):
    if isinstance(x,dict):return {str(k):_clean(v) for k,v in x.items()}
    if isinstance(x,(list,tuple)):return [_clean(v) for v in x]
    if isinstance(x,np.integer):return int(x)
    if isinstance(x,np.floating):return float(x) if np.isfinite(x) else None
    if isinstance(x,(pd.Timestamp,)):return x.isoformat()
    if pd.isna(x):return None
    return x



