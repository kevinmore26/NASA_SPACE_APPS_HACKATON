FROM python:3.13-slim
WORKDIR /opt/field-shift

RUN apt-get update \
    && apt-get install -y --no-install-recommends libexpat1 \
    && rm -rf /var/lib/apt/lists/*

COPY apps/field_shift_api/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY apps/field_shift_api/server.py apps/field_shift_api/server.py
COPY apps/field_shift_api/crop_suitability.py apps/field_shift_api/crop_suitability.py
COPY ml/crop_recommender.py ml/crop_recommender.py
COPY ml/data/EcoCrop_DB.csv ml/data/EcoCrop_DB.csv
COPY packages/field_compute/worker/raster_worker.py packages/field_compute/worker/raster_worker.py
RUN python -c "from packages.field_compute.worker import raster_worker"
RUN python -c "from ml.crop_recommender import CropRecommender"

ENV PYTHONUNBUFFERED=1
CMD ["sh", "-c", "exec uvicorn apps.field_shift_api.server:app --host 0.0.0.0 --port ${PORT:-10000}"]
