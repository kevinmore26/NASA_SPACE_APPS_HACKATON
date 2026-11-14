"""Registro completo del alcance: actualizar evidencia, nunca retirar pendientes."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GROUPS = {
 'P0': [
 ('ARCH-01','Workspace compatible y aplicación modular sin ciclos ni imports internos ajenos','workspace'),
 ('ARCH-02','Contratos públicos tipados/versionados y dominio sin Flutter, red o SQLite','dominio'),
 ('MAP-01','Motor Windows evaluado y sustituible; único renderizador','field_maps'),
 ('UI-01','Modo agricultor predeterminado, botones grandes, texto/iconos y ayuda por pasos','app'),
 ('UI-02','Navegación Inicio, Mis terrenos, Explorar, Análisis y Configuración','app'),
 ('UI-03','Diseño adaptable, contraste, errores y carga comprensibles','app'),
 ('UI-04','Modo avanzado progresivo comparte motor/modelos con agricultor','app'),
 ('MAP-02','Mapa interactivo: zoom y desplazamiento','field_maps'),
 ('MAP-03','Coordenadas, escala y selección contextual de puntos','field_maps'),
 ('MAP-04','Buscar coordenadas y navegar a parcelas guardadas','app'),
 ('MAP-05','Cambio de mapa base y atribución','field_maps'),
 ('MAP-06','Capas activables con transparencia','field_maps'),
 ('FIELD-01','Dibujar límites con instrucciones y ver polígono','field_maps'),
 ('FIELD-02','Mover/corregir vértices y deshacer','app'),
 ('FIELD-03','Guardar, recuperar, editar y eliminar parcelas nombradas','storage/app'),
 ('FIELD-04','Área geodésica en hectáreas; geometría WGS84','field_core'),
 ('FIELD-05','Rechazar pocos puntos, duplicados y autointersecciones','field_core'),
 ('BUILD-01','Compilar y abrir aplicación Windows real','app')],
 'P1': [
 ('GIBS-01','Capa NASA GIBS auténtica con proyección/formato/resolución/fecha comprobados','field_nasa'),
 ('GIBS-02','Visualizar teselas reales y distinguirlas de bandas científicas','app'),
 ('STAC-01','Catálogo Sentinel-2 L2A por área y fechas, con filtro de nubes','field_imagery'),
 ('STAC-02','Listar y seleccionar escenas con ID, fecha, nubes, fuente y activos','app'),
 ('STAC-03','Verificar acceso real a activos, condiciones y fallos del proveedor','field_imagery'),
 ('RGB-01','Mostrar imagen RGB auténtica de escena seleccionada','app'),
 ('META-01','Fechas, fuente, resolución, producto, versión y procedencia visibles','app'),
 ('LEGEND-01','Leyendas claras con texto, límites y significado','app')],
 'P2': [
 ('RGB-01','RGB natural desde bandas adecuadas','imagery/compute'),
 ('RGB-02','Falso color infrarrojo desde bandas adecuadas','imagery/compute'),
 ('RGB-03','Composición SWIR y bandas individuales','imagery/compute'),
 ('NDVI-01','NDVI real con fórmula y escala/offset correctos','imagery/compute'),
 ('NDMI-01','NDMI real con fórmula, escala/offset y límites interpretativos','imagery/compute'),
 ('QA-01','Excluir nubes, sombras, inválidos, no finitos y divisiones cero','imagery/compute'),
 ('QA-02','Alinear resoluciones, CRS y georreferenciación sin falsa precisión','imagery/compute'),
 ('STATS-01','Estadísticas por polígono: media, mínimo, máximo, mediana, dispersión','imagery/compute'),
 ('STATS-02','Número y cobertura válida, fecha, resolución y aviso parcela pequeña','imagery/compute'),
 ('META-01','Resultado conserva fuente/producto/versión/fecha/área/unidad/método/calidad/incertidumbre','imagery/storage'),
 ('LEGEND-01','Leyendas científicas consistentes entre fechas, nubes/sombras/sin datos distinguibles','app'),
 ('PIXEL-01','Modo avanzado consulta valores por píxel y bandas','app')],
 'P3': [
 ('TIME-01','Series temporales de resultados científicos reales','app'),
 ('TIME-02','Comparación de fechas con mismo lugar, escala y georreferenciación','app'),
 ('LANDSAT-01','Catálogo y acceso Landsat Collection 2 Level 2 auténtico','field_nasa'),
 ('LANDSAT-02','Reflectancia Landsat con escala/offset/QA/resolución correctos','compute'),
 ('LANDSAT-03','Temperatura superficial Landsat cuando sea válida y disponible','compute'),
 ('POWER-01','NASA POWER real: temperatura, lluvia, humedad relativa y radiación','field_nasa'),
 ('POWER-02','POWER conserva fechas, unidades, procedencia y resolución regional','field_nasa/app'),
 ('AGRI-01','Registrar cultivo actual e historial de cultivos','core/app'),
 ('AGRI-02','Registrar suelo, agua, riego, economía y prioridades','core/app')],
 'P4': [
 ('TEST-01','Pruebas unitarias y contratos por módulo','tests'),
 ('TEST-02','Pruebas integradas y regresión Windows','tests'),
 ('NET-01','Fallos de red, timeout y mensajes claros sin datos inventados','app/adapters'),
 ('STORE-01','Persistencia SQLite real con reinicialización y recuperación','field_storage'),
 ('STORE-02','Esquema versionado, datos externos a instalación y errores controlados','field_storage'),
 ('STORE-03','Persistir preferencias, capas, metadatos y resultados','field_storage'),
 ('CACHE-01','Caché limitada de teselas y recursos consultados','storage/maps'),
 ('CACHE-02','Resultados reutilizables con clave producto/versión/área/fecha/variable/método','storage/compute'),
 ('OFF-01','Abrir offline y recuperar/editar parcelas','app'),
 ('OFF-02','Ver mapas descargados previamente y avisar de recursos ausentes','app'),
 ('OFF-03','Consultar resultados locales sin conexión','app'),
 ('PERF-01','Procesar fuera de UI y no recalcular al navegar mapa','compute/maps'),
 ('PERF-02','Acceso parcial raster, concurrencia limitada, deduplicación/cancelación y liberación','compute/storage'),
 ('PERF-03','Medición reproducible CPU/RAM/GPU/VRAM/disco/red según disponibilidad','tools'),
 ('BUILD-01','Análisis estático, pruebas y compilación Windows final','workspace'),
 ('DIST-01','Distribución ejecutable con dependencias e instrucciones','tools'),
 ('DOC-01','Estado, decisiones, contratos y cobertura con evidencia y pendientes','docs'),
 ('UX-01','Validación de usabilidad con agricultores reales','externo')],
 'FUTURO': [
 ('SYNC','Sincronización opcional en nube','field_sync'),
 ('PLATFORM','Compilaciones Android/iOS/web','app'),
 ('ROTATION','Comparar tres rotaciones incluida actual con validación agronómica','field_rotations'),
 ('INDEX','NDRE, SAVI, NDWI y BSI','field_imagery'),
 ('GPM','GPM/IMERG y otras fuentes justificadas','field_nasa'),
 ('VOICE','Voz, idiomas locales y geocodificación por nombres','app')]
}
def main():
    state_path = ROOT/'docs/requirement_evidence.json'
    state = json.loads(state_path.read_text('utf-8')) if state_path.exists() else {}
    rows=[]; counts=[0,0,0]
    states=['IMPLEMENTADO Y PROBADO','IMPLEMENTADO, PERO NO VERIFICADO','PENDIENTE O BLOQUEADO']
    for priority, reqs in GROUPS.items():
        for suffix,title,module in reqs:
            key=f'{priority}-{suffix}'
            entry=state.get(key, {})
            status=entry.get('status',states[2]) if priority!='FUTURO' else 'FUTURO'
            if priority!='FUTURO': counts[states.index(status)]+=1
            rows.append(f"| {key} | {title} | {priority}/{module} | {'FUTURO' if priority=='FUTURO' else 'V1'} | {status} | {entry.get('evidence','Sin evidencia todavía.')} | {entry.get('note','Por implementar/verificar.' if priority!='FUTURO' else 'Fuera de Windows v1.')} |")
    total=sum(counts)
    text=f'# Cobertura funcional Windows v1\n\n{counts[0]}/{total} probados (**{100*counts[0]/total:.2f}%**); {counts[1]} implementados sin verificar; {counts[2]} pendientes/bloqueados.\n\nNo equivale a validación agronómica ni certificación de producción. Registro derivado de secciones 3–19, sin eliminar requisitos no completados. Generado por `python tools/requirements.py`.\n\n| ID | Requisito y criterio de aceptación | Prioridad/módulo | Alcance (V1/FUTURO) | Estado | Evidencia y prueba | Bloqueo/observación |\n| --- | --- | --- | --- | --- | --- | --- |\n'
    (ROOT/'docs/REQUIREMENTS_TRACEABILITY.md').write_text(text+'\n'.join(rows)+'\n',encoding='utf-8')
if __name__=='__main__': main()
