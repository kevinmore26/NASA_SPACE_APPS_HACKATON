# NASA Field Shift para Windows — 0.1.0

Abre `field_shift.exe`. Conserva toda la carpeta, incluidos `data`, DLLs y `workers`; el exe solo no funciona. No requiere instalar Python. No hay nube ni cuenta obligatoria. Distribución de prueba sin firma digital.

1. Escribe latitud y longitud (ejemplo de navegación: `-13.718, -76.148`). El mapa también se desplaza y amplía con ratón.
2. Pulsa **Marcar mi terreno** y toca sus esquinas. Para corregir, pulsa el número de un punto y luego su nueva posición. Puedes deshacer o quitarlo. Guarda con un nombre.
3. En **Análisis**, elige fechas y qué observar, pulsa **Buscar imágenes** y selecciona una escena. Se lee únicamente una ventana de bandas para el terreno. Un análisis puede tardar y necesita internet; **Cancelar** detiene el procesador.
4. El resultado muestra fecha, fuente, resolución y cobertura válida. **Historial guardado** permite abrir resultados locales y comparar dos fechas compatibles sin mover el mapa.
5. **Configuración → Modo avanzado** habilita bandas, Landsat, fórmulas y consulta del píxel. **Trabajar sin internet** utiliza las zonas ya consultadas y los análisis guardados.

NASA GIBS es una vista regional RGB de 250 m: no se calcula NDVI desde esas teselas. Sentinel-2 se procesa a 20 m efectivos y Landsat óptico a 30 m; temperatura Landsat a 100 m. POWER es regional y conserva las unidades del proveedor. Pocos píxeles o mucha nubosidad limitan la interpretación.

Los datos se guardan en la carpeta de soporte del usuario, indicada en Configuración; no junto al ejecutable. Conserva esa carpeta para respaldar tus terrenos. Caché de teselas 128 MB y de raster 512 MB. Un resultado antiguo cuyo raster fue retirado conserva sus estadísticas; vuelve a procesar la misma escena para recuperarlo. La aplicación muestra hasta 30 escenas por búsqueda: acota fechas si necesitas otra observación.

Esta versión no tiene recomendaciones de riego, fertilización, enfermedad o rotación. No se ha validado con agricultores reales ni como medición catastral. No mezcles series Sentinel-2 y Landsat como si fueran equivalentes. Consulta `PROJECT_STATUS.md` y `REQUIREMENTS_TRACEABILITY.md` del repositorio para conocer pruebas y pendientes.
