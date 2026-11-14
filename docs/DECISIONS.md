# Decisiones — Windows v1

## 2026-11-14: base real y motor cartográfico
El directorio inicial no tiene `.git`. Contiene plantillas Flutter/Dart, sin funcionalidades agrícolas. Flutter 3.47.1, Dart 3.13.1 y Visual Studio 2026 están instalados. No se hacen commits ni cambios de rama.

MapLibre 0.3.7+1 se inspeccionó desde su archivo publicado en pub.dev: Windows utiliza WebView experimental y su registro de plugin está comentado. La implementación nativa corresponde a 0.4 prerelease. Se selecciona flutter_map 8.3.2, compatible con Windows y Flutter instalado, detrás de la API pública de field_maps. No se afirma aceleración MapLibre nativa ni rendimiento sin medición. Solo un motor activo.

Fuentes: https://pub.dev/packages/maplibre/versions/0.3.7%2B1 y https://pub.dev/packages/flutter_map/versions/8.3.2 .

Persistencia SQLite mediante sqflite_common_ffi, fuera del directorio de instalación. Dominio independiente de Flutter/SQLite/red. Aplicación compone repositorios y servicios por constructor. No se requiere Riverpod para este tamaño de aplicación.

Para ventanas GeoTIFF/COG, reproyección y máscaras se utiliza GDAL/rasterio en un proceso separado detrás de RasterProcessor. Justificación: decodificar GeoTIFF georreferenciado, leer rangos HTTP y reproyectar no lo resuelve un decodificador PNG ni el renderizador. Protocolo JSON versionado; límite de área/píxeles, un proceso a la vez y cancelación. Python es un adaptador Windows sustituible, no dependencia del dominio. Se debe distribuir el runtime para no exigir Python al agricultor.

GIBS es exclusivamente visual. Sentinel-2 pertenece a ESA/Copernicus, con catálogo Earth Search. Landsat pertenece a USGS/NASA; catálogo Planetary Computer. NASA POWER es regional. No hay diagnósticos ni recomendaciones automáticas.
