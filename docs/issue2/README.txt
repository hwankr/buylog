══════════════════════════════════════════════════════════
  Buylog Issue2 — OCR 파싱 개선 & 웹 카메라 연동
══════════════════════════════════════════════════════════

─────────────────────────────────────────────────────────
  구현 내용 요약
─────────────────────────────────────────────────────────

① Gemini 2.5 Flash 멀티모달 OCR
   - 영수증 이미지를 Gemini에 직접 전송해 상품 목록을
     JSON으로 한 번에 추출 (기존 Regex 방식 대체)
   - responseSchema 강제로 파싱 구조 보장
   - 관련 파일: lib/services/ocr_service.dart

② 3단계 Fallback 체계
   - ① Gemini 멀티모달 → ② Google Vision + Gemini 텍스트 파싱
     → ③ Regex 파싱 순으로 단계적 처리
   - 관련 파일: lib/services/ocr_service.dart

③ 웹 카메라 직접 연동
   - Flutter Web에서 image_picker 대신 getUserMedia API 사용
   - 실시간 카메라 미리보기 → 촬영 → OCR 처리
   - 권한 거부 시 파일 선택기 fallback 내장
   - 관련 파일: lib/services/camera_picker_web.dart
                lib/services/camera_picker.dart (조건부 export)
                lib/services/camera_picker_stub.dart (non-web)

─────────────────────────────────────────────────────────
  Before / After
─────────────────────────────────────────────────────────

  항목         Before (Regex)     After (Gemini)
  ──────────   ───────────────    ──────────────
  매장명       "날짜" 오탐         정확히 추출
  상품 인식    0~2개              전량 (5/5개)
  날짜 파싱    null (형식 다양)    정규화 후 파싱
  카메라       갤러리만 열림       실시간 미리보기

─────────────────────────────────────────────────────────
  관련 파일 목록
─────────────────────────────────────────────────────────

  docs/issue2/
    발표자료-issue2.pdf     발표용 PDF (8페이지)
    발표자료-issue2.html    발표용 HTML 원본
    README.txt              이 파일

  lib/services/
    ocr_service.dart        OCR 메인 서비스 (Gemini + Fallback)
    camera_picker.dart      플랫폼 조건부 export
    camera_picker_web.dart  웹 카메라 구현 (getUserMedia)
    camera_picker_stub.dart 모바일용 stub

  lib/screens/
    scan_screen.dart        OCR 스캔 화면

─────────────────────────────────────────────────────────
  사용 API
─────────────────────────────────────────────────────────

  · Gemini 2.5 Flash     — OCR 메인 엔진 (무료 티어 포함)
  · Google Cloud Vision  — OCR Fallback (텍스트 추출)
  · getUserMedia (Web)   — 브라우저 카메라 API

══════════════════════════════════════════════════════════
