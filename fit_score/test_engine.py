import unittest
from datetime import datetime, timezone
from .engine import score_animal
NOW=datetime(2026,11,10,tzinfo=timezone.utc)
def rd(v,d="2026-11-10T00:00:00+00:00"):
    return {"value":v,"observed_at":d}
P={"id":"test","name":"Test","group":"Shrimp","water_type":"freshwater","review_status":"unverified","ranges":{"temperature_c":[20,26],"ph":[6.5,8],"gh_dgh":[5,10],"kh_dkh":[2,7],"min_tank_gal":5}}
def tank():
    return {"volume_gal":10,"water_type":"freshwater","cycled":True,"compatibility_reviewed":True,"readings":{"temperature_c":rd(23),"ph":rd(7.2),"gh_dgh":rd(7),"kh_dkh":rd(4),"ammonia_mg_l":rd(0),"nitrite_mg_l":rd(0),"chlorine_mg_l":rd(0),"nitrate_mg_l":rd(5)}}
class EngineTests(unittest.TestCase):
    def test_unverified(self):
        self.assertEqual(score_animal(P,tank(),NOW)["status"],"provisional")
    def test_chlorine(self):
        t=tank();t["readings"]["chlorine_mg_l"]=rd(.01)
        r=score_animal(P,t,NOW);self.assertEqual((r["status"],r["fit_score"]),("do_not_add",0))
    def test_uncycled(self):
        t=tank();t["cycled"]=False
        self.assertEqual(score_animal(P,t,NOW)["status"],"do_not_add")
    def test_wrong_water(self):
        t=tank();t["water_type"]="marine"
        self.assertEqual(score_animal(P,t,NOW)["status"],"do_not_add")
    def test_stale(self):
        t=tank();t["readings"]["ph"]=rd(7.2,"2026-10-20T00:00:00+00:00")
        self.assertIn("ph",score_animal(P,t,NOW)["stale"])
    def test_missing_ammonia(self):
        t=tank();t["readings"].pop("ammonia_mg_l")
        self.assertIn("ammonia_mg_l",score_animal(P,t,NOW)["missing"])
    def test_small_tank(self):
        t=tank();t["volume_gal"]=2
        self.assertLessEqual(score_animal(P,t,NOW)["fit_score"],35)
