# Issue3 브랜치 개발 내역

> **브랜치**: `issue3`
> **작업 범위**: Firebase 제거 → Supabase 실연동 + 이미지 업로드/표시 기능 구현

---

## 목차

1. [개요](#개요)
2. [주요 변경 사항](#주요-변경-사항)
3. [아키텍처](#아키텍처)
4. [기능별 상세 설명](#기능별-상세-설명)
5. [로컬 실행 방법](#로컬-실행-방법)
6. [Supabase 프로젝트 정보](#supabase-프로젝트-정보)

---

## 개요

기존에 Firebase 연동 준비용 Stub 코드로 작성되어 있던 서비스 레이어를 **Supabase 실연동**으로 교체하고, 이와 함께 **제품 이미지 업로드 및 표시** 기능을 구현했습니다.

### 커밋 목록

| 커밋 | 내용 |
|------|------|
| `63ef2c5` | 제품 수동 등록 및 반응형 UI 구현 |
| `0fc674c` | Firebase Stub → Supabase 실연동 교체 |
| `883b701` | 인증 방식 변경: 익명 로그인 대신 RLS 비활성 모드로 전환 |
| `5003cd6` | 제품 이미지 업로드 기능 추가 (image_picker + Supabase Storage) |
| `ee5f542` | 아이템 세부 화면 이미지 표시 구현 |

---

## 주요 변경 사항

### 삭제된 파일
- `lib/services/firebase_service.dart` — Firebase Stub 코드 전면 제거

### 신규 파일
- `lib/services/supabase_service.dart` — Supabase 실연동 서비스

### 수정된 파일
- `lib/main.dart` — Supabase 초기화 로직 추가
- `lib/models/item.dart` — `fromSupabase()` 팩토리 메서드 추가, `PurchaseRecord`에 `id` 필드 추가
- `lib/services/item_store.dart` — 비동기 CRUD (Supabase 동기화)
- `lib/screens/add_item_screen.dart` — 이미지 선택 및 업로드 UI
- `lib/screens/item_detail_screen.dart` — 이미지 배너 표시
- `pubspec.yaml` — 패키지 추가: `supabase_flutter`, `image_picker`

---

## 아키텍처

```
앱 시작 (main.dart)
  └─ SupabaseService.initialize()   // Supabase 클라이언트 초기화
  └─ ItemStore.instance.initialize() // DB에서 제품 목록 로드
  └─ runApp()

데이터 흐름
  ItemStore (ValueNotifier<List<ConsumableItem>>)
    ├─ loadItems()   ← Supabase DB (product_items, purchases, categories, ai_predictions)
    ├─ add()         → Supabase DB upsert
    ├─ update()      → Supabase DB upsert
    └─ delete()      → Supabase DB delete (CASCADE로 purchases 자동 삭제)

이미지 흐름
  사용자가 갤러리에서 이미지 선택 (image_picker)
    └─ Uint8List 형태로 메모리에 보관
    └─ 제품 저장 시 → SupabaseService.uploadItemImage()
         └─ _adminClient (service role key) → Storage 업로드
         └─ 공개 URL 반환 → product_items.image_url 에 저장
```

### 두 개의 Supabase 클라이언트

| 클라이언트 | 키 종류 | 용도 |
|-----------|---------|------|
| `_db` (Supabase.instance.client) | anon key | DB CRUD (RLS 비활성이므로 사용 가능) |
| `_adminClient` | service role key | Storage 업로드 (anon key로는 403 발생) |

> **보안 주의**: service role key는 `--dart-define=SUPABASE_SERVICE_KEY=...` 로 주입하며, 소스코드에 직접 커밋하지 않습니다.

---

## 기능별 상세 설명

### 1. Supabase DB 연동 (`supabase_service.dart`)

#### 연결 정보
- **프로젝트 ID**: `fervijwxdgkwjtcpzskx`
- **URL**: `https://fervijwxdgkwjtcpzskx.supabase.co`

#### 사용 테이블

| 테이블 | 역할 |
|--------|------|
| `product_items` | 제품 기본 정보 (name, brand, image_url, replacement_cycle_days 등) |
| `purchases` | 구매 이력 (purchase_date, price, store_name) |
| `categories` | 카테고리 (name, icon, color) |
| `ai_predictions` | AI 교체 주기 예측 (predicted_cycle_days, confidence) |

#### 주요 메서드

```dart
// 전체 제품 로드 (JOIN 쿼리로 한 번에 가져옴)
static Future<List<ConsumableItem>> loadItems()

// 제품 저장 (신규 / 수정 모두 처리)
static Future<void> saveItem(ConsumableItem item)

// 제품 삭제 (purchases는 DB CASCADE로 자동 삭제)
static Future<void> deleteItem(String itemId)

// UUID v4 생성 (dart:math 사용, 외부 패키지 불필요)
static String generateUuid()
```

#### 인증 방식
익명 로그인이 Supabase 프로젝트에서 비활성화되어 있어, **RLS(Row Level Security)가 비활성 상태**인 점을 활용하여 개발용 고정 `user_id`를 사용합니다.

```dart
static const _devUserId = '08cccfe3-766f-43bd-b06c-8d909e0f9fe8';
```

> 프로덕션 전환 시 실제 인증 및 RLS 정책 적용 필요.

---

### 2. 카테고리 자동 생성

`_ensureCategory(String name)` 메서드가 카테고리 이름으로 UUID를 조회하고, 없으면 자동 생성합니다. 앱 세션 동안 결과를 캐싱하여 불필요한 DB 조회를 방지합니다.

```dart
static final Map<String, String> _categoryCache = {};
```

---

### 3. 이미지 업로드 (`add_item_screen.dart`)

#### 흐름

1. 사용자가 이미지 영역을 탭
2. `image_picker`로 갤러리에서 이미지 선택 (최대 1024×1024, 품질 85%)
3. `Uint8List`로 메모리에 로드 → 미리보기 표시 (`Image.memory`)
4. "저장" 버튼 클릭 시 `SupabaseService.uploadItemImage()` 호출
5. 반환된 공개 URL을 `ConsumableItem.imageUrl`에 저장

#### 이미지 선택 상태 관리

```dart
Uint8List? _imageBytes; // 새로 선택한 이미지 바이트

// 이미지가 선택된 상태인지 (신규 선택 또는 기존 URL 존재)
bool get _hasImageSelected =>
    _imageBytes != null || (_isEditing && widget.editItem!.imageUrl != null);
```

#### Storage 버킷
- **버킷명**: `product-images`
- **공개 여부**: Public (별도 인증 없이 URL로 접근 가능)
- **저장 경로**: `items/{itemId}.jpg`

---

### 4. 이미지 표시 (`item_detail_screen.dart`)

세부 화면 상단의 제품 헤더 카드에 이미지 유무에 따라 다른 레이아웃을 적용합니다.

#### 이미지 있을 때
```
┌──────────────────────────────────┐
│                                  │
│     220px 전체 너비 이미지 배너    │
│                                  │
├──────────────────────────────────┤
│  [카테고리 태그]                   │
│  제품명                  [D-day   │
│  브랜드명                  링]    │
└──────────────────────────────────┘
```

#### 이미지 없을 때
```
┌──────────────────────────────────┐
│  [아이콘]  [카테고리 태그]          │
│            제품명       [D-day    │
│            브랜드명       링]     │
└──────────────────────────────────┘
```

- 로딩 중: `CircularProgressIndicator` 표시
- 로드 실패: `broken_image` 아이콘 표시

---

### 5. 반응형 상태 관리 (`item_store.dart`)

`ItemStore`는 `ValueNotifier<List<ConsumableItem>>`를 상속하여, 데이터 변경 시 모든 리스너(화면)에 자동으로 알립니다.

```dart
// 낙관적 업데이트: 로컬 상태를 먼저 반영 후 DB 동기화
Future<void> add(ConsumableItem item) async {
  value = [item, ...value]; // UI 즉시 반영
  await SupabaseService.saveItem(item); // DB 저장
}
```

---

## 로컬 실행 방법

### 1. 패키지 설치
```bash
flutter pub get
```

### 2. 앱 실행 (service role key 주입 필수)
```bash
flutter run -d chrome --web-port 3000 \
  --dart-define=SUPABASE_SERVICE_KEY=<서비스_롤_키>
```

> 서비스 롤 키는 팀 노션 또는 팀장에게 문의하세요.

### 3. 이미지 업로드 없이 실행할 경우
```bash
flutter run -d chrome --web-port 3000
```
이미지 업로드 시 오류가 발생하지만 나머지 기능은 정상 동작합니다.

---

## Supabase 프로젝트 정보

| 항목 | 값 |
|------|-----|
| 프로젝트 ID | `fervijwxdgkwjtcpzskx` |
| 대시보드 | https://supabase.com/dashboard/project/fervijwxdgkwjtcpzskx |
| Storage 버킷 | `product-images` (public) |
| RLS 상태 | 전체 테이블 비활성 (개발 환경) |
| anon key | `sb_publishable_FO7WmA_Pu4RsGgsfRJzssQ_f0orCu7w` |
| service role key | 별도 보관 (소스코드 미포함) |
