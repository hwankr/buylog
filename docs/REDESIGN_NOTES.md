# buylog UI 리디자인 (2026-05) 변경 노트

> 작성: 전승환 / 검토 대상: 팀원 4명 / 적용 브랜치: `ui-test`
> 디자인 원본: `.design-handoff/project/prototype.html` (Claude Design 핸드오프)

이 문서는 본 PR이 **어느 파일을 / 왜 / 어디까지** 건드리는지를 1페이지로 요약한다. 본인 담당 화면의 영향 범위가 궁금하다면 이 문서의 해당 섹션을 먼저 확인해주세요. 되돌리고 싶은 결정이 있다면 PR 코멘트로 토론합시다.

> **주의:** 본 PR은 여러 커밋에 나눠 적용됩니다. 이 문서는 PR이 모두 머지된 시점의 최종 상태를 기준으로 작성되었습니다. 중간 커밋을 fetch한 시점에는 표의 일부 변경이 아직 반영되지 않았을 수 있습니다.

## 한 줄 요약

따뜻한 뉴트럴 톤(아이보리 + 테라코타 + 세이지 모스)으로 비주얼 통일 + 홈 화면 정보 위계 재정리 + 하단 탭에서 `스캔` 자리를 `모든 제품`으로 교체.

## 변경 / 미변경 파일 한눈에

| 파일 | 변경? | 적용 커밋 그룹 | 이유 |
| --- | --- | --- | --- |
| `lib/services/item_store.dart` | 롤백 추가 | 데이터 안정화 (1e671ac 외) | Supabase 실패 시 ghost item 방지 |
| `lib/screens/item_detail_screen.dart` | try/catch | 데이터 안정화 (54dcd3f) | 위 롤백의 rethrow 처리 |
| `lib/screens/items_screen.dart` | 🆕 신규 | 데이터 안정화 (29bf470) | 새 `모든 제품` 탭의 본체 |
| `docs/REDESIGN_NOTES.md` | 🆕 신규 | 리디자인 본편 | 이 문서 |
| `lib/theme/app_theme.dart` | 값만 | 리디자인 본편 | 모든 화면이 토큰 경유 → 한 곳만 바꾸면 끝 |
| `lib/widgets/home/home_hero_card.dart` | 🆕 신규 | 리디자인 본편 | 홈 히어로 카드 컴포지트 |
| `lib/widgets/home/upcoming_item_row.dart` | 🆕 신규 | 리디자인 본편 | 홈 컴팩트 행 |
| `lib/screens/home_screen.dart` | 구조 | 리디자인 본편 | 디자인의 1/3이 홈 (히어로·다가오는 교체·최근 기록) |
| `lib/main.dart` | 구조 | 리디자인 본편 | 하단 탭 IA 변경 (`스캔` → `모든 제품`), FAB 액션 시트 |
| `test/widget_test.dart` | 1줄 | 리디자인 본편 | 탭 라벨 변경 반영 |
| **그 외 모든 화면/위젯 파일** | ❌ | — | `AppColors` 토큰 경유 → 자동으로 새 팔레트 |

> 팀원 작성 코드(`group_screen`, `reports_screen`, `settings_screen`, `add_item_screen`, `widgets/item_card`, `widgets/dday_badge`, `widgets/countdown_ring`, `widgets/reports/*`)는 **한 줄도 수정하지 않았다.** 색/카드/링 비주얼이 달라 보이는 것은 토큰 값만 바뀐 결과.

## 왜 이렇게 바꿨나 (3가지 의사결정)

### 1. 팔레트 토큰 값만 교체 — 식별자 유지

`AppColors.primary` 등 19개 토큰의 *값*만 바꾸고 *이름*은 유지했다. 이유:
- 모든 팀원 코드가 토큰 경유로 색을 사용 중 → 한 군데만 바꾸면 자동 적용
- 식별자가 그대로라 grep 호환성·blame 안정성 보존
- 각자가 작업한 화면 파일은 diff에 등장하지 않음

`primary`라는 이름이 더 이상 cyan이 아니라 terracotta가 된 점이 약간의 인지 부조화를 유발하지만, 이름을 바꾸면 모든 호출부를 건드려야 해서 비용 대비 손실이 더 컸다.

### 2. 홈 = 큐레이팅 다이제스트, 전체 리스트 = `모든 제품` 탭

기존 홈은 무한 스크롤로 전체 품목을 노출했다. 새 디자인은 홈을 "오늘 챙겨야 할 것"에 집중하는 다이제스트로 바꾸고, 전체 리스트는 새 `모든 제품` 탭으로 옮겼다.

기술적 결과:
- 홈의 자체 Supabase 페이지네이션 (`_supabase.from('product_items')`, `ScrollController`, `_isMoreLoading` 등)을 모두 제거
- 홈은 `ValueListenableBuilder<List<ConsumableItem>>`로 `ItemStore` 구독 → AddItem/ItemDetail과 동일한 단일 소스
- 결과: 직접 등록 직후 홈에 즉시 반영. 이전에는 홈만 stale.

### 3. `스캔` 탭 → `모든 제품` 탭, 스캔은 FAB 액션 시트로

5탭 중 `스캔`은 진입 빈도가 낮은 모달성 작업이라 탭 슬롯을 차지하기엔 비효율. 디자인은 이 자리를 `모든 제품`으로 바꾸고, FAB을 누르면 *카메라 스캔* / *직접 등록* 두 가지가 떠오르는 액션 시트로 통합.

기술적 결과:
- `ScanScreen` 코드 자체는 한 줄도 안 바뀜 — `main.dart`에서만 라우팅이 바뀜
- FAB이 홈/모든 제품 탭에서 노출

## 되돌리고 싶다면

본 PR이 머지된 후 부분 롤백이 필요한 경우의 가이드입니다.

- **팔레트만 되돌리기**: `lib/theme/app_theme.dart`만 develop 시점으로 되돌립니다. `home_hero_card.dart`/`upcoming_item_row.dart`는 토큰 경유라 자동 적응합니다.
- **홈 구조 되돌리기**: `lib/screens/home_screen.dart`을 되돌리고 `lib/widgets/home/` 디렉토리를 삭제합니다. `lib/main.dart`의 `MainNavigationState.switchTab` 호출이 사라지더라도 main.dart 자체는 그대로 둘 수 있습니다.
- **탭 IA 되돌리기**: `lib/main.dart`만 되돌리면 `스캔` 탭이 복귀합니다. `lib/screens/items_screen.dart`는 import 사라지면 오펀이 되니 함께 정리하세요.
- **전체 되돌리기**: `git revert`로 본 PR의 머지 커밋 한 개.

## 알려진 시각적 한계 (후속 폴리시 후보)

리디자인 적용 후에도 남는 자잘한 시각 이슈를 팀 공통 인지로 남깁니다. 본 PR 범위에서는 의도적으로 손대지 않았습니다.

- **D-day 배지 텍스트 대비**: warm 팔레트의 status fg/bg 페어(`success/successLight`, `warning/warningLight`, `primary/primaryLight2`)는 12 px 굵은 글자에서 WCAG AA(4.5:1)에 미달합니다. 디자인 핸드오프의 의도적 선택을 따랐고, 접근성 보강이 필요해지면 fg 토큰을 한 단계 어둡게 하거나 별도 `onPrimary/onSuccess` 토큰을 도입하는 follow-up이 자연스럽습니다.
- **`lib/widgets/reports/category_pie_chart.dart` 카테고리 색**: 파일 내부에 cool 톤 hex가 하드코딩되어 있어 새 팔레트와 톤이 어긋나 보일 수 있습니다. 팀원 작성 코드라 이번 PR에서는 보존했습니다.
- **`lib/data/sample_data.dart`의 멤버 아바타 색**: 4명 그룹 멤버 아바타 색이 hex 문자열로 박혀 있어 warm 팔레트와 무관하게 표시됩니다. 동일한 이유로 보존했습니다.
- **`lib/screens/scan_screen.dart`의 뷰파인더 슬레이트(`0xFF1E293B`)**: 카메라 오버레이용 어두운 배경. 카메라 chrome 톤은 디자인 변경 범위 밖이라 그대로 둡니다.

위 항목 중 하나라도 폴리시가 필요하다고 판단되면 별도 PR로 진행해주세요.

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
