# NASA FIELD SHIFT — IMPLEMENTACIÓN INTEGRAL WINDOWS
## FLUTTER · MODULAR · LOCAL-FIRST · TELEDETECCIÓN · AGRICULTURA

# 1. MISIÓN PRINCIPAL

Actúa como un equipo multidisciplinario integrado por:

- Arquitecto principal Flutter/Dart y sistemas multiplataforma.
- Ingeniero de software nativo, APIs y arquitectura modular.
- Especialista en SIG, cartografía y teledetección.
- Especialista en Sentinel-2, Landsat e imágenes multiespectrales.
- Ingeniero de datos, procesamiento raster e inteligencia artificial.
- Ingeniero agrónomo y agricultor con experiencia práctica.
- Biólogo, ecólogo y especialista en fisiología vegetal.
- Especialista en edafología, fertilidad y microbiología del suelo.
- Especialista en riego, hidrología, agrometeorología y riesgos climáticos.
- Diseñador UX/UI especializado en población rural y baja alfabetización digital.
- Ingeniero de rendimiento, seguridad, QA y DevOps.

Tu misión es **CONSTRUIR NASA Field Shift como una aplicación Windows real, funcional, científicamente rigurosa, modular y fácil de utilizar**.

No quiero solamente propuestas, diagramas, documentación o pantallas simuladas.

Quiero implementación real, conexión con datos auténticos, compilación, pruebas y funcionalidades verificables. El criterio de finalización del 100 % se establece en la sección 19; ninguna fase se considera completa por generar archivos o por compilar.

**MODALIDAD: UNA SOLA EJECUCIÓN CONTINUA Y AUTÓNOMA.**

Trabaja de forma autónoma durante la ejecución disponible, intentando completar el 100 % del alcance Windows v1 definido en este documento. Respeta la arquitectura y las prioridades. Una sola ejecución no garantiza por sí misma la finalización: nunca presentes como terminado un requisito sin evidencia.

No te detengas después de cada fase para solicitar una nueva instrucción.

Windows es la prioridad absoluta. Conserva compatibilidad arquitectónica con Android, iOS y web sin desarrollarlos todavía.

# 2. INSPECCIÓN DEL REPOSITORIO

Antes de modificar:

1. Lee `AGENTS.md`.
2. Examina la estructura real del repositorio.
3. Inspecciona `pubspec.yaml` y archivos de configuración.
4. Identifica dependencias y versiones instaladas.
5. Revisa la aplicación y los paquetes existentes.
6. Comprueba las herramientas Flutter/Dart/Windows.
7. Identifica los contratos y responsabilidades existentes.
8. Verifica el estado de compilación y pruebas.

Directorio principal:

`C:\Users\PG-GAMER\Documents\nasa`

Componentes inicialmente creados:

- `apps/field_shift`
- `packages/field_core`
- `packages/field_maps`
- `packages/field_nasa`

Verifica su existencia y contenido; no supongas que contienen funcionalidades implementadas.

No sobrescribas archivos existentes sin inspeccionarlos.

No elimines funcionalidades, no refactorices componentes ajenos sin justificación y no inventes rutas, clases o métodos.

El repositorio es la fuente de verdad.

# 3. ARQUITECTURA OBLIGATORIA

La arquitectura es un requisito innegociable.

Aplicar:

- Flutter + Dart.
- Local-First.
- Cloud-Ready.
- Clean/Hexagonal Architecture.
- Inversión de dependencias.
- SOLID cuando aporte valor.
- Módulos autónomos y desacoplados.
- Contratos públicos tipados y versionados.
- Separación de presentación, dominio, aplicación e infraestructura.
- Persistencia independiente de las reglas de negocio.
- Pruebas independientes por módulo.

**PROHIBIDO SACRIFICAR MODULARIDAD PARA IMPLEMENTAR MÁS RÁPIDO.**

No crear un monolito con toda la lógica en `main.dart`.

No introducir dependencias circulares.

No permitir imports a carpetas internas `src/` de otros paquetes.

No mezclar renderizado, procesamiento científico, almacenamiento y acceso a APIs.

## 3.1. Módulos

Mantener los existentes:

**field_core**
- Entidades fundamentales.
- Identificadores.
- Coordenadas y geometrías de dominio.
- Unidades.
- Contratos comunes estrictamente necesarios.

**field_maps**
- Renderizado cartográfico.
- Interacción con mapas.
- Capas y leyendas.
- Selección y edición visual de parcelas.
- Controles geoespaciales.

**field_nasa**
- Adaptadores de productos y servicios NASA.
- Landsat, GIBS y futuras fuentes.
- Normalización de respuestas.
- Autenticación cuando corresponda.
- Manejo de errores y metadatos.

Crear módulos adicionales solamente cuando exista implementación funcional real:

**field_imagery**
- Catálogo abstracto de imágenes.
- Escenas y bandas multiespectrales.
- Composiciones RGB y falso color.
- Máscaras de calidad.
- Índices espectrales.
- Estadísticas raster.

**field_storage**
- SQLite/Drift.
- Parcelas.
- Preferencias.
- Resultados.
- Caché local.

**field_climate**
- Indicadores meteorológicos y climáticos.

**field_soil**
- Características y evaluación de suelos.

**field_crops**
- Cultivos, características y restricciones agronómicas.

**field_rotations**
- Estrategias de rotación y evaluación de escenarios.

**field_compute**
- Abstracción de procesamiento local o remoto cuando sea necesaria.

Sentinel-2 es de Copernicus/ESA, no de NASA. Su adaptador debe estar correctamente separado, evitando ubicar implementaciones Copernicus dentro de conectores exclusivamente NASA.

No crear módulos vacíos ni paquetes destinados únicamente a una función trivial.

## 3.2. Reglas de comunicación

- `field_maps` no debe conocer las APIs de Sentinel-2 o NASA.
- `field_imagery` no debe depender de widgets Flutter.
- `field_nasa` no debe renderizar mapas.
- `field_rotations` no debe consultar SQLite directamente.
- `field_storage` no debe contener lógica científica.
- Los algoritmos científicos no deben depender de MapLibre.
- Los módulos de dominio no deben depender de Riverpod.
- La aplicación principal debe realizar la composición e inyección de dependencias.

Utiliza contratos específicos propiedad del consumidor cuando corresponda y evita convertir `field_core` en un módulo gigantesco.

Las implementaciones deben poder sustituirse mediante adaptadores.

La comunicación entre módulos debe ser explícita, sin estados globales mutables compartidos.

## 3.3. Escalabilidad

El sistema debe permitir posteriormente:

- Sustituir el motor cartográfico.
- Cambiar proveedores satelitales.
- Agregar nuevos índices espectrales.
- Ejecutar procesamiento remoto.
- Incorporar sincronización.
- Adaptar la aplicación a Android.
- Incorporar una nube sin reescribir el dominio.

No implementar infraestructura futura si no existe necesidad actual.

# 4. EXPERIENCIA DEL AGRICULTOR — PRIORIDAD MÁXIMA

NASA Field Shift debe resultar comprensible incluso para agricultores con poca experiencia digital, distintos niveles de alfabetización y acceso limitado a tecnología.

**La interfaz debe ser extremadamente sencilla.**

La complejidad científica debe permanecer detrás de la aplicación.

No convertir el visor en un sistema SIG difícil de utilizar.

## 4.1. Modo agricultor — predeterminado

Crear una interfaz intuitiva con:

- Mapa principal.
- Botones grandes.
- Iconos comprensibles.
- Texto sencillo.
- Muy pocas opciones visibles a la vez.
- Navegación guiada.
- Instrucciones visuales.
- Leyendas interpretables.
- Explicaciones breves.
- Estados de carga y error comprensibles.

El usuario debe poder realizar estas acciones:

1. Encontrar su terreno.
2. Marcar sus límites.
3. Seleccionar qué quiere conocer.
4. Visualizar la información.
5. Entender qué representa.
6. Guardar su terreno.
7. Consultar cambios históricos.

Traducir términos técnicos a lenguaje agrícola:

- NDVI → Estado de la vegetación.
- NDMI → Agua en la vegetación.
- BSI → Suelo descubierto.
- Precipitación → Cuánto ha llovido.
- Temperatura superficial → Calor de la superficie.

Estas etiquetas son explicaciones simplificadas, no diagnósticos agronómicos.

No presentar un índice bajo como prueba automática de enfermedad, deficiencia nutricional o falta de riego.

Preparar una arquitectura compatible con accesibilidad, localización y futuras explicaciones por voz, sin construir servicios de voz innecesarios.

## 4.2. Modo avanzado

Incluir acceso opcional a:

- Satélites.
- Productos científicos.
- Bandas espectrales.
- Fórmulas.
- Índices.
- Valores por píxel.
- Resoluciones.
- Metadatos.
- Estadísticas.
- Series temporales.
- Calidad e incertidumbre.

Ambos modos deben compartir modelos, cálculos y almacenamiento.

No duplicar motores científicos.

## 4.3. Diseño visual

Aplicar una estética profesional, moderna, clara y limpia.

Utilizar jerarquía visual consistente, iconografía comprensible, buena legibilidad y contraste.

No saturar la pantalla con paneles.

Mostrar controles avanzados progresivamente.

Las leyendas deben utilizar colores acompañados de texto y significado, evitando depender solamente del color.

# 5. INTERFAZ PRINCIPAL WINDOWS

Construir una interfaz adaptable a distintas resoluciones.

## Barra superior

- NASA Field Shift.
- Inicio.
- Mis terrenos.
- Explorar mapa.
- Análisis.
- Configuración.

## Mapa central

Debe ocupar la mayor parte de la aplicación.

Implementar:

- Zoom.
- Desplazamiento.
- Coordenadas.
- Escala.
- Búsqueda por coordenadas.
- Navegación por ubicaciones.
- Cambio de mapa base.
- Capas satelitales.
- Activación/desactivación.
- Transparencia.
- Selección de puntos.
- Dibujo y edición de polígonos.
- Medición de áreas.
- Leyendas.
- Información contextual.

La búsqueda por nombres de lugares podrá incorporarse mediante un proveedor apropiado si existe una solución viable y justificada; no es necesario contratar un servicio de geocodificación en este entregable.

## Panel contextual

Mostrar solamente información relevante para la tarea seleccionada.

## Herramientas temporales

Permitir seleccionar fechas y explorar observaciones históricas.

La comparación de fechas debe utilizar la misma localización, escala y georreferenciación.

# 6. MOTOR CARTOGRÁFICO Y GPU

Evaluar el estado actual de MapLibre para Flutter Windows antes de integrarlo.

Verificar:

- Compatibilidad con la versión de Flutter instalada.
- Estabilidad.
- API pública disponible.
- Soporte raster y vectorial.
- Manejo de capas.
- Rendimiento.
- Renderizado GPU.
- Limitaciones del backend Windows.

Preferir tecnologías estables.

No asumir que una versión experimental ofrece funcionalidad completa.

Si MapLibre presenta una incompatibilidad real, investigar y aplicar una alternativa documentada detrás de un contrato cartográfico, sin acoplarla al dominio.

No introducir múltiples motores simultáneamente.

No recalcular información científica durante movimientos, zoom o desplazamientos.

Separar completamente renderizado y procesamiento raster.

# 7. DELIMITACIÓN DE TERRENOS AGRÍCOLAS

Implementar una herramienta extremadamente sencilla para marcar parcelas.

El agricultor deberá poder:

- Señalar puntos sobre el mapa.
- Formar un polígono.
- Ver sus límites.
- Mover o corregir vértices.
- Deshacer errores.
- Guardar.
- Editar.
- Eliminar.
- Recuperar parcelas.
- Asignar nombres.
- Registrar el cultivo actual.

Calcular el área en hectáreas mediante métodos geodésicos o proyección adecuada.

No calcular superficies únicamente con píxeles de pantalla.

Validar geometrías inválidas, polígonos autointersecados y cantidad insuficiente de vértices.

Guardar geometrías con coordenadas y referencia espacial conocidas.

Las estadísticas agrícolas por parcela solo deben calcularse cuando exista una geometría válida.

# 8. FUENTES SATELITALES AUTÉNTICAS

No utilizar imágenes artificiales o datos simulados como resultados científicos.

## 8.1. Sentinel-2 — fuente óptica principal

Priorizar Sentinel-2 Level-2A.

Implementar:

- Consulta de catálogo STAC.
- Búsqueda por geometría o extensión.
- Filtro por fechas.
- Identificación de escenas.
- Nubosidad reportada.
- Fecha de adquisición.
- Identificadores del producto.
- Metadatos.
- Selección de escenas.
- Acceso a recursos disponibles.
- Visualización RGB natural.
- Falso color cuando exista acceso a bandas.
- Máscaras de calidad.

Verificar endpoints reales, autenticación, disponibilidad de recursos y condiciones de uso.

No asumir que consultar un catálogo implica poder descargar todos sus activos.

No almacenar secretos en el repositorio.

## 8.2. Landsat — componente NASA

Incorporar Landsat Collection 2 Level-2 cuando las funcionalidades anteriores sean estables.

Utilizar reflectancia superficial y temperatura superficial según disponibilidad y validez del producto.

Respetar sus factores de escala, offsets, máscaras y resoluciones.

No mezclar valores de Sentinel-2 y Landsat sin la armonización científica correspondiente.

## 8.3. NASA GIBS

Integrar capas visuales NASA mediante servicios oficiales de teselas.

Verificar:

- Capas disponibles.
- Proyección.
- Formato.
- Fechas.
- Resoluciones.
- Atribución.
- Disponibilidad de teselas.

GIBS se utilizará para visualización.

No calcular índices científicos a partir de PNG o imágenes RGB coloreadas.

## 8.4. NASA POWER

Incorporar progresivamente:

- Temperatura.
- Precipitación.
- Humedad relativa.
- Radiación solar.
- Otros parámetros relevantes.

Registrar unidades, fechas, resolución y procedencia.

No presentar datos climáticos regionales como mediciones exactas de una parcela.

GPM/IMERG será una ampliación posterior si no se puede integrar y verificar durante esta ejecución.

# 9. PROCESAMIENTO MULTIESPECTRAL

Implementar procesamiento real de bandas disponibles.

Visualizaciones:

- RGB natural.
- Falso color infrarrojo.
- Composiciones SWIR.
- Bandas individuales.
- Mapas de índices espectrales.

Priorizar:

1. NDVI.
2. NDMI.
3. NDRE.
4. SAVI.
5. NDWI.
6. BSI.

NDVI y NDMI constituyen la primera prioridad funcional.

Los demás podrán incorporarse después de comprobar la calidad y el rendimiento de los anteriores. NDRE, SAVI, NDWI y BSI quedan registrados como ampliaciones, no como funcionalidad verificada automáticamente si no han sido implementados.

## Reglas científicas

- Utilizar reflectancias científicas, no colores RGB.
- Aplicar escala y offset adecuados.
- Comprobar denominadores y divisiones por cero.
- Excluir píxeles inválidos.
- Aplicar máscaras de nubes y sombras.
- Considerar calidad del producto.
- Controlar distintas resoluciones entre bandas.
- Conservar georreferenciación.
- Registrar método y versión de cálculo.
- Evitar interpolaciones que aparenten precisión inexistente.

NDMI no representa directamente humedad volumétrica del suelo.

NDRE no es una medición directa de nitrógeno.

NDVI no identifica por sí solo enfermedades agrícolas.

No declarar precisión que no haya sido validada.

# 10. LEYENDAS Y ANÁLISIS VISUAL

Cada visualización científica debe incluir:

- Nombre sencillo.
- Nombre técnico opcional.
- Colores interpretables.
- Escala.
- Valores.
- Fecha.
- Fuente.
- Resolución.
- Calidad.
- Explicación breve.

Utilizar escalas consistentes entre fechas para permitir comparaciones válidas.

Distinguir nubes, sombras y ausencia de datos.

La interpretación debe ser conservadora y científicamente fundamentada.

# 11. ESTADÍSTICAS POR PARCELA

Cuando existan datos raster científicos válidos, implementar:

- Promedio.
- Mínimo.
- Máximo.
- Mediana.
- Dispersión.
- Número de píxeles válidos.
- Porcentaje de cobertura válida.
- Fecha de adquisición.
- Resolución efectiva.

Utilizar la geometría real de la parcela.

No incluir píxeles inválidos en los cálculos.

Informar cuando la parcela sea demasiado pequeña para una evaluación fiable.

No inventar estadísticas si no existe información disponible.

Si no se dispone de bandas auténticas, conservar el visor funcional y mostrar claramente la ausencia de datos.

# 12. ALMACENAMIENTO LOCAL

Aplicar Local-First.

Preferir SQLite/Drift si su integración está justificada y es compatible.

Guardar:

- Parcelas.
- Límites geográficos.
- Cultivos registrados.
- Preferencias.
- Capas seleccionadas.
- Metadatos.
- Resultados calculados.
- Configuración del usuario.

Implementar almacenamiento y recuperación reales.

Separar los datos de usuario del directorio de instalación.

Preservar los datos ante actualizaciones.

Incorporar migraciones de esquema cuando sea necesario.

## Caché

Mantener caché limitada para:

- Teselas.
- Subconjuntos raster.
- Consultas.
- Metadatos.
- Estadísticas reutilizables.

Usar identificadores basados en producto, versión, área, fecha, variable y versión de procesamiento.

Aplicar límites de tamaño y políticas de eliminación.

No construir un repositorio local gigantesco de escenas satelitales.

# 13. RENDIMIENTO Y RECURSOS

Optimizar:

- CPU.
- RAM.
- GPU.
- VRAM.
- Almacenamiento.
- Red.

Requisitos:

- No bloquear el hilo UI.
- No reconstruir mapas innecesariamente.
- No recalcular índices al desplazar el mapa.
- No descargar escenas completas cuando exista acceso parcial.
- Utilizar teselas y carga progresiva.
- Controlar concurrencia.
- Evitar solicitudes duplicadas.
- Cancelar tareas obsoletas cuando corresponda.
- Reutilizar resultados.
- Liberar recursos después de procesar.
- Separar procesamiento y renderizado.

Utilizar Dart Isolates cuando sean adecuados.

No incorporar C++, Python o motores GPU especializados sin necesidad técnica demostrada.

Si se incorpora procesamiento nativo, mantenerlo detrás de contratos y prever alternativas multiplataforma.

Realizar mediciones cuando el entorno lo permita.

No inventar FPS ni consumo de memoria.

# 14. FUNCIONAMIENTO SIN INTERNET

La aplicación debe:

- Abrirse sin conexión.
- Recuperar parcelas guardadas.
- Permitir editar sus límites.
- Mostrar recursos cartográficos previamente descargados.
- Consultar resultados locales existentes.

Cuando falten mapas o datos remotos, mostrar mensajes claros.

No afirmar que existe funcionalidad offline para una capa que no está descargada.

No implementar sincronización en la nube durante esta ejecución.

Preparar la arquitectura para añadirla sin modificar el dominio.

# 15. ANÁLISIS AGRÍCOLA Y ROTACIONES

Este bloque se implementará después de comprobar cartografía, parcelas e indicadores científicos.

Registrar información agrícola:

- Cultivo actual.
- Historial de cultivos.
- Tipo de suelo.
- Disponibilidad de agua.
- Sistema de riego.
- Restricciones económicas.
- Prioridades del agricultor.

La plataforma deberá evolucionar hacia la comparación de al menos tres estrategias de rotación, incluyendo la actual. Esta capacidad pertenece al alcance futuro de la plataforma y debe conservarse en el registro de requisitos, sin fingir que forma parte de la entrega Windows v1 si aún no se ha desarrollado.

Evaluar posteriormente:

- Agua.
- Nutrientes.
- Protección del suelo.
- Erosión.
- Plagas.
- Compatibilidad de cultivos.
- Materia orgánica.
- Aptitud climática.
- Rentabilidad.

No inventar recomendaciones agronómicas ni rendimientos.

Si no se dispone de datos confiables suficientes, registrar la información y dejar la comparación completa pendiente.

No dedicar recursos a un motor de recomendaciones ficticio mientras el visor y sus análisis principales sigan incompletos.

# 16. ESTRATEGIA DE EJECUCIÓN AUTÓNOMA

**Esta instrucción solicita una única sesión continua de trabajo autónomo, sin pausas de aprobación entre fases ordinarias. No supone que todos los requisitos puedan completarse si existen límites de tiempo, contexto, permisos, herramientas o proveedores.**

No te detengas para solicitar confirmación al terminar tareas normales.

Trabaja siguiendo estrictamente esta prioridad. **P0, P1, P2, P3 y P4 integran el alcance objetivo de Windows v1**; no rebajes automáticamente una prioridad a «opcional» por conveniencia. Si no puedes completar alguno de sus requisitos, márcalo como pendiente y no declares el 100 %. Las funciones indicadas explícitamente como futuras o ampliaciones se registran aparte.

## P0 — Fundación y mapa Windows

- Workspace y dependencias correctas.
- Arquitectura desacoplada.
- Aplicación Flutter funcional.
- Interfaz sencilla.
- Mapa interactivo.
- Controles básicos.
- Dibujar, editar y guardar parcelas.
- Compilación Windows.

## P1 — Imágenes reales

- NASA GIBS.
- Catálogo Sentinel-2.
- Consulta de escenas.
- Visualización de imagen disponible.
- Fechas.
- Metadatos.
- Capas y leyendas.

## P2 — Procesamiento agrícola

- RGB/falso color desde datos adecuados.
- NDVI.
- NDMI.
- Máscaras.
- Estadísticas por parcela.
- Leyendas científicas.

## P3 — Análisis complementario

- Series temporales.
- Comparación de fechas.
- Landsat.
- NASA POWER.
- Registro agrícola básico.

## P4 — Estabilización

- Corrección de errores.
- Pruebas.
- Rendimiento.
- Manejo de fallos de red.
- Persistencia.
- Compilación final Windows.
- Distribución ejecutable.

No comenzar funciones de una prioridad inferior si las fundamentales de la prioridad superior están rotas. Ejecuta pruebas focalizadas y verifica la integridad modular al incorporar cada prioridad; no postergues toda la calidad hasta P4.

No gastar tiempo en implementaciones enormes de funcionalidades secundarias.

No generar módulos vacíos ni documentación excesiva.

No duplicar código.

No agregar dependencias innecesarias.

No repetir pruebas idénticas sin cambios.

No refactorizar implementaciones estables sin una razón concreta.

Si un servicio falla:

1. Identifica el error.
2. Comprueba endpoint, autenticación y parámetros.
3. Intenta una corrección razonable.
4. Si persiste una limitación externa, registra el problema y continúa con funciones independientes.

No reemplaces datos reales por datos falsos para aparentar que una integración funciona.

No esperes instrucciones entre fases.

Solo solicita intervención cuando resulte imprescindible obtener credenciales, autorización de seguridad o resolver un bloqueo que no permita continuar de forma segura.

# 17. PRUEBAS Y CALIDAD

Ejecutar según corresponda:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build windows`

También:

- Pruebas unitarias por módulo.
- Pruebas de contratos públicos.
- Pruebas de geometría y superficies.
- Pruebas de índices espectrales.
- Pruebas de persistencia.
- Pruebas de integración de adaptadores.
- Pruebas de errores de red.
- Pruebas de regresión.

## Verificación arquitectónica obligatoria

Comprobar que:

1. No existan dependencias circulares.
2. Ningún módulo importe implementaciones internas ajenas.
3. El dominio científico no dependa de Flutter.
4. El renderizador no contenga algoritmos científicos.
5. Los conectores no dependan de widgets.
6. La persistencia esté encapsulada.
7. Los contratos sean verificables independientemente.
8. No existan dependencias innecesarias.
9. No se haya eliminado funcionalidad existente.

La compilación correcta no demuestra que todas las funciones se hayan probado. Cada requisito del alcance Windows v1 debe enlazarse con una evidencia concreta en la matriz de cobertura de la sección 19.

Distinguir pruebas automáticas, inspección manual y validación científica.

# 18. DOCUMENTACIÓN Y CONTINUIDAD

Mantener documentación mínima y útil.

Crear o actualizar cuando corresponda:

- `docs/PROJECT_STATUS.md`
- `docs/DECISIONS.md`
- `docs/MODULE_CONTRACTS.md`
- `docs/REQUIREMENTS_TRACEABILITY.md` (obligatorio para registrar cobertura y evidencia)

Registrar:

- Decisiones arquitectónicas.
- Contratos relevantes.
- Implementaciones reales.
- Problemas conocidos.
- Pruebas ejecutadas.
- Funcionalidades pendientes.

No modificar las instrucciones de `AGENTS.md` innecesariamente.

# 19. CONDICIÓN DE FINALIZACIÓN, COBERTURA FUNCIONAL Y EVIDENCIA

## 19.1. Objetivo de cobertura

El objetivo es alcanzar el **100 % del alcance Windows v1**, definido por los requisitos de P0, P1, P2, P3 y P4, sin confundirlo con el 100 % de la futura plataforma multiplataforma. Esto es una meta de ejecución, **no una garantía anticipada de entrega**.

Los elementos mencionados expresamente como futuras ampliaciones (por ejemplo, sincronización en nube, compilaciones Android/iOS/web, motor completo de rotaciones agrícolas, GPM/IMERG condicionado y los índices secundarios cuando estén designados como ampliaciones) deben quedar trazados como **FUTURO**, no desaparecer de los requisitos ni contarse falsamente como terminados.

**No reduzcas ni redefinas silenciosamente el alcance v1.** Si un requisito P0–P4 es inviable por un bloqueo técnico, falta de credenciales, incompatibilidad de Windows, datos inaccesibles o limitaciones de la ejecución, permanece pendiente y la cobertura no es del 100 %.

## 19.2. Registro obligatorio de requisitos

Crea y mantén `docs/REQUIREMENTS_TRACEABILITY.md` desde el inicio de los cambios. Incluye **una fila por requisito verificable** con estas columnas:

| ID | Requisito y criterio de aceptación | Prioridad/módulo | Alcance (V1/FUTURO) | Estado | Evidencia y prueba | Bloqueo/observación |
| --- | --- | --- | --- | --- | --- | --- |

Utiliza IDs estables como `P0-MAP-01`, `P0-FIELD-02`, `P1-STAC-01`, `P2-NDVI-01`, `P3-POWER-01`, `P4-BUILD-01`. La enumeración debe derivarse del alcance real de este documento: no omitas requisitos para elevar artificialmente el porcentaje.

Estados permitidos para requisitos de V1:

1. **IMPLEMENTADO Y PROBADO:** función integrada, con evidencia concreta suficiente para su naturaleza (prueba automática, integración real, ejecución de interfaz o validación científica pertinente), sin fallos conocidos que invaliden el criterio de aceptación.
2. **IMPLEMENTADO, PERO NO VERIFICADO:** existe código funcional previsto, pero falta evidencia, prueba relevante, validación de integración, comprobación visual o verificación científica.
3. **PENDIENTE O BLOQUEADO:** requisito no realizado, incompleto, deshabilitado, con un fallo que impide usarlo, o dependiente de permisos/datos/servicios no disponibles. Indica la causa exacta.

Los requisitos fuera de V1 deben registrarse con alcance **FUTURO** y no computarse en el porcentaje V1. No presentes FUTURO como estado de una función incluida en P0–P4.

## 19.3. Evidencia mínima para declarar probado

- **Código y arquitectura:** archivos reales, contratos públicos, ausencia de ciclos e imports internos indebidos, pruebas del módulo afectado.
- **Interfaz Windows:** compilación y, cuando el entorno lo permita, apertura real de la aplicación e interacción comprobada con mapa, capas, parcelas y controles. Compilar no demuestra que el mapa aparezca ni que una persona pueda usarlo.
- **Persistencia:** prueba de guardar, cerrar/reabrir o reinicializar el repositorio y recuperar correctamente la parcela; contemplar errores y migraciones aplicables.
- **APIs externas:** respuestas reales del proveedor para una consulta concreta, metadatos y manejo de errores. Un mock o fixture prueba la lógica del adaptador, pero no la disponibilidad real del servicio.
- **Índices científicos:** casos de prueba reproducibles con datos conocidos, aplicación correcta de escala, máscara, resolución, georreferenciación y manejo de valores inválidos. Un PNG coloreado no valida NDVI/NDMI.
- **Rendimiento:** mediciones reproducibles si se afirma una mejora; no inventar FPS, memoria o tiempos.
- **Usabilidad agrícola:** la revisión automática de accesibilidad y la inspección visual no equivalen a una prueba con agricultores reales. Si no se realizan pruebas de campo, indicarlo expresamente como validación externa pendiente.

Registra el comando, resultado, ruta de prueba o evidencia y cualquier limitación de cada comprobación. No inventes capturas, reportes ni pruebas ejecutadas.

## 19.4. Cálculo y declaración de cobertura

La cobertura de Windows v1 se calcula usando **todos los requisitos obligatorios de P0–P4** enumerados en la matriz:

`Cobertura verificada (%) = 100 × (requisitos V1 en IMPLEMENTADO Y PROBADO / total de requisitos V1)`

Indica también por separado la cantidad **implementada sin verificar** y **pendiente o bloqueada**. No uses métricas basadas en líneas de código, número de archivos o pantallas dibujadas.

Solo declara **«100 % del alcance Windows v1 implementado y probado»** si **todos** los requisitos V1 están en `IMPLEMENTADO Y PROBADO` y no hay bloqueos de aceptación. Si no se pudo verificar visualmente, científicamente o mediante integración real una función que lo requiere, no la cuentes como probada.

La cobertura técnica de V1 no debe confundirse con certificación de producción, aceptación de agricultores, validación agronómica de campo ni finalización de la plataforma futura. Expón por separado esas validaciones si siguen pendientes.

## 19.5. Autonomía sin ocultar limitaciones

Trabaja durante una sola ejecución continua, sin solicitar aprobación entre pasos ordinarios. Sigue intentando resolver fallos razonables, conserva lo que funcione y continúa con tareas independientes cuando exista un bloqueo externo.

No reemplaces funciones reales por simulaciones ni rebajes la precisión científica para aparentar finalización. No introduzcas acoplamientos o dependencias circulares para acelerar el avance. No borres funciones verificadas de otras áreas.

Si la ejecución llega a un límite de herramientas, contexto o permisos, entrega el repositorio en un estado coherente, documenta exactamente lo que falta y deja comandos y requisitos identificados para reanudar sin rehacer trabajo. **No declares éxito completo por haber agotado la ejecución.**

# 20. INFORME FINAL

Al terminar, entregar un informe breve y verificable, incluyendo el recuento de requisitos V1 probados, sin verificar y pendientes, más el porcentaje calculado conforme a la sección 19.

## IMPLEMENTADO
- Funcionalidades terminadas.
- Módulos.
- Archivos modificados.

## PROBADO
- Comandos ejecutados.
- Resultados.
- Integraciones reales verificadas.

## PENDIENTE
- Funciones incompletas.
- Errores.
- Limitaciones técnicas.
- Dependencias de proveedores externos.

## EJECUCIÓN
- Comando para iniciar la aplicación.
- Ubicación del ejecutable generado.
- Instrucciones mínimas de uso.

No declarar terminado lo que no funciona.

No afirmar que una imagen es real si no fue obtenida de su proveedor.

No afirmar que un cálculo científico es válido sin comprobar sus datos y metodología.

# 21. CONDICIÓN FINAL

El objetivo es obtener **NASA Field Shift para Windows**, con una experiencia extremadamente sencilla para agricultores, datos geoespaciales auténticos y arquitectura preparada para crecer.

Prioridades permanentes:

1. Arquitectura modular y desacoplada.
2. Rigor científico y trazabilidad.
3. Facilidad de uso para agricultores.
4. Funcionalidades reales y verificables.
5. Estabilidad.
6. Rendimiento.
7. Bajo consumo de recursos.
8. Instalación sencilla.
9. Mantenimiento.
10. Escalabilidad futura.

**Una sola ejecución no significa un monolito.**

Intenta completar todos los requisitos de Windows v1 durante una sola sesión continua, sin sacrificar contratos, calidad científica ni pruebas. El 100 % solo puede declararse tras verificar cada criterio de aceptación conforme a la sección 19; si algún requisito queda pendiente, informa la cobertura real.

Prefiero menos funcionalidades completas y correctamente desacopladas antes que una gran aplicación llena de pantallas simuladas, errores o componentes acoplados.

**COMIENZA AHORA: inspecciona el repositorio, crea la matriz de requisitos, implementa P0 y continúa por P1–P4 con pruebas y verificaciones. Entrega la aplicación Windows más completa y verificable posible, indicando su cobertura real sin afirmar un 100 % no demostrado.**
