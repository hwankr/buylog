# buylog UI 리디자인 (2026-05) 변경 노트

> 작성: 전승환 / 검토 대상: 팀원 4명 / 적용 브랜치: `ui-test`
> 디자인 원본: `.design-handoff/project/prototype.html` (Claude Design 핸드오프)

본인 담당 화면의 영향 범위가 궁금하다면 아래 해당 항목을 먼저 확인해주세요. 되돌리고 싶은 결정이 있다면 PR 코멘트로 토론합시다.

---

## 한눈에 보기

따뜻한 뉴트럴 톤(아이보리 + 테라코타 + 세이지 모스)으로 비주얼 통일 + 홈 화면 정보 위계 재정리 + 하단 탭 `스캔` 자리를 `모든 제품`으로 교체.

| # | 변경 | 영향 |
| --- | --- | --- |
| 1 | 하단 탭 `스캔` → `모든 제품` | 탭 IA 변경, 스캔은 FAB 액션 시트로 |
| 2 | 홈 화면 구조 재편 | 무한 스크롤 → 큐레이팅 다이제스트 |
| 3 | 테마 팔레트: 쿨 teal → 따뜻한 뉴트럴 | 모든 화면 자동 적용 (토큰 경유) |
| 4 | 새 위젯 분리 (`lib/widgets/home/`) | 팀원 위젯 보존 |
| 5 | 새 화면 `모든 제품` | 전체 품목 리스트 + 필터 |
| 6 | `ItemStore` 롤백 | Supabase 실패 시 ghost item 방지 |
| 7 | 탭 라벨 `내 아이템` → `홈` | 의미상 정합성 |
| 8 | `docs/REDESIGN_NOTES.md` | 이 문서 |

> 팀원 작성 코드(`group_screen`, `reports_screen`, `settings_screen`, `add_item_screen`, `widgets/item_card`, `widgets/dday_badge`, `widgets/countdown_ring`, `widgets/reports/*`)는 **한 줄도 수정하지 않았다.** 색/카드/링 비주얼이 달라 보이는 것은 토큰 값만 바뀐 결과.

> **주의:** 본 PR은 여러 커밋에 나눠 적용됩니다. 이 문서는 PR이 모두 머지된 시점의 최종 상태를 기준입니다. 중간 커밋을 fetch한 시점에는 일부 변경이 아직 반영되지 않았을 수 있습니다.

---

## 세부 사항

### 1. 하단 탭: `스캔` → `모든 제품`

- **이유**: 스캔 기능 진입 빈도가 낮아 탭 슬롯을 차지하기엔 비효율. 전체 제품 리스트 조회가 더 잦은 동작.
- **변경 위치**: `lib/main.dart` 의 `_tabs`, `_screenAt`
- **변경 내용**:
  - `BottomNavigationBar`에서 `ScanScreen` 자리에 `ItemsScreen` 노출
  - 스캔 진입은 FAB 누르면 뜨는 액션 시트(카메라 스캔 / 직접 등록)로 이동
  - `ScanScreen` 코드 자체는 한 줄도 안 건드림

### 2. 홈 화면 구조 재편

- **이유**: 기존 홈은 무한 스크롤로 전체 품목을 보여줘 정보 위계가 평평했음. "오늘 챙겨야 할 것"에 집중하는 다이제스트로 재정리.
- **변경 위치**: `lib/screens/home_screen.dart`
- **변경 내용**:
  - 자체 `_supabase.from('product_items')` 페이지네이션 + `ScrollController` + `_isMoreLoading` 로직 제거
  - `ValueListenableBuilder<ItemStore>` 구독으로 교체 → AddItem/Detail 결과가 즉시 홈에 반영
  - 빌드 트리: 인사말 → 히어로 카드(가장 시급, 카운트다운 링) → AI 인사이트 → 다가오는 교체 4건 → 최근 기록
  - 전체 품목 리스트는 `모든 제품` 탭이 담당

### 3. 테마 팔레트: 쿨 teal → 따뜻한 뉴트럴

- **이유**: 디자인 핸드오프가 따뜻한 톤(아이보리·테라코타·세이지). 식별자를 그대로 두면 팀원 코드 한 줄도 안 건드리고 자동 적용 가능.
- **변경 위치**: `lib/theme/app_theme.dart`
- **변경 내용**:
  - `AppColors` 19개 토큰의 *값*만 교체. *이름*은 유지 (`primary`, `background`, `success` 등)
  - `primary`: cyan `#0891B2` → terracotta `#C25A4A`
  - `background`: 쿨 그레이 `#F7F6F3` → 아이보리 `#F7F2E9`
  - D-day 4-tier 시각 구분 보존 위해 `danger`(`#B0392E`)와 `dangerLight`(`#EFC5B6`)는 `primary`/`primaryLight2`와 의도적으로 분리
- **메모**: `primary`라는 이름이 더 이상 cyan이 아니라 terracotta가 된 점이 약간의 인지 부조화는 있지만, 이름을 바꾸면 모든 호출부를 건드려야 해서 비용 대비 손실이 더 컸음.

### 4. 새 위젯 분리

- **이유**: 디자인 신규 컴포넌트를 팀원 위젯에 끼워넣지 않고 별도 파일로 두면 PR diff에서 "새 파일이구나"로 즉시 인식됨.
- **변경 위치**: `lib/widgets/home/` (신규 디렉토리)
- **추가된 파일**:
  - `home_hero_card.dart`: 카운트다운 링 + "가장 시급" 핀 + AI 예측% + 자세히/주문 버튼
  - `upcoming_item_row.dart`: 36 px 아이콘 + 이름·주기 + D-day 배지의 컴팩트 행

### 5. 새 화면 `모든 제품`

- **이유**: 홈에서 빠진 전체 품목 리스트를 담을 곳이 필요. 필터 칩(전체/긴급/곧/여유)으로 정보 정리.
- **변경 위치**: `lib/screens/items_screen.dart` (신규)
- **변경 내용**:
  - `ItemStore` 구독으로 전체 제품 표시
  - 필터 칩 + 정렬(D-day 오름차순)
  - 홈의 "모두 보기"에서 진입 가능

### 6. `ItemStore` 롤백 + 에러 처리

- **이유**: 기존 optimistic update가 Supabase 실패 시 롤백 없이 ghost item을 화면에 남겼음.
- **변경 위치**: `lib/services/item_store.dart`, `lib/screens/item_detail_screen.dart`
- **변경 내용**:
  - `ItemStore.add/update/delete` 진입 시 이전 `value` 스냅샷 보관, Supabase 실패 catch에서 복원 후 rethrow
  - `ItemDetailScreen._confirmDelete`에 try/catch + `SnackBar('삭제 실패...')` 추가 (rethrow 후속 처리)
  - 회귀 보호용 단위 테스트 3건 신규 (`test/services/item_store_test.dart`)

### 7. 탭 라벨: `내 아이템` → `홈`

- **이유**: 첫 탭이 더 이상 "내 아이템 리스트"가 아닌 다이제스트라서 의미상 맞지 않음.
- **변경 위치**: `lib/main.dart` 의 `_tabs[0]`, `test/widget_test.dart`
- **변경 내용**: 라벨 문자열 + 위젯 테스트 검증 라벨 갱신

### 8. 변경 사유 문서화

- **이유**: 팀원 4명이 합쳐 작성한 코드 위에 진행되는 PR이라, 어디를 왜 건드렸는지 한눈에 보이게.
- **변경 위치**: `docs/REDESIGN_NOTES.md` (신규, 이 문서)

---

## 알려진 시각적 한계 (후속 폴리시 후보)

리디자인 적용 후에도 남는 자잘한 시각 이슈. 본 PR 범위에서는 의도적으로 손대지 않음.

- **D-day 배지 텍스트 대비**: warm 팔레트의 status fg/bg 페어(`success/successLight`, `warning/warningLight`, `primary/primaryLight2`)는 12 px 굵은 글자에서 WCAG AA(4.5:1)에 미달. 디자인 핸드오프의 의도적 선택을 따름. 접근성 보강이 필요해지면 fg 토큰을 한 단계 어둡게 하거나 별도 `onPrimary/onSuccess` 토큰을 도입하는 follow-up.
- **`lib/widgets/reports/category_pie_chart.dart` 카테고리 색**: 파일 내부에 cool 톤 hex가 하드코딩되어 있어 새 팔레트와 톤이 어긋나 보일 수 있음. 팀원 작성 코드라 이번 PR에서는 보존.
- **`lib/data/sample_data.dart`의 멤버 아바타 색**: 4명 그룹 멤버 아바타 색이 hex 문자열로 박혀 있어 warm 팔레트와 무관하게 표시. 동일한 이유로 보존.
- **`lib/screens/scan_screen.dart`의 뷰파인더 슬레이트(`0xFF1E293B`)**: 카메라 오버레이용 어두운 배경. 카메라 chrome 톤은 디자인 변경 범위 밖.

---

## 되돌리고 싶다면

본 PR이 머지된 후 부분 롤백이 필요한 경우의 가이드.

- **팔레트만 되돌리기**: `lib/theme/app_theme.dart`만 develop 시점으로 되돌리면 끝. `home_hero_card.dart`/`upcoming_item_row.dart`는 토큰 경유라 자동 적응.
- **홈 구조 되돌리기**: `lib/screens/home_screen.dart`을 되돌리고 `lib/widgets/home/` 디렉토리를 삭제. `lib/main.dart`의 `MainNavigationState.switchTab` 호출이 사라지더라도 main.dart 자체는 그대로 둘 수 있음.
- **탭 IA 되돌리기**: `lib/main.dart`만 되돌리면 `스캔` 탭이 복귀. `lib/screens/items_screen.dart`는 import 사라지면 오펀이 되니 함께 정리.
- **전체 되돌리기**: `git revert`로 본 PR의 머지 커밋 한 개.

---

## 관련 커밋

본 PR이 develop 위에 누적하는 커밋:

| SHA | 설명 |
| --- | --- |
| `29bf470` | (선행) `lib/screens/items_screen.dart` 신규 |
| `1e671ac` | (선행) `ItemStore` 롤백 추가 |
| `54dcd3f` | (선행) `ItemDetailScreen` 에러 처리 |
| `ac3b3ac` | docs: REDESIGN_NOTES 신규 |
| `7492fd1` | docs: REDESIGN_NOTES 시제 프레이밍 정리 |
| `a93467d` | theme: warm-neutral 팔레트로 토큰 값 교체 |
| `9f92613` | theme: D-day 4-tier 보존 위해 `danger ≠ primary` 분리 |
| `ee7524f` | theme: `dangerLight` 갭 확대 + 시각적 한계 문서화 |
| `d1ea091` | widgets/home: `HomeHeroCard`, `UpcomingItemRow` 신규 |
| `9dd1dbf` | widgets/home: 리뷰 반영 (조건부 CTA, warm surface) |
| `4efd77e` | home: `ItemStore` 구독으로 빌드 트리 교체 |
| `e8a32af` | main: 하단 탭 재구성 + FAB 액션 시트 |
| `46db1ac` | home/main: 리뷰 반영 (exhaustive switch, userName dedup) |
| `6aad00f` | home: `upcoming` 비었을 때 '다가오는 교체' 섹션 숨김 |
| `ea97dbe` | test/widget: 탭 라벨 검증 갱신 |
| `84636c0` | docs: REDESIGN_NOTES SHA 백필 |
| `617a844` | chore: dart format 적용 |
