# Cobertura funcional Windows v1

0/65 probados (**0.00%**); 0 implementados sin verificar; 65 pendientes/bloqueados.

No equivale a validación agronómica ni certificación de producción. Registro derivado de secciones 3–19, sin eliminar requisitos no completados. Generado por `python tools/requirements.py`.

| ID | Requisito y criterio de aceptación | Prioridad/módulo | Alcance (V1/FUTURO) | Estado | Evidencia y prueba | Bloqueo/observación |
| --- | --- | --- | --- | --- | --- | --- |
| P0-ARCH-01 | Workspace compatible y aplicación modular sin ciclos ni imports internos ajenos | P0/workspace | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-ARCH-02 | Contratos públicos tipados/versionados y dominio sin Flutter, red o SQLite | P0/dominio | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-01 | Motor Windows evaluado y sustituible; único renderizador | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-UI-01 | Modo agricultor predeterminado, botones grandes, texto/iconos y ayuda por pasos | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-UI-02 | Navegación Inicio, Mis terrenos, Explorar, Análisis y Configuración | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-UI-03 | Diseño adaptable, contraste, errores y carga comprensibles | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-UI-04 | Modo avanzado progresivo comparte motor/modelos con agricultor | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-02 | Mapa interactivo: zoom y desplazamiento | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-03 | Coordenadas, escala y selección contextual de puntos | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-04 | Buscar coordenadas y navegar a parcelas guardadas | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-05 | Cambio de mapa base y atribución | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-MAP-06 | Capas activables con transparencia | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-FIELD-01 | Dibujar límites con instrucciones y ver polígono | P0/field_maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-FIELD-02 | Mover/corregir vértices y deshacer | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-FIELD-03 | Guardar, recuperar, editar y eliminar parcelas nombradas | P0/storage/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-FIELD-04 | Área geodésica en hectáreas; geometría WGS84 | P0/field_core | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-FIELD-05 | Rechazar pocos puntos, duplicados y autointersecciones | P0/field_core | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P0-BUILD-01 | Compilar y abrir aplicación Windows real | P0/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-GIBS-01 | Capa NASA GIBS auténtica con proyección/formato/resolución/fecha comprobados | P1/field_nasa | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-GIBS-02 | Visualizar teselas reales y distinguirlas de bandas científicas | P1/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-STAC-01 | Catálogo Sentinel-2 L2A por área y fechas, con filtro de nubes | P1/field_imagery | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-STAC-02 | Listar y seleccionar escenas con ID, fecha, nubes, fuente y activos | P1/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-STAC-03 | Verificar acceso real a activos, condiciones y fallos del proveedor | P1/field_imagery | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-RGB-01 | Mostrar imagen RGB auténtica de escena seleccionada | P1/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-META-01 | Fechas, fuente, resolución, producto, versión y procedencia visibles | P1/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P1-LEGEND-01 | Leyendas claras con texto, límites y significado | P1/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-RGB-01 | RGB natural desde bandas adecuadas | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-RGB-02 | Falso color infrarrojo desde bandas adecuadas | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-RGB-03 | Composición SWIR y bandas individuales | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-NDVI-01 | NDVI real con fórmula y escala/offset correctos | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-NDMI-01 | NDMI real con fórmula, escala/offset y límites interpretativos | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-QA-01 | Excluir nubes, sombras, inválidos, no finitos y divisiones cero | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-QA-02 | Alinear resoluciones, CRS y georreferenciación sin falsa precisión | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-STATS-01 | Estadísticas por polígono: media, mínimo, máximo, mediana, dispersión | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-STATS-02 | Número y cobertura válida, fecha, resolución y aviso parcela pequeña | P2/imagery/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-META-01 | Resultado conserva fuente/producto/versión/fecha/área/unidad/método/calidad/incertidumbre | P2/imagery/storage | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-LEGEND-01 | Leyendas científicas consistentes entre fechas, nubes/sombras/sin datos distinguibles | P2/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P2-PIXEL-01 | Modo avanzado consulta valores por píxel y bandas | P2/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-TIME-01 | Series temporales de resultados científicos reales | P3/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-TIME-02 | Comparación de fechas con mismo lugar, escala y georreferenciación | P3/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-LANDSAT-01 | Catálogo y acceso Landsat Collection 2 Level 2 auténtico | P3/field_nasa | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-LANDSAT-02 | Reflectancia Landsat con escala/offset/QA/resolución correctos | P3/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-LANDSAT-03 | Temperatura superficial Landsat cuando sea válida y disponible | P3/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-POWER-01 | NASA POWER real: temperatura, lluvia, humedad relativa y radiación | P3/field_nasa | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-POWER-02 | POWER conserva fechas, unidades, procedencia y resolución regional | P3/field_nasa/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-AGRI-01 | Registrar cultivo actual e historial de cultivos | P3/core/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P3-AGRI-02 | Registrar suelo, agua, riego, economía y prioridades | P3/core/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-TEST-01 | Pruebas unitarias y contratos por módulo | P4/tests | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-TEST-02 | Pruebas integradas y regresión Windows | P4/tests | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-NET-01 | Fallos de red, timeout y mensajes claros sin datos inventados | P4/app/adapters | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-STORE-01 | Persistencia SQLite real con reinicialización y recuperación | P4/field_storage | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-STORE-02 | Esquema versionado, datos externos a instalación y errores controlados | P4/field_storage | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-STORE-03 | Persistir preferencias, capas, metadatos y resultados | P4/field_storage | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-CACHE-01 | Caché limitada de teselas y recursos consultados | P4/storage/maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-CACHE-02 | Resultados reutilizables con clave producto/versión/área/fecha/variable/método | P4/storage/compute | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-OFF-01 | Abrir offline y recuperar/editar parcelas | P4/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-OFF-02 | Ver mapas descargados previamente y avisar de recursos ausentes | P4/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-OFF-03 | Consultar resultados locales sin conexión | P4/app | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-PERF-01 | Procesar fuera de UI y no recalcular al navegar mapa | P4/compute/maps | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-PERF-02 | Acceso parcial raster, concurrencia limitada, deduplicación/cancelación y liberación | P4/compute/storage | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-PERF-03 | Medición reproducible CPU/RAM/GPU/VRAM/disco/red según disponibilidad | P4/tools | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-BUILD-01 | Análisis estático, pruebas y compilación Windows final | P4/workspace | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-DIST-01 | Distribución ejecutable con dependencias e instrucciones | P4/tools | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-DOC-01 | Estado, decisiones, contratos y cobertura con evidencia y pendientes | P4/docs | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| P4-UX-01 | Validación de usabilidad con agricultores reales | P4/externo | V1 | PENDIENTE O BLOQUEADO | Sin evidencia todavía. | Por implementar/verificar. |
| FUTURO-SYNC | Sincronización opcional en nube | FUTURO/field_sync | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
| FUTURO-PLATFORM | Compilaciones Android/iOS/web | FUTURO/app | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
| FUTURO-ROTATION | Comparar tres rotaciones incluida actual con validación agronómica | FUTURO/field_rotations | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
| FUTURO-INDEX | NDRE, SAVI, NDWI y BSI | FUTURO/field_imagery | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
| FUTURO-GPM | GPM/IMERG y otras fuentes justificadas | FUTURO/field_nasa | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
| FUTURO-VOICE | Voz, idiomas locales y geocodificación por nombres | FUTURO/app | FUTURO | FUTURO | Sin evidencia todavía. | Fuera de Windows v1. |
