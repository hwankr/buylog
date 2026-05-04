# buylog UI 리디자인 (2026-05) 변경 노트

> 작성: 전승환 / 검토 대상: 팀원 4명 / 적용 브랜치: `ui-test`
> 디자인 원본: `.design-handoff/project/prototype.html` (Claude Design 핸드오프)

이 문서는 리디자인 PR이 **어느 파일을 / 왜 / 어디까지** 건드렸는지를 1페이지로 요약한다. 자기 코드가 바뀌었다고 느낀다면 이 문서의 해당 섹션을 먼저 읽어주세요. 되돌리고 싶은 결정이 있다면 PR 코멘트로 토론합시다.

## 한 줄 요약

따뜻한 뉴트럴 톤(아이보리 + 테라코타 + 세이지 모스)으로 비주얼 통일 + 홈 화면 정보 위계 재정리 + 하단 탭에서 `스캔` 자리를 `모든 제품`으로 교체.

## 변경 / 미변경 파일 한눈에

| 파일 | 변경? | 이유 |
| --- | --- | --- |
| `lib/theme/app_theme.dart` | ✅ 값만 | 모든 화면이 토큰 경유 → 한 곳만 바꾸면 끝 |
| `lib/main.dart` | ✅ 구조 | 하단 탭 IA 변경 (`스캔` → `모든 제품`), FAB 액션 시트 |
| `lib/screens/home_screen.dart` | ✅ 구조 | 디자인의 1/3이 홈 히어로·다가오는 교체·최근 기록 |
| `lib/screens/items_screen.dart` | 🆕 신규 | 새 `모든 제품` 탭 |
| `lib/widgets/home/home_hero_card.dart` | 🆕 신규 | 홈 히어로 카드 컴포지트 |
| `lib/widgets/home/upcoming_item_row.dart` | 🆕 신규 | 홈 컴팩트 행 |
| `test/widget_test.dart` | ✅ 1줄 | 탭 라벨 변경 반영 |
| `lib/services/item_store.dart` | ✅ 롤백 추가 (이전 PR) | Supabase 실패 시 ghost item 방지 |
| `lib/screens/item_detail_screen.dart` | ✅ try/catch (이전 PR) | 위 롤백의 rethrow 처리 |
| **그 외 모든 화면/위젯 파일** | ❌ | `AppColors` 토큰 경유 → 자동으로 새 팔레트 |

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

- 팔레트만 되돌리기: `lib/theme/app_theme.dart` 한 파일을 develop 시점으로 되돌리면 끝
- 홈 구조 되돌리기: `lib/screens/home_screen.dart`만 되돌리면 끝 (다른 화면 영향 없음)
- 탭 IA 되돌리기: `lib/main.dart`만 되돌리면 끝
- 전체 되돌리기: `git revert`로 이 PR의 머지 커밋 하나만

## 관련 커밋

| SHA | 설명 |
| --- | --- |
| `29bf470` | `lib/screens/items_screen.dart` 신규 (이 PR 이전 작업) |
| `1e671ac` | `ItemStore` 롤백 추가 |
| `54dcd3f` | `ItemDetailScreen` 에러 처리 |
| (이 PR) | 위 노트의 본 변경사항 |
