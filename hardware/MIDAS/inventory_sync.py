from dataclasses import dataclass
from difflib import SequenceMatcher
from typing import Any
import os
import re

try:
    from supabase import create_client
except ImportError:
    create_client = None


@dataclass(frozen=True)
class InventoryOwner:
    user_id: str | None
    group_id: str | None

    def to_observation_owner(self) -> dict[str, str | None]:
        if bool(self.user_id) == bool(self.group_id):
            raise ValueError("Exactly one of user_id or group_id is required.")
        return {"user_id": self.user_id, "group_id": self.group_id}


@dataclass(frozen=True)
class ItemMatch:
    product_item_id: str | None
    status: str
    score: float | None


def normalize_name(value: str) -> str:
    normalized = re.sub(r"\s+", "", value.strip().lower())
    return re.sub(r"[^0-9a-z가-힣]", "", normalized)


def optional_float(value: str | None) -> float | None:
    if value is None or str(value).strip() == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def make_client_from_env():
    url = os.getenv("SUPABASE_URL")
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    if not url or not key:
        return None
    if create_client is None:
        raise RuntimeError("Install the supabase package before enabling inventory sync.")
    return create_client(url, key)


def owner_from_env() -> InventoryOwner | None:
    user_id = (os.getenv("BUYLOG_CAPTURE_USER_ID") or "").strip() or None
    group_id = (os.getenv("BUYLOG_CAPTURE_GROUP_ID") or "").strip() or None
    if not user_id and not group_id:
        return None
    return InventoryOwner(user_id=user_id, group_id=group_id)


def _safe_int(value: Any) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _safe_confidence(value: Any) -> float:
    try:
        confidence = float(value)
    except (TypeError, ValueError):
        confidence = 0.0
    return max(0.0, min(confidence, 1.0))


def _match_score(detected: str, candidate: str) -> float:
    if not detected or not candidate:
        return 0.0
    if detected == candidate:
        return 1.0
    if detected in candidate or candidate in detected:
        shorter = min(len(detected), len(candidate))
        longer = max(len(detected), len(candidate))
        return max(0.9, shorter / longer)
    return SequenceMatcher(None, detected, candidate).ratio()


def match_detected_item(
    *,
    detected_name: str,
    catalog: list[dict[str, Any]],
    confidence: float,
    min_confidence: float,
    min_match_score: float,
) -> ItemMatch:
    if confidence < min_confidence:
        return ItemMatch(product_item_id=None, status="low_confidence", score=None)

    detected = normalize_name(detected_name)
    if not detected:
        return ItemMatch(product_item_id=None, status="unmatched", score=None)

    scored: list[tuple[float, dict[str, Any]]] = []
    for product in catalog:
        candidates = [
            normalize_name(str(product.get("name") or "")),
            normalize_name(f"{product.get('brand') or ''}{product.get('name') or ''}"),
        ]
        best_score = max((_match_score(detected, candidate) for candidate in candidates), default=0.0)
        scored.append((best_score, product))

    if not scored:
        return ItemMatch(product_item_id=None, status="unmatched", score=None)

    scored.sort(key=lambda entry: entry[0], reverse=True)
    top_score, top_product = scored[0]
    second_score = scored[1][0] if len(scored) > 1 else 0.0

    if top_score < min_match_score:
        return ItemMatch(product_item_id=None, status="unmatched", score=top_score)
    if second_score >= min_match_score and (top_score - second_score) < 0.05:
        return ItemMatch(product_item_id=None, status="ambiguous", score=top_score)

    return ItemMatch(
        product_item_id=str(top_product["id"]),
        status="matched",
        score=top_score,
    )


def build_detected_item_records(
    *,
    items: list[dict[str, Any]],
    catalog: list[dict[str, Any]],
    min_confidence: float,
    min_match_score: float,
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for item in items:
        detected_name = str(item.get("item_name") or "").strip()
        if not detected_name:
            continue

        quantity = max(_safe_int(item.get("quantity")), 0)
        confidence = _safe_confidence(item.get("confidence"))
        match = match_detected_item(
            detected_name=detected_name,
            catalog=catalog,
            confidence=confidence,
            min_confidence=min_confidence,
            min_match_score=min_match_score,
        )

        records.append(
            {
                "product_item_id": match.product_item_id,
                "detected_name": detected_name,
                "normalized_name": normalize_name(detected_name),
                "quantity": quantity,
                "confidence": confidence,
                "note": str(item.get("note") or "").strip() or None,
                "match_status": match.status,
                "match_score": match.score,
            }
        )
    return records


class InventorySync:
    def __init__(
        self,
        *,
        db,
        owner: InventoryOwner,
        min_confidence: float = 0.6,
        min_match_score: float = 0.82,
    ):
        self.db = db
        self.owner = owner
        self.min_confidence = min_confidence
        self.min_match_score = min_match_score

    def load_catalog(self) -> list[dict[str, Any]]:
        query = self.db.table("product_items").select("id,name,brand,user_id,group_id")
        if self.owner.group_id:
            query = query.eq("group_id", self.owner.group_id)
        else:
            query = query.eq("user_id", self.owner.user_id)
        response = query.execute()
        return list(response.data or [])

    def persist_analysis(
        self,
        *,
        device_id: str,
        image_file: str,
        txt_file: str,
        gpt_ok: bool,
        analysis_result: dict[str, Any],
        sensor_id: str | None,
        weight_g: float | None,
        delta_g: float | None,
    ) -> dict[str, Any]:
        observation_payload = {
            **self.owner.to_observation_owner(),
            "device_id": device_id,
            "image_file": image_file,
            "txt_file": txt_file,
            "summary": analysis_result.get("summary") or "",
            "raw_result": analysis_result,
            "gpt_ok": gpt_ok,
            "sensor_id": sensor_id or None,
            "weight_g": weight_g,
            "delta_g": delta_g,
        }

        observation_rows = (
            self.db.table("inventory_observations")
            .insert(observation_payload)
            .select("id,observed_at")
            .execute()
        ).data
        observation = observation_rows[0]

        item_records = build_detected_item_records(
            items=list(analysis_result.get("items") or []),
            catalog=self.load_catalog(),
            min_confidence=self.min_confidence,
            min_match_score=self.min_match_score,
        )

        inserted_items = []
        if item_records:
            item_payload = [
                {"observation_id": observation["id"], **record}
                for record in item_records
            ]
            inserted_items = (
                self.db.table("inventory_observation_items")
                .insert(item_payload)
                .select(
                    "id,product_item_id,detected_name,quantity,confidence,match_status"
                )
                .execute()
            ).data or []

        matched_count = 0
        for row in inserted_items:
            if row.get("match_status") != "matched" or not row.get("product_item_id"):
                continue

            matched_count += 1
            self.db.table("product_inventory_snapshots").upsert(
                {
                    "product_item_id": row["product_item_id"],
                    "observation_item_id": row["id"],
                    "remaining_quantity": row["quantity"],
                    "confidence": row["confidence"],
                    "source_detected_name": row["detected_name"],
                    "observed_at": observation["observed_at"],
                },
                on_conflict="product_item_id",
            ).execute()

        return {
            "ok": True,
            "observation_id": observation["id"],
            "detected_count": len(item_records),
            "matched_count": matched_count,
        }
