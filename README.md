# NASA Field Shift V2.2 para Windows

Aplicación de escritorio para guardar parcelas, analizar observaciones satelitales y comparar opciones de rotación. Incluye Sentinel-2 (ESA/Copernicus), Landsat (USGS/NASA), NASA POWER y NASA GIBS. Los terrenos, resultados y registros agrícolas se guardan localmente. La interfaz abre en inglés y el selector EN/ES guarda el idioma elegido.

## Ejecutar en Windows

Requiere Flutter 3.50.0 con Dart 3.14.0, Visual Studio 2022 con desarrollo de escritorio con C++ y Python 3.13. Desde la raíz del proyecto, en PowerShell:

~~~powershell
flutter pub get
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools\requirements-worker.txt
Push-Location apps\field_shift
flutter run -d windows
Pop-Location
~~~

Para empaquetar una compilación de distribución, ejecuta `.\tools\build_windows.ps1` desde la raíz. El script prepara el worker y genera `dist\NASA_Field_Shift_Windows_0.2.2`.

## Usar y verificar

- [Guía de uso en Windows](docs/USO_WINDOWS.md) con el flujo de mapa, análisis y planificador.
- [Publicar la app web](docs/WEB.md) con la interfaz Flutter y el servicio de procesamiento.
- [Estado del proyecto](docs/PROJECT_STATUS.md) con las reglas del piloto, los cambios y los resultados de verificación.
- [Contratos y método científico](docs/MODULE_CONTRACTS.md) y [decisiones de arquitectura](docs/DECISIONS.md).
- [Cobertura de V1](docs/REQUIREMENTS_TRACEABILITY.md) con la evidencia histórica del proyecto.

Para ejecutar la suite de Windows desde la raíz, usa `.\.venv\Scripts\python.exe tools\verify_all.py`.
