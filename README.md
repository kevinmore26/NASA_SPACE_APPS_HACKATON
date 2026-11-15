# NASA Field Shift · Windows

Visor agrícola Flutter con parcelas locales, NASA GIBS, Sentinel-2/Copernicus, Landsat USGS/NASA, NASA POWER y procesamiento científico de ventanas COG.

Abre `dist/NASA_Field_Shift_Windows_0.1.0/field_shift.exe` conservando toda su carpeta. Lee [uso Windows](docs/USO_WINDOWS.md), [estado real](docs/PROJECT_STATUS.md) y [cobertura por requisito](docs/REQUIREMENTS_TRACEABILITY.md). No es una herramienta de diagnóstico agronómico validada.

Desarrollo Windows: Flutter 3.47.1/Dart 3.13.1 y Visual Studio C++. Desde la raíz:

```powershell
flutter pub get
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools/requirements-worker.txt
.\tools\build_windows.ps1
```

Pruebas reproducibles: `tools/verify_all.ps1`. Integración real: desde `apps/field_shift`, `dart run bin/verify_live.dart`; luego desde la raíz, `.\.venv\Scripts\python.exe tools/verify_science_live.py`. Los servicios externos pueden cambiar, limitar consultas o tener períodos sin cobertura.

Los módulos no importan implementaciones internas ajenas. Consultar [contratos y métodos](docs/MODULE_CONTRACTS.md) y [decisiones](docs/DECISIONS.md). Las plantillas iniciales de ejemplos/pruebas se mantienen por compatibilidad, pero no constituyen evidencia agrícola.
