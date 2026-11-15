# Contratos públicos

La aplicación compone servicios por constructor. Los paquetes exponen únicamente su biblioteca pública; no hay imports `src` entre paquetes. `tools/check_architecture.py` verifica imports y ciclos. `docs/evidence/architecture.json` registra el grafo real.

| Paquete | Propiedad y contrato | Dependencias de dominio |
| --- | --- | --- |
| field_core | GeoPoint WGS84, GeoBounds, FieldGeometry, Parcel, FarmRecord, FarmPlanning, ParcelRepository, LocalDocuments | Ninguna |
| field_maps | FieldMap/Controller, MapTiles y MapRaster; renderizado/interacción, sin URLs de proveedores ni cálculos científicos | field_core |
| field_imagery | SceneCatalog, Scene, Observation, RasterProcessor, RasterResult, RasterStatistics, PixelSample; adaptador STAC reutilizable y configuración Earth Search | field_core |
| field_nasa | GibsLayer, NasaPower/ClimateProvider, ClimateSeries y catálogo Landsat USGS/NASA | field_core, field_imagery |
| field_storage | LocalStore SQLite esquema 1; CachedTileClient con límite, deduplicación y offline | field_core |
| field_compute | LocalRasterProcessor; proceso cancelable con protocolo JSON schema=1; no Flutter | field_core, field_imagery |
| field_rotations | RotationEngine compara escenarios con el terreno y una revisión determinista de las condiciones del piloto | field_core |
| app | FieldController, ParcelObservations, composición y vistas del escritorio | Bibliotecas públicas anteriores |

Las estadísticas y muestras tienen tipos explícitos. Los documentos JSON conservan metadatos originales del proveedor y resultados versionados; no se fuerzan datos ausentes a cero. FarmPlanning se guarda como subdocumento opcional de la parcela y las filas V1 siguen usando el mismo contrato SQLite. El worker intercambia JSON por stdin/stdout y nunca recibe PNG de mapa para calcular índices. Windows es el adaptador implementado; otras plataformas necesitarán adaptar ejecución/persistencia, sin cambiar entidades ni interfaces científicas.

## Ciencia reproducible

- `NDVI=(NIR-rojo)/(NIR+rojo)`; `NDMI=(NIR-SWIR1)/(NIR+SWIR1)`. Sentinel usa B08/B04/B11; Landsat 8/9 usa B5/B4/B6. Se aplica escala y offset de cada activo STAC **antes** de operar. Denominadores ≤1e-8, reflectancia negativa para índices y valores no finitos quedan fuera.
- Sentinel-2 L2A: solo clases SCL 4/5/6. Se excluyen desconocido, sin dato, saturado, sombra, nube, cirrus y nieve. Cuadrícula local UTM fijada a múltiplos de 20 m; B08/B04 a 10 m se agregan a 20 m. No se afirma resolución NDVI de 10 m cuando la calidad está a 20 m.
- Landsat 8/9 C2 L2: QA_PIXEL bits 0–5 y cualquier QA_RADSAT excluidos. Óptico a 30 m. ST_B10 aplica escala/offset STAC y resta 273,15; se entrega a 100 m, conservando el límite térmico nativo. No se aplica aún SR_QA_AEROSOL ni se propaga ST_QA: incertidumbre cuantitativa pendiente.
- Reflectancia se remuestrea por promedio; banderas de invalidez por máximo conservador. Reproyección GDAL con CRS explícito. Se incluye el centro del píxel dentro del polígono, no el rectángulo completo. No hay ponderación fraccional de bordes. Media, mínimo, máximo, mediana y desviación poblacional solo sobre valores válidos. Cobertura = válidos/centros dentro de parcela; menos de 9 válidos genera aviso conservador, no un umbral agronómico validado.
- Raster numérico GeoTIFF en UTM; PNG de visualización reproyectado a EPSG:3857 con bounds WGS84. Escalas fijas −1…1 para índices, 0…0,3 para reflectancia y −10…60 °C para temperatura (solo visualización, no recorte de valores). Nubes y sombras tienen colores diferenciados; inválidos transparentes. RGB/falso color/SWIR muestran estadísticas de la primera banda en modo avanzado.
- Comparación permite únicamente mismo proveedor, variable, geometría, resolución, CRS y transformación. No se armonizan Sentinel/Landsat. Aun con la misma cuadrícula, distintas máscaras/coberturas limitan comparar medias; no es una diferencia sobre soporte válido común ni prueba causal.
- Área geodésica esférica con radio autálico 6371007,18 m; puede diferir aproximadamente 0,5% del elipsoide. No es catastro. Se rechazan cruces, duplicados, solapamientos adyacentes y polígonos degenerados o que cruzan el antimeridiano.

## Proveedores y recursos

Earth Search y GIBS públicos sin credenciales. Landsat usa firma pública temporal de Planetary Computer en memoria; no se persisten URLs firmadas. Máximo 30 escenas por consulta; la interfaz avisa y permite acotar fechas. Errores HTTP no se sustituyen por datos de ejemplo.

Ventanas COG mediante rangos HTTP, máximo 1.048.576 celdas de destino, 4096 por lado y un grado geográfico por lado. Un worker a la vez; timeout cuatro minutos y cancelación del proceso. La clave de caché incluye STAC/producto/versión/fecha/polígono/variable/método. Cache raster 512 MB, teselas 128 MB. Documentos/terrenos no se purgan con los raster. Resultados son locales; no hay sincronización.

OSM se consulta a demanda sin prefetch, con User-Agent identificable, atribución visible y caché siete días. No se promete disponibilidad. POWER conserva JSON y unidades recibidas (en la prueba AG, radiación en MJ/m²/día), UTC y advertencia regional. Guardar la observación histórica no la convierte en un dato actual.

Fuentes consultadas: [Earth Search](https://github.com/Element84/earth-search), [GIBS](https://nasa-gibs.github.io/gibs-api-docs/access-basics/), [POWER Daily](https://power.larc.nasa.gov/docs/services/api/temporal/daily/), [USGS QA](https://www.usgs.gov/landsat-missions/landsat-collection-2-quality-assessment-bands), [política OSM](https://operations.osmfoundation.org/policies/tiles/).
