FROM python:3.13-slim
WORKDIR /opt/field-shift
COPY apps/field_shift_api/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
COPY apps/field_shift_api/server.py apps/field_shift_api/server.py
COPY packages/field_compute/worker/raster_worker.py packages/field_compute/worker/raster_worker.py
ENV PYTHONUNBUFFERED=1
CMD ["sh", "-c", "exec uvicorn apps.field_shift_api.server:app --host 0.0.0.0 --port ${PORT:-10000}"]
