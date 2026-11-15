# NASA Field Shift · Estado de entrega

## V2.2 · Interfaz y coordenadas

- La interfaz usa IBM Plex Sans local, una barra lateral verde oscuro y una foto aérea de referencia en Inicio. Las tarjetas de terrenos dibujan el contorno guardado. En ventanas estrechas, la barra inferior permite llegar a las seis secciones mediante cuatro accesos y el menú **Más**.
- **Go to coordinates** tiene un `PageStorageKey` propio para que el campo de texto lea su posición de desplazamiento por separado del estado de expansión. El formulario de terreno aplica la misma corrección en los campos de notas.
- En Linux pasaron 31 pruebas Dart/Flutter y 6 del worker Python. Las pruebas de interfaz abren y cierran el panel de coordenadas, centran el mapa, cambian el ancho de la ventana, recorren los seis destinos a 320 px y guardan notas. La ejecución nativa de V2.2 está pendiente en un host Windows.

## V2.1 · Ajustes tras la prueba en Windows

- **Inicio** muestra el terreno activo y accesos a mapa, observaciones y próxima siembra. La tipografía Source Sans 3 se incluye con su licencia y se carga offline. La barra de escritorio conserva los nombres de las secciones en ventanas medianas.
- **Idioma** abre en inglés y permite cambiar a español desde la barra o Configuración. La preferencia se guarda en SQLite. Los nombres de parcelas y las notas del usuario conservan su texto.
- **Período** permite elegir mes y año directamente, últimos 30 o 90 días y fechas personalizadas. Imágenes y clima comparten la selección.
- **Observaciones** separa imágenes y clima en la misma vista. La lectura básica explica qué se puede observar. Datos y método abre estadísticas, unidades, fuente y resolución.
- **Errores de Flutter** separa el estado de expansión y el desplazamiento de la tabla de clima. Los valores no numéricos se muestran como datos ausentes. Los detalles y fuentes tienen un botón de copia.
- **Codificación** recibe JSON UTF-8 en el worker y corrige el separador mal codificado al mostrar resultados anteriores. Se conserva el JSON original archivado.
- **Planificador** explica cuándo una parcela está fuera del piloto. El alcance agronómico sigue siendo la costa irrigada de Lambayeque. La lectura se basa en los datos del agricultor y en las fichas de cultivo, con imágenes y clima como contexto para contrastar en campo.

La evidencia de esta revisión está en [v2_1_verification.json](evidence/v2_1_verification.json). Se ejecutaron 29 pruebas Dart/Flutter y 6 del worker Python. Los casos de regresión incluyen el idioma guardado, febrero de un año anterior, el clima con valores ausentes, la copia de detalles y fuentes, y el protocolo UTF-8 con una consola configurada como en Windows. La compilación y la prueba nativa de V2.1 siguen pendientes en un host Windows.

## Registro de V2.0

## Qué incluye

La V2 se implementó sobre el workspace Flutter existente. Conserva el runner y el proyecto de Windows, el worker raster y el directorio de datos de la instalación anterior.

| Módulo | Cambios principales |
| --- | --- |
| apps/field_shift/lib/app.dart y presentation/field_screen.dart | Tema Material 3, Inter local, barra lateral, modo compacto, menú para ventanas estrechas e indicador de conexión. |
| presentation/dashboard_page.dart y parcels_page.dart | Resumen del terreno activo, contorno, estado de observaciones y tarjetas con acciones sobre cada parcela. |
| presentation/map_workspace.dart y packages/field_maps | Vista OSM con GIBS opcional, búsqueda por coordenadas, edición de vértices, centrado y mapa compartido con Análisis. |
| presentation/analysis_page.dart y result_panel.dart | Filtros, catálogo y procesamiento, historial, comparación, leyendas, calidad, metadatos y clima regional. |
| presentation/rotation_form.dart y rotation_page.dart | Registro agrícola guiado, comparación de escenarios y contexto de datos para validación local. |
| packages/field_rotations | Catálogo piloto y motor de comparación determinista en Dart, independiente de Flutter. |
| packages/field_core/lib/src/farm_planning.dart y parcel.dart | Perfil agrícola tipado de versión 1 dentro del JSON de la parcela. Se preservan los campos libres, los IDs y las geometrías. |
| application/field_controller.dart y parcel_observations.dart | Selección de parcela, archivo de evidencia local, operaciones cancelables y estado de consulta. |
| packages/field_imagery y packages/field_nasa | Clasificación del resultado y acceso a unidades originales de POWER. |
| packages/field_storage y packages/field_compute | Continúan usando SQLite esquema 1 y el protocolo del worker esquema 1. Se probó la reapertura de una fila de SQLite con datos V1. |
| tools/build_windows.ps1, tools/build_windows.py y tools/verify_all.py | Empaquetado con ruta para V2 y suite con pruebas del planificador. |

## Reglas del planificador

El catálogo piloto parte de maíz amarillo duro y se limita a la costa cálida e irrigada de Lambayeque, de 0 a 500 m s. n. m. El agricultor confirma esa condición y el motor comprueba que las coordenadas estén cerca del área de alcance. La comprobación es aproximada y la altitud procede del registro del agricultor.

Para evaluar sustituciones en la siguiente campaña, se requieren mes de siembra, buen drenaje, agua confirmada y un sistema de riego. Un presupuesto que solo cubre el cultivo actual bloquea las alternativas. Si el presupuesto queda sin confirmar, la viabilidad económica sigue pendiente. La prioridad seleccionada orienta qué aspecto se debe verificar. El motor se abstiene de puntuar o estimar rendimientos y ahorros con estos datos.

| Escenario | Condiciones |
| --- | --- |
| Referencia | Cultivo, historial y siguiente cultivo declarado, cuando existen. |
| Maíz amarillo duro → caupí INIA 432 | Octubre a marzo. El piloto exige textura franco arenosa y conductividad del suelo de hasta 2 dS/m, conforme al filtro conservador de la ficha. |
| Maíz amarillo duro → frijol blanco mediano | Marzo a mayo en costa norte. Su variedad, manejo, salinidad y mercado requieren confirmación local. |

Con los datos completos, marzo permite comparar las tres opciones. En otros casos, el motor deja disponibles las opciones compatibles e identifica el motivo de cada exclusión. La evaluación se refiere al cambio de cultivo para la siguiente campaña. El usuario debe confirmar fechas de cosecha, de siembra y de retorno al maíz con asesoría local.

La ficha del maíz documenta la práctica de intercalar leguminosas. Las fichas varietales aportan las ventanas y el criterio de campo para el piloto. [SENASA · Maíz amarillo duro, § 3.4](https://www.senasa.gob.pe/senasa/descargasarchivos/2020/07/Guia-BPA-MAIZ-AMARILLO-DURO.pdf), [SENASA · Frijol, § 3.4](https://www.senasa.gob.pe/senasa/descargasarchivos/2020/07/Guia-BPA-FRIJOL.pdf), [INIA · Compendio de cultivares, pp. 208–209](https://repositorio.inia.gob.pe/server/api/core/bitstreams/00d5f440-ebef-4b68-a70a-d240ac46bc1f/content), [INIA · Ficha de caupí 432](https://agroshow.s3.us-east-2.amazonaws.com/catalogs/mbh4457l0txnl3.pdf).

El planificador muestra la observación satelital utilizable más reciente y la serie regional de POWER disponible para la parcela, con fechas, calidad y unidades. Son evidencia histórica para la validación local. La lógica de compatibilidad usa los datos declarados sobre el terreno. NDVI y precipitación regional se presentan con sus límites de interpretación.

## Datos y calidad

- El archivo conserva los documentos originales. Resultado V1 y preferencias V1 mantienen sus claves. Los análisis se asocian a la geometría vigente y el archivo regional de tiempo se vincula al punto consultado.
- La calidad se calcula al leer el resultado. **Sin datos utilizables** corresponde a cero píxeles válidos o a estadísticas sin valor interpretable. **Limitado** corresponde a menos de nueve píxeles, menos del 50 % de cobertura válida o avisos del worker. **Disponible** corresponde a los demás resultados válidos. Los umbrales son criterios de presentación y cobertura. Las estadísticas y fórmulas del worker se conservan.
- El modo sin conexión abre la geometría, las notas, los escenarios y los resultados ya guardados. Las vistas RGB o numéricas dependen de que sus archivos sigan disponibles en caché. La evidencia guardada conserva su fecha y procedencia.
- El diseño soporta otras ubicaciones para mapas y análisis. La comparación agronómica requiere un catálogo explícito por región.

## Verificación de V2

Pruebas ejecutadas el 14/11/2026 en Linux con Flutter 3.50.0 y Dart 3.14.0.

| Prueba | Resultado |
| --- | --- |
| Resolución de dependencias y análisis estático | Correctos. El análisis mantiene avisos informativos de deprecación de la biblioteca Material del SDK. |
| Pruebas Dart/Flutter | 26 aprobadas. Cubren dominio, mapas, persistencia V1, navegación, delimitación, calidad, reapertura offline y comparación. |
| Pruebas unitarias del worker Python | 5 aprobadas. |
| Arquitectura de paquetes | Correcta. Se verificaron imports públicos y ausencia de ciclos. |
| Tamaños Flutter | 1600×900, 1366×768, 1024×768, 720×620, 400×640 y 360×540. El mismo mapa se mantiene al cambiar de tamaño. |
| Servicios reales | Earth Search devolvió 3 escenas Sentinel-2. Planetary Computer devolvió 4 escenas Landsat. POWER devolvió 7 días con unidades. GIBS sirvió el mosaico solicitado. |
| Worker con bandas reales | NDVI de 2 escenas Sentinel-2 y de 1 Landsat, más temperatura superficial Landsat. Se verificaron archivos de vista, ráster numérico y lectura del píxel central. |
| Compilación e integración nativas Windows | Pendientes en un equipo Windows. El host de la verificación fue Linux. |

La evidencia de V2 está en [v2_verification.json](evidence/v2_verification.json). Los archivos de verificación de V1 se conservan como evidencia histórica. La validación agronómica en campo del piloto y las pruebas con agricultores siguen pendientes.

## Reproducir

Sigue el [arranque del README](../README.md). En Windows, ejecuta la suite desde la raíz con el Python de la carpeta .venv y el script tools/verify_all.py. Incluye la integración nativa con una parcela de prueba, escenas Sentinel-2, POWER y reapertura offline.

Para consultar los adaptadores sin sustituir las capturas de V1, abre apps/field_shift y ejecuta:

~~~powershell
dart run bin/verify_live.dart "$env:TEMP\field-shift-verification"
~~~

## Archivos de V2

### Creados

- `apps/field_shift/assets/fonts/Inter.ttf`
- `apps/field_shift/assets/fonts/OFL.txt`
- `apps/field_shift/lib/application/parcel_observations.dart`
- `apps/field_shift/lib/presentation/analysis_page.dart`
- `apps/field_shift/lib/presentation/dashboard_page.dart`
- `apps/field_shift/lib/presentation/map_workspace.dart`
- `apps/field_shift/lib/presentation/parcels_page.dart`
- `apps/field_shift/lib/presentation/rotation_form.dart`
- `apps/field_shift/lib/presentation/rotation_page.dart`
- `apps/field_shift/lib/presentation/settings_page.dart`
- `apps/field_shift/lib/presentation/workspace_widgets.dart`
- `docs/PROJECT_STATUS.md`
- `docs/evidence/v2_verification.json`
- `packages/field_core/lib/src/farm_planning.dart`
- `packages/field_rotations/lib/field_rotations.dart`
- `packages/field_rotations/lib/src/rotation_engine.dart`
- `packages/field_rotations/pubspec.yaml`
- `packages/field_rotations/test/rotation_engine_test.dart`

### Modificados

- `README.md`
- `apps/field_shift/bin/verify_live.dart`
- `apps/field_shift/integration_test/windows_flow_test.dart`
- `apps/field_shift/lib/app.dart`
- `apps/field_shift/lib/application/field_controller.dart`
- `apps/field_shift/lib/main.dart`
- `apps/field_shift/lib/presentation/farm_dialog.dart`
- `apps/field_shift/lib/presentation/field_screen.dart`
- `apps/field_shift/lib/presentation/result_panel.dart`
- `apps/field_shift/pubspec.yaml`
- `apps/field_shift/test/controller_test.dart`
- `apps/field_shift/test/support.dart`
- `apps/field_shift/test/widget_test.dart`
- `docs/DECISIONS.md`
- `docs/MODULE_CONTRACTS.md`
- `docs/USO_WINDOWS.md`
- `docs/evidence/architecture.json`
- `packages/field_core/lib/field_core.dart`
- `packages/field_core/lib/src/parcel.dart`
- `packages/field_imagery/lib/src/models.dart`
- `packages/field_maps/lib/src/field_map.dart`
- `packages/field_nasa/lib/src/services.dart`
- `packages/field_storage/test/storage_test.dart`
- `pubspec.yaml`
- `tools/build_windows.ps1`
- `tools/build_windows.py`
- `tools/verify_all.py`
