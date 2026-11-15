"""Use Guillermo's EcoCrop scorer with the inputs from a saved field."""
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal

import requests
from fastapi import HTTPException
from pydantic import BaseModel, Field, FiniteFloat

DATA = Path(__file__).resolve().parents[2] / "ml" / "data"
MAX_CROPS = 5
TEXTURES = {"sandyLoam": "medium", "loam": "medium", "clay": "heavy"}
DRAINAGE = {"good": "well", "poor": "poorly"}


class CropSuitabilityRequest(BaseModel):
    latitude: FiniteFloat = Field(ge=-85, le=85, strict=True)
    longitude: FiniteFloat = Field(ge=-180, le=180, strict=True)
    texture: Literal["sandyLoam", "loam", "clay"] | None = None
    drainage: Literal["good", "poor"] | None = None
    soilConductivity: FiniteFloat | None = Field(default=None, ge=0, strict=True)

    def soil_inputs(self) -> dict[str, str | float]:
        soil: dict[str, str | float] = {}
        if self.texture is not None:
            soil["soil_texture"] = TEXTURES[self.texture]
        if self.drainage is not None:
            soil["soil_drainage"] = DRAINAGE[self.drainage]
        if self.soilConductivity is not None:
            soil["soil_ec_ds_m"] = self.soilConductivity
        return soil


def evaluate_crops(field: CropSuitabilityRequest):
    from ml.crop_recommender import CropRecommender

    if not (DATA / "EcoCrop_DB.csv").is_file():
        raise HTTPException(503, "The EcoCrop catalog is unavailable.")

    soil = field.soil_inputs()
    try:
        # POWER describes a regional grid cell. Use one query per field.
        engine = CropRecommender(
            field.latitude,
            field.longitude,
            ring_points=0,
            soil=soil,
            data_dir=DATA,
            timeout=27,
        )
        with engine.http:
            result = engine.recommend()
    except requests.Timeout as error:
        raise HTTPException(504, "NASA POWER took too long to respond.") from error
    except (requests.RequestException, RuntimeError, ValueError, OSError) as error:
        raise HTTPException(
            502, "Could not evaluate crops with the available climate data.",
        ) from error

    rows = result["recommendations"]
    if rows:
        status = "candidates"
        score_key = "score_escenario_actual_0_100"
    else:
        score_key = "score_condicional_con_agua_0_100"
        rows = [row for row in result["alternatives_not_optimal"] if row[score_key] > 0]
        status = "conditional" if rows else "empty"

    metadata = result["metadata"]
    return {
        "schema": 1,
        "status": status,
        "point": metadata["center"],
        "period": metadata["period"],
        "source": metadata["source"],
        "catalog": "FAO EcoCrop (OpenCLIM)",
        "soilFactors": list(soil),
        "evaluatedAt": datetime.now(timezone.utc).isoformat(),
        "crops": [
            {
                "name": row["cultivo_comun"],
                "scientificName": row["nombre_cientifico"],
                "score": row[score_key],
            }
            for row in rows[:MAX_CROPS]
        ],
    }
