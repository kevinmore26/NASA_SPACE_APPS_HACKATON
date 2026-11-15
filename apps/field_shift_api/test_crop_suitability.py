import math
import tempfile
import unittest

import pandas as pd

from ml.crop_recommender import CropRecommender


class EcoCropScoringTest(unittest.TestCase):
    def test_accepts_textures_listed_in_the_catalog(self):
        crop = pd.Series({"TEXT": "medium, light", "TEXTR": "heavy, medium, light"})
        with tempfile.TemporaryDirectory() as data:
            engine = CropRecommender(0, 0, data_dir=data, soil={"soil_texture": "loam"})
            with engine.http:
                self.assertEqual(engine._soil_score(crop, {})["score_textura"], 100)
                self.assertEqual(
                    engine._soil_score(crop, {"soil_texture": "clay"})["score_textura"],
                    70,
                )

    def test_missing_climate_does_not_count_as_zero_suitability(self):
        score = CropRecommender._score([float("nan"), 5, 20], 10, 15, 25, 30)
        self.assertTrue(math.isnan(score[0]))
        self.assertEqual(score[1:].tolist(), [0, 100])
