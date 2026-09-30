import copy
from datetime import datetime, timezone
import unittest
from motionstudies_exporter import render

NOW = 1800000000

def iso(seconds):
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat()

def fixture():
    return {"schemaVersion": 1, "kind": "feed-observer-status", "state": "healthy",
            "assessedAt": iso(NOW), "failedAt": None,
            "lastCheck": {"completedAt": iso(NOW-10), "sourceError": None,
                          "report": {"producerGeneratedAt": iso(NOW-20), "telemetry": {"state": "current"},
                                     "feeds": [{"feedId": "bus", "configuredState": "active", "state": "healthy"}]}}}

class ExporterTests(unittest.TestCase):
    def test_current_and_degraded_reports(self):
        value = fixture()
        self.assertIn('motionstudies_feed_state{feed="bus"} 0', render(value, NOW))
        value["state"] = "degraded"
        value["lastCheck"]["report"]["feeds"][0]["state"] = "degraded"
        self.assertIn('motionstudies_feed_state{feed="bus"} 2', render(value, NOW))
        self.assertIn('motionstudies_observer_state 2', render(value, NOW))
    def test_stale_future_failed_and_unknown_never_green(self):
        original = fixture()
        mutations = [lambda x: x.update(assessedAt=iso(NOW-181)),
                     lambda x: x["lastCheck"].update(completedAt=iso(NOW-181)),
                     lambda x: x["lastCheck"]["report"].update(producerGeneratedAt=iso(NOW+31)),
                     lambda x: x.update(failedAt=iso(NOW)),
                     lambda x: x.update(state="unknown")]
        for mutate in mutations:
            value = copy.deepcopy(original)
            mutate(value)
            self.assertIn('motionstudies_feed_state{feed="bus"} 4', render(value, NOW))
        self.assertIn('motionstudies_feed_state{feed="bus"} 4', render(original, NOW+200))
    def test_no_payload_or_credential_in_metrics(self):
        value = fixture()
        value["secret"] = "do-not-emit"
        value["lastCheck"]["report"]["feeds"][0]["error"] = "do-not-emit"
        self.assertNotIn("do-not-emit", render(value, NOW))
        value["lastCheck"]["report"]["feeds"][0]["feedId"] = 'bad"\nname'
        with self.assertRaises(ValueError):
            render(value, NOW)
    def test_duplicates_and_unavailable_check(self):
        value = fixture()
        value["lastCheck"]["report"]["feeds"] *= 2
        with self.assertRaises(ValueError): render(value, NOW)
        value["lastCheck"] = None
        self.assertIn("motionstudies_observer_state 4", render(value, NOW))

if __name__ == "__main__": unittest.main()
