# Publicar NASA Field Shift como página web

Flutter genera el sitio estático. La página guarda parcelas, preferencias y observaciones en IndexedDB. FastAPI consulta los catálogos de imágenes y NASA POWER, y ejecuta el worker de análisis cuando el usuario lo solicita.

## 1. Subir el código

Haz el commit de los cambios web sobre el código de la V2.2 y envíalo al repositorio de GitHub. Render toma el backend de ese repositorio. El commit puede llamarse `feat(web): run Field Shift in the browser`.

## 2. Publicar la API en Render

1. Crea un **Web Service**, conecta el repositorio y elige la rama que tiene los cambios web.
2. Elige **Docker**. Deja **Root Directory** vacío y pon `./apps/field_shift_api/Dockerfile` en **Dockerfile Path**. Usa la raíz del repositorio como contexto de Docker.
3. Elige **Free** para la primera prueba. En **Health Check Path** usa `/health`.
4. Despliega y abre `https://TU_SERVICIO.onrender.com/health`. Debe devolver `{"status":"ok"}`.

[Configuración de Docker en Render](https://render.com/docs/docker)

## 3. Publicar Flutter en Netlify

Ejecuta en PowerShell desde la raíz del proyecto. Sustituye la URL por la de tu servicio en Render.

```powershell
flutter pub get
$apiUrl = 'https://TU_SERVICIO.onrender.com'
Push-Location apps/field_shift
flutter build web --no-web-resources-cdn "--dart-define=FIELD_SHIFT_API_URL=$apiUrl"
Pop-Location
```

1. Abre [Netlify Drop](https://app.netlify.com/drop) y arrastra la carpeta `apps/field_shift/build/web`.
2. Copia la URL de la página generada. En Render → **Environment**, agrega `FIELD_SHIFT_WEB_ORIGIN` con ese origen exacto. Ejemplo de valor `https://tu-proyecto.netlify.app`.
3. Espera el nuevo despliegue de Render. Abre el enlace de Netlify y comprueba que puedes guardar una parcela, recuperarla tras recargar, consultar clima y procesar una imagen.

[Publicar una carpeta compilada en Netlify](https://docs.netlify.com/manage/projects/add-new-project/)

## Evaluación de cultivos

**Planificador → Evaluar cultivos** consulta `POST /api/crops/suitability` en la API de Render. La solicitud lleva el centro del terreno guardado y, cuando existen, textura, drenaje y conductividad declarados. La respuesta guarda la ubicación consultada, el periodo histórico, las fuentes y hasta cinco cultivos en el navegador. El resultado sigue disponible sin conexión con los mismos datos del terreno.

El motor de Guillermo (`ml/crop_recommender.py`, rama `guillermo`) usa un punto de NASA POWER Daily y las mejores ventanas históricas de 2015 a 2024. El cálculo toma la lluvia histórica y los datos de suelo disponibles. Si solo hay opciones al evaluar temperatura y suelo, se muestran con un aviso para revisar el agua disponible. El planificador presenta esos puntajes orientativos junto a la comparación de rotaciones del piloto.

Para construir el contenedor, incorpora a `main` `ml/crop_recommender.py` y `ml/data/EcoCrop_DB.csv` de la rama de Guillermo. Docker instala pandas y requests con las demás dependencias del servicio. El mismo `FIELD_SHIFT_API_URL` del build conecta Flutter con el endpoint nuevo.

Fuentes del motor y las categorías de suelo. [NASA POWER Daily API](https://power.larc.nasa.gov/docs/services/api/temporal/daily/) · [Base EcoCrop de la FAO, distribuida por OpenCLIM](https://github.com/OpenCLIM/ecocrop) · [Clases de textura de EcoCrop, tabla 2](https://edepot.wur.nl/709345).

## Actualizaciones

Render puede actualizar la API desde la rama conectada. Para una nueva versión de la interfaz, vuelve a ejecutar el build y arrastra `build/web` a **Deploys** del mismo proyecto de Netlify. Comparte la URL del proyecto con el jurado.

En la demo web, las parcelas y observaciones se guardan por navegador y dominio. En modo sin conexión puedes consultar las observaciones guardadas en la pestaña abierta. El mapa base y las consultas nuevas usan internet. Render Free entra en reposo tras 15 minutos de inactividad. Su disco temporal guarda los rásteres durante la vida de la instancia. Usa una parcela pequeña para medir el tiempo de procesamiento en la instancia.

Para Android, el cliente de análisis HTTP y ese servicio permiten reutilizar el procesamiento. El APK requiere su propia integración y validación.
