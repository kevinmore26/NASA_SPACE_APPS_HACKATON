# Decisiones — Windows v1

## 2026-11-14: base real y motor cartográfico
El directorio inicial no tiene `.git`. Contiene plantillas Flutter/Dart, sin funcionalidades agrícolas. Flutter 3.47.1, Dart 3.13.1 y Visual Studio 2026 están instalados. No se hacen commits ni cambios de rama.

MapLibre 0.3.7+1 se inspeccionó desde su archivo publicado en pub.dev: Windows utiliza WebView experimental y su registro de plugin está comentado. La implementación nativa corresponde a 0.4 prerelease. Se selecciona flutter_map 8.3.2, compatible con Windows y Flutter instalado, detrás de la API pública de field_maps. No se afirma aceleración MapLibre nativa ni rendimiento sin medición. Solo un motor activo.

Fuentes: https://pub.dev/packages/maplibre/versions/0.3.7%2B1 y https://pub.dev/packages/flutter_map/versions/8.3.2 .

Persistencia SQLite mediante sqflite_common_ffi, fuera del directorio de instalación. Dominio independiente de Flutter/SQLite/red. Aplicación compone repositorios y servicios por constructor. No se requiere Riverpod para este tamaño de aplicación.

Para ventanas GeoTIFF/COG, reproyección y máscaras se utiliza GDAL/rasterio en un proceso separado detrás de RasterProcessor. Justificación: decodificar GeoTIFF georreferenciado, leer rangos HTTP y reproyectar no lo resuelve un decodificador PNG ni el renderizador. Protocolo JSON versionado; límite de área/píxeles, un proceso a la vez y cancelación. Python es un adaptador Windows sustituible, no dependencia del dominio. Se debe distribuir el runtime para no exigir Python al agricultor.

GIBS es exclusivamente visual. Sentinel-2 pertenece a ESA/Copernicus, con catálogo Earth Search. Landsat pertenece a USGS/NASA; catálogo Planetary Computer. NASA POWER es regional. No hay diagnósticos ni recomendaciones automáticas.

## V2 · Comparación de rotaciones y archivo local

La navegación mantiene un único mapa al pasar entre Explorar y Análisis y abre Inicio sin solicitar teselas. A partir de 1280 px se muestran las etiquetas de navegación. Entre 900 y 1279 px se usa una barra compacta. Por debajo de 900 px se abre el menú desde el encabezado y se reorganizan los paneles según el espacio disponible.

El modelo agrícola tipado se añade al JSON del terreno y conserva el texto libre de V1. SQLite mantiene su esquema 1. El archivo de observaciones filtra el historial por los límites actuales y conserva los documentos originales para auditoría. NASA POWER guarda el punto de consulta junto a la respuesta original. Las series V1 se recuperan con el punto informado por POWER.

El módulo field_rotations contiene el catálogo y las reglas del piloto. Recibe el terreno y devuelve una referencia y las alternativas condicionales. El análisis satelital y la serie regional se usan para describir la evidencia disponible, incluidas sus fechas y su calidad. La elegibilidad usa suelo, agua, calendario y los demás datos registrados por el agricultor. Las reglas se documentan en [Estado de V2](PROJECT_STATUS.md).

La tipografía Inter se distribuye con su licencia SIL OFL, se carga localmente y se atribuye desde el listado de licencias de la app.

## V2.1 · Lectura básica y verificación técnica

El Inicio prioriza el terreno activo. La barra conserva nombres de secciones a partir de 950 px y las ventanas más estrechas usan el menú superior. Source Sans 3 sustituye a Inter y mantiene su licencia junto al archivo de fuente. Se guarda el idioma como un campo opcional de preferences-v1. Cuando falta, se usa inglés.

Observaciones comparte el período entre imágenes y clima. Las claves de PageStorage para expandir la tabla y para el desplazamiento horizontal son distintas. Los textos largos se pueden copiar sin activar un campo editable dentro de la expansión. El protocolo lee JSON como bytes UTF-8 y el adaptador de resultados corrige el separador heredado al mostrarlo.
