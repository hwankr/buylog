import unittest

from inventory_sync import (
    InventoryOwner,
    InventorySync,
    build_detected_item_records,
    match_detected_item,
    normalize_name,
    optional_float,
)


class FakeResponse:
    def __init__(self, data):
        self.data = data


class FakeTable:
    def __init__(self, name, db):
        self.name = name
        self.db = db
        self.operation = None
        self.payload = None
        self.filters = []
        self.select_value = None

    def select(self, value):
        self.select_value = value
        return self

    def eq(self, key, value):
        self.filters.append((key, value))
        return self

    def insert(self, payload):
        self.operation = "insert"
        self.payload = payload
        self.db.calls.append((self.name, "insert", payload))
        return self

    def upsert(self, payload, on_conflict=None):
        self.operation = "upsert"
        self.payload = payload
        self.db.calls.append((self.name, "upsert", payload, on_conflict))
        return self

    def execute(self):
        if self.name == "product_items" and self.operation is None:
            return FakeResponse(self.db.product_rows)
        if self.name == "inventory_observations":
            return FakeResponse([{"id": "observation-1", "observed_at": "2026-05-29T06:12:00Z"}])
        if self.name == "inventory_observation_items":
            rows = []
            for index, row in enumerate(self.payload):
                copied = dict(row)
                copied["id"] = f"observation-item-{index + 1}"
                rows.append(copied)
            return FakeResponse(rows)
        return FakeResponse([])


class FakeSupabase:
    def __init__(self):
        self.calls = []
        self.product_rows = [
            {
                "id": "item-1",
                "name": "Milk",
                "brand": "Seoul",
                "user_id": "user-1",
                "group_id": None,
            },
            {
                "id": "item-2",
                "name": "Water",
                "brand": "Samdasoo",
                "user_id": "user-1",
                "group_id": None,
            },
        ]

    def table(self, name):
        return FakeTable(name, self)


class InventorySyncTest(unittest.TestCase):
    def test_normalize_name_removes_spaces_case_and_punctuation(self):
        self.assertEqual(normalize_name("  Seoul Milk 1L "), "seoulmilk1l")
        self.assertEqual(normalize_name("Milk-1L!"), "milk1l")
        self.assertEqual(normalize_name(" 서울 우유! "), "서울우유")

    def test_optional_float_parses_blank_and_invalid_values_as_none(self):
        self.assertIsNone(optional_float(""))
        self.assertIsNone(optional_float(None))
        self.assertIsNone(optional_float("abc"))
        self.assertEqual(optional_float("12.5"), 12.5)

    def test_match_detected_item_prefers_exact_normalized_name(self):
        catalog = [
            {"id": "item-1", "name": "Milk", "brand": "Seoul"},
            {"id": "item-2", "name": "Water", "brand": "Samdasoo"},
        ]

        match = match_detected_item(
            detected_name="Milk",
            catalog=catalog,
            confidence=0.91,
            min_confidence=0.6,
            min_match_score=0.82,
        )

        self.assertEqual(match.status, "matched")
        self.assertEqual(match.product_item_id, "item-1")
        self.assertEqual(match.score, 1.0)

    def test_match_detected_item_rejects_low_confidence(self):
        match = match_detected_item(
            detected_name="Milk",
            catalog=[{"id": "item-1", "name": "Milk", "brand": "Seoul"}],
            confidence=0.4,
            min_confidence=0.6,
            min_match_score=0.82,
        )

        self.assertEqual(match.status, "low_confidence")
        self.assertIsNone(match.product_item_id)

    def test_build_detected_item_records_keeps_unmatched_items_for_audit(self):
        records = build_detected_item_records(
            items=[
                {"item_name": "Milk", "quantity": 2, "confidence": 0.91, "note": "two bottles"},
                {"item_name": "Unknown", "quantity": 1, "confidence": 0.2, "note": ""},
            ],
            catalog=[{"id": "item-1", "name": "Milk", "brand": "Seoul"}],
            min_confidence=0.6,
            min_match_score=0.82,
        )

        self.assertEqual(records[0]["product_item_id"], "item-1")
        self.assertEqual(records[0]["match_status"], "matched")
        self.assertIsNone(records[1]["product_item_id"])
        self.assertEqual(records[1]["match_status"], "low_confidence")

    def test_inventory_owner_requires_exactly_one_scope(self):
        with self.assertRaises(ValueError):
            InventoryOwner(user_id=None, group_id=None).to_observation_owner()
        with self.assertRaises(ValueError):
            InventoryOwner(user_id="user-1", group_id="group-1").to_observation_owner()
        self.assertEqual(
            InventoryOwner(user_id="user-1", group_id=None).to_observation_owner(),
            {"user_id": "user-1", "group_id": None},
        )

    def test_persist_analysis_inserts_observation_items_and_snapshot(self):
        fake = FakeSupabase()
        sync = InventorySync(
            db=fake,
            owner=InventoryOwner(user_id="user-1", group_id=None),
            min_confidence=0.6,
            min_match_score=0.82,
        )

        result = sync.persist_analysis(
            device_id="kitchen-cam-01",
            image_file="kitchen-cam-01_1.jpg",
            txt_file="kitchen-cam-01_1.txt",
            gpt_ok=True,
            analysis_result={
                "items": [
                    {
                        "item_name": "Milk",
                        "quantity": 2,
                        "confidence": 0.91,
                        "note": "two bottles",
                    }
                ],
                "summary": "Milk 2",
            },
            sensor_id="",
            weight_g=None,
            delta_g=None,
        )

        self.assertTrue(result["ok"])
        self.assertEqual(result["matched_count"], 1)
        snapshot_calls = [
            call
            for call in fake.calls
            if call[0] == "product_inventory_snapshots" and call[1] == "upsert"
        ]
        self.assertEqual(len(snapshot_calls), 1)
        self.assertEqual(snapshot_calls[0][2]["product_item_id"], "item-1")
        self.assertEqual(snapshot_calls[0][2]["remaining_quantity"], 2)


if __name__ == "__main__":
    unittest.main()
