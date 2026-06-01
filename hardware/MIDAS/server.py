from flask import Flask, request, jsonify, send_from_directory
from datetime import datetime
from dotenv import load_dotenv
from openai import OpenAI
from collections import Counter
import os
import json
import base64
import re
from inventory_sync import (
    InventorySync,
    make_client_from_env,
    optional_float,
    owner_from_env,
)

# ── 환경 변수 로드 ─────────────────────────────
load_dotenv()

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
OPENAI_MODEL = os.getenv("OPENAI_MODEL", "gpt-5.5")

if not OPENAI_API_KEY:
    raise RuntimeError("OPENAI_API_KEY가 설정되지 않았습니다. .env 파일을 확인하세요.")

client = OpenAI(api_key=OPENAI_API_KEY)
supabase_db = make_client_from_env()
inventory_owner = owner_from_env()

if supabase_db is None:
    print("[WARN] Supabase sync disabled: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing")
if inventory_owner is None:
    print("[WARN] Supabase sync disabled: BUYLOG_CAPTURE_USER_ID or BUYLOG_CAPTURE_GROUP_ID is missing")

app = Flask(__name__)

# ── 폴더 설정 ─────────────────────────────
UPLOAD_DIR = "uploads"
RESULT_DIR = "results"

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(RESULT_DIR, exist_ok=True)


# ── 이미지를 base64 data URL로 변환 ─────────
def image_to_data_url(image_path):
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    encoded = base64.b64encode(image_bytes).decode("utf-8")
    return f"data:image/jpeg;base64,{encoded}"


# ── GPT 응답에서 JSON만 추출 ─────────────────
def extract_json(text):
    """
    GPT가 혹시 ```json ... ``` 형태로 응답해도 JSON 부분만 파싱하기 위한 함수
    """
    text = text.strip()

    # ```json ... ``` 제거
    if text.startswith("```"):
        text = re.sub(r"^```json\s*", "", text)
        text = re.sub(r"^```\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # 본문 중 {...} 또는 [...] 부분만 추출 시도
    match = re.search(r"(\{.*\}|\[.*\])", text, re.DOTALL)
    if match:
        return json.loads(match.group(1))

    raise ValueError("GPT 응답에서 JSON을 파싱할 수 없습니다.")


# ── GPT Vision 객체 인식 함수 ─────────────────
def analyze_fridge_image_with_gpt(image_path):
    image_data_url = image_to_data_url(image_path)

    prompt = """
너는 재고 파악 시스템의 이미지 분석 모델이다.

이미지를 보고 창고 안에 보이는 물품을 분석해라.

목표:
- 물품 종류를 한국어로 출력
- 같은 물품은 개수를 합산
- 확실하지 않은 물체는 제외하거나 confidence를 낮게 설정
- 너무 세부적인 브랜드명보다 일반 물품명으로 정리
  예: 서울우유 → 우유, 삼다수 → 생수병, 코카콜라 → 탄산음료

반드시 아래 JSON 형식만 출력해라.
설명 문장, 마크다운, 코드블록은 출력하지 마라.

{
  "items": [
    {
      "item_name": "우유",
      "quantity": 1,
      "confidence": 0.85,
      "note": "우유팩으로 보임"
    }
  ],
  "summary": "냉장고 안에 우유 1개가 보임"
}

주의:
- quantity는 정수로 출력
- confidence는 0.0부터 1.0 사이 숫자
- 보이지 않는 물품은 추측하지 말 것
- 잘 모르겠으면 item_name을 '확인불가'로 하지 말고 제외할 것
"""

    response = client.responses.create(
        model=OPENAI_MODEL,
        input=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": prompt
                    },
                    {
                        "type": "input_image",
                        "image_url": image_data_url
                    }
                ]
            }
        ],
    )

    output_text = response.output_text
    parsed = extract_json(output_text)

    items = parsed.get("items", [])
    summary = parsed.get("summary", "")

    # 데이터 정리
    cleaned_items = []

    for item in items:
        item_name = str(item.get("item_name", "")).strip()
        if not item_name:
            continue

        try:
            quantity = int(item.get("quantity", 1))
        except Exception:
            quantity = 1

        try:
            confidence = float(item.get("confidence", 0.0))
        except Exception:
            confidence = 0.0

        note = str(item.get("note", "")).strip()

        cleaned_items.append({
            "item_name": item_name,
            "quantity": max(quantity, 1),
            "confidence": max(0.0, min(confidence, 1.0)),
            "note": note
        })

    return {
        "items": cleaned_items,
        "summary": summary,
        "raw_text": output_text
    }


# ── txt 저장 함수 ─────────────────────────
def save_gpt_result_txt(txt_path, image_filename, analysis_result):
    items = analysis_result.get("items", [])
    summary = analysis_result.get("summary", "")

    with open(txt_path, "w", encoding="utf-8") as f:
        f.write("GPT API 냉장고 객체 인식 결과\n")
        f.write("====================================\n")
        f.write(f"이미지 파일: {image_filename}\n")
        f.write(f"분석 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("\n")

        f.write("[요약]\n")
        if summary:
            f.write(summary + "\n")
        else:
            f.write("요약 없음\n")

        f.write("\n")
        f.write("[검출된 물품]\n")

        if not items:
            f.write("검출된 물품 없음\n")
        else:
            for item in items:
                f.write(
                    f"- {item['item_name']}: "
                    f"{item['quantity']}개 "
                    f"(신뢰도: {item['confidence']:.2f})"
                )

                if item.get("note"):
                    f.write(f" / 비고: {item['note']}")

                f.write("\n")

        f.write("\n")
        f.write("[JSON 원본]\n")
        f.write(json.dumps(analysis_result, ensure_ascii=False, indent=2))


# ── 메인 페이지 ─────────────────────────
@app.route("/")
def index():
    image_files = sorted(
        [f for f in os.listdir(UPLOAD_DIR) if f.lower().endswith(".jpg")],
        reverse=True
    )

    html = """
    <!DOCTYPE html>
    <html lang="ko">
    <head>
        <meta charset="UTF-8">
        <title>ESP32 냉장고 GPT 인식 서버</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background: #111827;
                color: white;
                padding: 20px;
            }
            h1 {
                color: #60a5fa;
            }
            .card {
                background: #1f2937;
                padding: 16px;
                margin-bottom: 16px;
                border-radius: 12px;
            }
            img {
                width: 320px;
                max-width: 100%;
                border-radius: 8px;
                display: block;
                margin-bottom: 10px;
            }
            a {
                color: #93c5fd;
                text-decoration: none;
                margin-right: 12px;
            }
            .empty {
                color: #d1d5db;
            }
        </style>
    </head>
    <body>
        <h1>ESP32 냉장고 GPT 인식 서버</h1>
    """

    if not image_files:
        html += "<p class='empty'>아직 업로드된 이미지가 없습니다.</p>"

    for image_file in image_files:
        txt_file = image_file.replace(".jpg", ".txt")

        html += f"""
        <div class="card">
            <h2>{image_file}</h2>
            <img src="/uploads/{image_file}">
            <a href="/uploads/{image_file}" target="_blank">이미지 보기</a>
            <a href="/results/{txt_file}" target="_blank">GPT 인식 결과 txt 보기</a>
        </div>
        """

    html += """
    </body>
    </html>
    """

    return html


def persist_inventory_upload(
    *,
    device_id,
    image_filename,
    txt_filename,
    gpt_ok,
    analysis_result,
    sensor_id,
    weight_g,
    delta_g,
):
    if supabase_db is None or inventory_owner is None:
        return {
            "ok": False,
            "skipped": True,
            "error": "Supabase inventory sync is not configured",
        }

    sync = InventorySync(db=supabase_db, owner=inventory_owner)
    return sync.persist_analysis(
        device_id=device_id,
        image_file=image_filename,
        txt_file=txt_filename,
        gpt_ok=gpt_ok,
        analysis_result=analysis_result,
        sensor_id=sensor_id,
        weight_g=optional_float(weight_g),
        delta_g=optional_float(delta_g),
    )


# ── ESP32 이미지 업로드 엔드포인트 ─────────
@app.route("/upload", methods=["POST"])
def upload():
    image_data = request.data

    if not image_data:
        return jsonify({
            "ok": False,
            "error": "No image data received"
        }), 400

    device_id = request.headers.get("X-Device-Id", "fridge_cam_01")
    photo_count = request.headers.get("X-Photo-Count", "0")

    # ESP-NOW 무게 이벤트 정보를 나중에 같이 보낼 경우 대비
    sensor_id = request.headers.get("X-Sensor-Id", "")
    weight_g = request.headers.get("X-Weight-G", "")
    delta_g = request.headers.get("X-Delta-G", "")

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    image_filename = f"{device_id}_{timestamp}_{photo_count}.jpg"
    txt_filename = f"{device_id}_{timestamp}_{photo_count}.txt"

    image_path = os.path.join(UPLOAD_DIR, image_filename)
    txt_path = os.path.join(RESULT_DIR, txt_filename)

    # 1. 이미지 저장
    with open(image_path, "wb") as f:
        f.write(image_data)

    print(f"[OK] 이미지 수신: {image_filename}")
    print(f"     크기: {len(image_data) / 1024:.1f} KB")

    # 2. GPT API로 이미지 분석
    try:
        analysis_result = analyze_fridge_image_with_gpt(image_path)
        gpt_ok = True
        print("[OK] GPT 이미지 분석 완료")

    except Exception as e:
        gpt_ok = False
        analysis_result = {
            "items": [],
            "summary": "GPT 이미지 분석 실패",
            "error": str(e)
        }
        print(f"[FAIL] GPT 이미지 분석 실패: {e}")

    # 3. txt 저장
    save_gpt_result_txt(
        txt_path=txt_path,
        image_filename=image_filename,
        analysis_result=analysis_result
    )

    print(f"[OK] txt 저장: {txt_filename}")

    try:
        inventory_sync_result = persist_inventory_upload(
            device_id=device_id,
            image_filename=image_filename,
            txt_filename=txt_filename,
            gpt_ok=gpt_ok,
            analysis_result=analysis_result,
            sensor_id=sensor_id,
            weight_g=weight_g,
            delta_g=delta_g,
        )
        if inventory_sync_result.get("ok"):
            print(
                "[OK] Supabase inventory sync: "
                f"{inventory_sync_result.get('matched_count', 0)} matched"
            )
        else:
            print(f"[WARN] Supabase inventory sync skipped: {inventory_sync_result.get('error')}")
    except Exception as e:
        inventory_sync_result = {"ok": False, "skipped": False, "error": str(e)}
        print(f"[FAIL] Supabase inventory sync failed: {e}")

    # 4. 응답
    return jsonify({
        "ok": True,
        "gpt_ok": gpt_ok,
        "image_file": image_filename,
        "txt_file": txt_filename,
        "device_id": device_id,
        "sensor_id": sensor_id,
        "weight_g": weight_g,
        "delta_g": delta_g,
        "items": analysis_result.get("items", []),
        "summary": analysis_result.get("summary", ""),
        "supabase_ok": bool(inventory_sync_result.get("ok")),
        "inventory_sync": inventory_sync_result,
    })


# ── 이미지 파일 제공 ─────────────────────
@app.route("/uploads/<filename>")
def uploaded_file(filename):
    return send_from_directory(UPLOAD_DIR, filename)


# ── txt 결과 파일 제공 ───────────────────
@app.route("/results/<filename>")
def result_file(filename):
    return send_from_directory(RESULT_DIR, filename)


# ── 서버 실행 ───────────────────────────
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
