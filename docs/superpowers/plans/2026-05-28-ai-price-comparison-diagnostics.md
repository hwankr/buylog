# AI Price Comparison Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** AI 기반 최저가 비교가 빈 목록으로 조용히 실패하지 않게 만들고, Naver/Supabase Edge/OpenAI 중 어느 경계가 깨졌는지 앱과 테스트에서 확인 가능하게 한다.

**Architecture:** 현재 로컬 `.env`, 배포된 Supabase Edge Function, Naver API, OpenAI 보강 호출은 모두 직접 점검에서 동작했다. 따라서 첫 수정은 secret 값을 더 바꾸는 것이 아니라 `PriceComparisonService`가 실패 원인과 데이터 출처를 반환하게 하고, `ItemDetailScreen`은 그 상태만 렌더링하게 분리한다.

**Tech Stack:** Flutter/Dart, `http`, `flutter_dotenv`, `supabase_flutter`, Supabase Edge Functions on Deno, Naver Shopping API, OpenAI Chat Completions.

---

## Investigation Summary

- Local `.env` contains `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, and `OPENAI_API_KEY`.
- Direct Naver Shopping API probe returned HTTP 200 with one item for `정수기 필터`.
- Deployed Supabase `price-comparison` Edge Function probe returned HTTP 200 with comparisons.
- Edge Function AI enrichment probe returned HTTP 200 with three comparisons, one `isLowest=true`, and unit-price suffix present.
- Focused tests passed:
  - `flutter test test/services/price_comparison_service_test.dart`
  - `flutter test test/ai/prediction_service_test.dart`
  - `flutter test test/screens/item_detail_screen_test.dart`
  - `flutter test test/widget_test.dart --plain-name "loadEnvironmentForStartup"`
  - `flutter test test/widget_test.dart --plain-name "App should render"`
- `dart analyze lib/services/price_comparison_service.dart lib/services/supabase_price_comparison_proxy.dart lib/screens/item_detail_screen.dart supabase/functions/price-comparison/index.ts` returned no issues.

Conclusion: the currently checked local and deployed env path is not the reproduced failure. The app still has a real reliability problem: proxy/API/env/OpenAI failures are collapsed into an empty list or generic UI text, so a transient or environment-specific failure looks exactly like "AI price comparison does not work."

## File Structure

- Modify: `lib/services/price_comparison_service.dart`
  - Add typed fetch result and failure reason.
  - Keep `fetchComparisons()` as a compatibility wrapper.
  - Add `allowDirectFallback` so web proxy failures do not silently attempt browser-direct Naver calls.
- Modify: `lib/services/supabase_price_comparison_proxy.dart`
  - Throw a typed exception when the Edge Function response contains `error`.
  - Preserve existing successful response parsing.
- Modify: `lib/screens/item_detail_screen.dart`
  - Replace `_realPriceData` plus `_isLoadingPrice` only-state with a small UI state that can also hold an error message.
  - Inject a price comparison gateway for widget tests.
- Modify: `supabase/functions/price-comparison/index.ts`
  - Return structured error codes for missing Naver credentials and Naver API failures.
  - Include `analysisEnabled` and `analysisApplied` metadata without exposing secrets.
- Modify: `test/services/price_comparison_service_test.dart`
  - Add failure-state tests for missing env, proxy failure with web-style no fallback, and OpenAI-disabled Naver-only success.
- Create: `test/services/supabase_price_comparison_proxy_test.dart`
  - Test decoding of success and error payloads through helper functions.
- Modify: `test/screens/item_detail_screen_test.dart`
  - Add UI tests for success, empty result, and explicit failure message.
- Create: `docs/price-comparison-debugging.md`
  - Document local and deployed env checks without printing secret values.

---

### Task 1: Add Typed Price Comparison Result

**Files:**
- Modify: `lib/services/price_comparison_service.dart`
- Test: `test/services/price_comparison_service_test.dart`

- [ ] **Step 1: Add failing tests for result metadata and missing Naver credentials**

Append these tests inside `group('PriceComparisonService', () { ... })` in `test/services/price_comparison_service_test.dart`:

```dart
test('returns missing credentials failure when Naver env is unavailable', () async {
  final service = PriceComparisonService(
    client: MockClient((request) async {
      fail('Naver should not be called without credentials');
    }),
    naverClientId: '',
    naverClientSecret: '',
  );

  final result = await service.fetchComparisonResult(
    itemName: 'filter',
    brand: 'Coway',
  );

  expect(result.comparisons, isEmpty);
  expect(result.source, PriceComparisonSource.none);
  expect(result.failure, PriceComparisonFailure.missingNaverCredentials);
  expect(result.message, contains('NAVER_CLIENT_ID'));
});

test('does not fall back to direct Naver call when proxy fallback is disabled', () async {
  var directCallCount = 0;
  final service = PriceComparisonService(
    client: MockClient((request) async {
      directCallCount++;
      return http.Response('unexpected', 500);
    }),
    allowDirectFallback: false,
    serverProxy: ({required brand, required display, required itemName}) {
      throw const PriceComparisonProxyException(
        code: 'missing_naver_credentials',
        message: 'Missing Naver API credentials',
      );
    },
  );

  final result = await service.fetchComparisonResult(
    itemName: 'filter',
    brand: 'Coway',
  );

  expect(directCallCount, 0);
  expect(result.comparisons, isEmpty);
  expect(result.source, PriceComparisonSource.proxy);
  expect(result.failure, PriceComparisonFailure.proxyFailed);
  expect(result.message, contains('Missing Naver API credentials'));
});

test('keeps Naver results when OpenAI analysis is disabled', () async {
  final service = PriceComparisonService(
    client: MockClient((request) async {
      expect(request.url.host, 'openapi.naver.com');
      return http.Response(
        '''
        {
          "items": [
            {
              "title": "<b>Coway</b> filter",
              "lprice": "12000",
              "mallName": "NaverShop",
              "link": "https://example.com/a"
            }
          ]
        }
        ''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
    naverClientId: 'naver-id',
    naverClientSecret: 'naver-secret',
    openAiApiKey: '',
  );

  final result = await service.fetchComparisonResult(
    itemName: 'filter',
    brand: 'Coway',
  );

  expect(result.failure, isNull);
  expect(result.source, PriceComparisonSource.directNaver);
  expect(result.comparisons.single.store, '[NaverShop] Coway filter');
  expect(result.comparisons.single.isLowest, isTrue);
});
```

- [ ] **Step 2: Run the focused service test and verify it fails**

Run:

```powershell
flutter test test/services/price_comparison_service_test.dart
```

Expected: FAIL because `fetchComparisonResult`, `PriceComparisonSource`, `PriceComparisonFailure`, `allowDirectFallback`, and `PriceComparisonProxyException` do not exist yet.

- [ ] **Step 3: Add result and exception types**

In `lib/services/price_comparison_service.dart`, add these declarations after the `PriceComparisonServerProxy` typedef:

```dart
enum PriceComparisonSource { none, proxy, directNaver }

enum PriceComparisonFailure {
  missingNaverCredentials,
  emptyQuery,
  proxyFailed,
  naverApiFailed,
  invalidNaverResponse,
  networkFailed,
}

class PriceComparisonFetchResult {
  const PriceComparisonFetchResult({
    required this.comparisons,
    required this.source,
    this.failure,
    this.message,
  });

  final List<PriceComparison> comparisons;
  final PriceComparisonSource source;
  final PriceComparisonFailure? failure;
  final String? message;

  bool get isSuccess => failure == null;
}

class PriceComparisonProxyException implements Exception {
  const PriceComparisonProxyException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => 'PriceComparisonProxyException($code): $message';
}
```

- [ ] **Step 4: Add fallback control and result-returning method**

In `PriceComparisonService`, add the constructor parameter and field:

```dart
PriceComparisonService({
  http.Client? client,
  String? naverClientId,
  String? naverClientSecret,
  String? openAiApiKey,
  PriceComparisonServerProxy? serverProxy,
  bool allowDirectFallback = true,
}) : _client = client ?? http.Client(),
     _naverClientId = naverClientId,
     _naverClientSecret = naverClientSecret,
     _openAiApiKey = openAiApiKey,
     _serverProxy = serverProxy,
     _allowDirectFallback = allowDirectFallback;

final bool _allowDirectFallback;
```

Replace the start of `fetchComparisons()` with this wrapper:

```dart
Future<List<PriceComparison>> fetchComparisons({
  required String itemName,
  required String brand,
  int display = 5,
}) async {
  final result = await fetchComparisonResult(
    itemName: itemName,
    brand: brand,
    display: display,
  );
  return result.comparisons;
}
```

Then add `fetchComparisonResult()` containing the previous fetch logic with explicit failures:

```dart
Future<PriceComparisonFetchResult> fetchComparisonResult({
  required String itemName,
  required String brand,
  int display = 5,
}) async {
  final serverProxy = _serverProxy;
  if (serverProxy != null) {
    try {
      final proxiedData = await serverProxy(
        itemName: itemName,
        brand: brand,
        display: display,
      );
      if (proxiedData.isNotEmpty) {
        return PriceComparisonFetchResult(
          comparisons: proxiedData,
          source: PriceComparisonSource.proxy,
        );
      }
    } catch (error) {
      if (!_allowDirectFallback) {
        return PriceComparisonFetchResult(
          comparisons: const [],
          source: PriceComparisonSource.proxy,
          failure: PriceComparisonFailure.proxyFailed,
          message: error.toString(),
        );
      }
    }
  }

  final naverClientId =
      (_naverClientId ?? dotenv.env['NAVER_CLIENT_ID'] ?? '').trim();
  final naverClientSecret =
      (_naverClientSecret ?? dotenv.env['NAVER_CLIENT_SECRET'] ?? '').trim();

  if (naverClientId.isEmpty || naverClientSecret.isEmpty) {
    return const PriceComparisonFetchResult(
      comparisons: [],
      source: PriceComparisonSource.none,
      failure: PriceComparisonFailure.missingNaverCredentials,
      message: 'Missing NAVER_CLIENT_ID or NAVER_CLIENT_SECRET.',
    );
  }

  final query = [brand.trim(), itemName.trim()]
      .where((part) => part.isNotEmpty)
      .join(' ');
  if (query.isEmpty) {
    return const PriceComparisonFetchResult(
      comparisons: [],
      source: PriceComparisonSource.none,
      failure: PriceComparisonFailure.emptyQuery,
      message: 'Item name or brand is required for price comparison.',
    );
  }

  final uri = Uri.https('openapi.naver.com', '/v1/search/shop.json', {
    'query': query,
    'display': display.clamp(1, 10).toString(),
    'sort': 'sim',
  });

  http.Response response;
  try {
    response = await _client.get(
      uri,
      headers: {
        'X-Naver-Client-Id': naverClientId,
        'X-Naver-Client-Secret': naverClientSecret,
      },
    );
  } catch (error) {
    return PriceComparisonFetchResult(
      comparisons: const [],
      source: PriceComparisonSource.directNaver,
      failure: PriceComparisonFailure.networkFailed,
      message: error.toString(),
    );
  }

  if (response.statusCode != 200) {
    return PriceComparisonFetchResult(
      comparisons: const [],
      source: PriceComparisonSource.directNaver,
      failure: PriceComparisonFailure.naverApiFailed,
      message: 'Naver API failed with status ${response.statusCode}.',
    );
  }

  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  final rawItems = decoded is Map<String, dynamic>
      ? decoded['items'] as List<dynamic>? ?? const []
      : const [];
  final shopItems = rawItems
      .whereType<Map<String, dynamic>>()
      .toList()
      .asMap()
      .entries
      .map((entry) => _NaverShopItem.fromJson(entry.key, entry.value))
      .where((item) => item != null)
      .cast<_NaverShopItem>()
      .toList();

  if (shopItems.isEmpty) {
    return const PriceComparisonFetchResult(
      comparisons: [],
      source: PriceComparisonSource.directNaver,
    );
  }

  final analyses = await _analyzeWithOpenAi(shopItems);
  final comparisons = _buildComparisons(shopItems, analyses);

  return PriceComparisonFetchResult(
    comparisons: comparisons,
    source: PriceComparisonSource.directNaver,
  );
}
```

Move the comparison mapping into a private helper in the same file:

```dart
List<PriceComparison> _buildComparisons(
  List<_NaverShopItem> shopItems,
  Map<int, _OpenAiProductAnalysis> analyses,
) {
  final comparisons = shopItems.map((item) {
    final analysis = analyses[item.index];
    final productName = analysis?.pureName ?? item.title;
    final count = analysis?.totalCount;
    final unitPrice = analysis?.unitPrice;
    final suffix = count != null && unitPrice != null
        ? ' (총 $count개 / 개당 ${_formatPrice(unitPrice)})'
        : '';

    return PriceComparison(
      store: '[${item.mallName}] $productName$suffix',
      price: item.price,
      link: item.link,
    );
  }).toList()
    ..sort((a, b) => a.price.compareTo(b.price));

  return [
    for (var i = 0; i < comparisons.length; i++)
      PriceComparison(
        store: comparisons[i].store,
        price: comparisons[i].price,
        link: comparisons[i].link,
        isLowest: i == 0,
      ),
  ];
}
```

- [ ] **Step 5: Run the focused service test and verify it passes**

Run:

```powershell
flutter test test/services/price_comparison_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/services/price_comparison_service.dart test/services/price_comparison_service_test.dart
git commit -m "fix: expose price comparison failures"
```

---

### Task 2: Make Supabase Proxy Error Payloads Actionable

**Files:**
- Modify: `lib/services/supabase_price_comparison_proxy.dart`
- Create: `test/services/supabase_price_comparison_proxy_test.dart`

- [ ] **Step 1: Create failing proxy decoding tests**

Create `test/services/supabase_price_comparison_proxy_test.dart`:

```dart
import 'package:buylog/services/price_comparison_service.dart';
import 'package:buylog/services/supabase_price_comparison_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabasePriceComparisonProxy response parsing', () {
    test('parses successful comparison payload', () {
      final comparisons = parsePriceComparisonPayload({
        'comparisons': [
          {
            'store': '[Shop] Filter',
            'price': 9000,
            'isLowest': true,
            'link': 'https://example.com/filter',
          },
        ],
      });

      expect(comparisons.single.store, '[Shop] Filter');
      expect(comparisons.single.price, 9000);
      expect(comparisons.single.isLowest, isTrue);
      expect(comparisons.single.link, 'https://example.com/filter');
    });

    test('throws typed exception when function returns error payload', () {
      expect(
        () => parsePriceComparisonPayload({
          'error': 'Missing Naver API credentials',
          'code': 'missing_naver_credentials',
        }),
        throwsA(
          isA<PriceComparisonProxyException>()
              .having((error) => error.code, 'code', 'missing_naver_credentials')
              .having(
                (error) => error.message,
                'message',
                contains('Missing Naver API credentials'),
              ),
        ),
      );
    });
  });
}
```

- [ ] **Step 2: Run the proxy test and verify it fails**

Run:

```powershell
flutter test test/services/supabase_price_comparison_proxy_test.dart
```

Expected: FAIL because `parsePriceComparisonPayload` does not exist and error payloads are not typed.

- [ ] **Step 3: Extract proxy payload parser**

In `lib/services/supabase_price_comparison_proxy.dart`, replace the in-method parsing with:

```dart
final data = _decodeResponseData(response.data);
return parsePriceComparisonPayload(data);
```

Then add this top-level helper:

```dart
List<PriceComparison> parsePriceComparisonPayload(Map<String, dynamic> data) {
  final error = (data['error'] as String?)?.trim();
  if (error != null && error.isNotEmpty) {
    throw PriceComparisonProxyException(
      code: (data['code'] as String?)?.trim().isNotEmpty == true
          ? (data['code'] as String).trim()
          : 'edge_function_error',
      message: error,
    );
  }

  final rawComparisons = data['comparisons'] as List<dynamic>? ?? const [];
  return rawComparisons
      .whereType<Map<String, dynamic>>()
      .map(
        (row) => PriceComparison(
          store: row['store'] as String? ?? '',
          price: (row['price'] as num?)?.toInt() ?? 0,
          isLowest: row['isLowest'] as bool? ?? false,
          link: row['link'] as String?,
        ),
      )
      .where((comparison) => comparison.store.isNotEmpty)
      .toList(growable: false);
}
```

- [ ] **Step 4: Run proxy and service tests**

Run:

```powershell
flutter test test/services/supabase_price_comparison_proxy_test.dart
flutter test test/services/price_comparison_service_test.dart
```

Expected: both PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/services/supabase_price_comparison_proxy.dart test/services/supabase_price_comparison_proxy_test.dart
git commit -m "fix: parse price proxy errors"
```

---

### Task 3: Surface Price Comparison State In Item Detail

**Files:**
- Modify: `lib/screens/item_detail_screen.dart`
- Modify: `test/screens/item_detail_screen_test.dart`

- [ ] **Step 1: Add failing item detail state tests**

In `test/screens/item_detail_screen_test.dart`, add:

```dart
import 'package:buylog/services/price_comparison_service.dart';
```

Then add these tests:

```dart
testWidgets('item detail shows fetched price comparisons', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ItemDetailScreen(
        item: _item(),
        priceComparisonGateway: ({required brand, required display, required itemName}) async {
          return const PriceComparisonFetchResult(
            comparisons: [
              PriceComparison(
                store: '[Shop] Coway filter',
                price: 9000,
                isLowest: true,
                link: 'https://example.com/filter',
              ),
            ],
            source: PriceComparisonSource.proxy,
          );
        },
      ),
    ),
  );

  await tester.pump();
  await tester.pump();

  expect(find.text('[Shop] Coway filter'), findsOneWidget);
  expect(find.text('9,000원'), findsOneWidget);
});

testWidgets('item detail shows explicit price comparison failure', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: ItemDetailScreen(
        item: _item(),
        priceComparisonGateway: ({required brand, required display, required itemName}) async {
          return const PriceComparisonFetchResult(
            comparisons: [],
            source: PriceComparisonSource.proxy,
            failure: PriceComparisonFailure.proxyFailed,
            message: 'Missing Naver API credentials',
          );
        },
      ),
    ),
  );

  await tester.pump();
  await tester.pump();

  expect(find.textContaining('가격 비교를 불러오지 못했습니다'), findsOneWidget);
  expect(find.textContaining('Missing Naver API credentials'), findsOneWidget);
});

ConsumableItem _item() {
  return const ConsumableItem(
    id: 'item-price',
    name: 'filter',
    brand: 'Coway',
    category: 'filter',
    icon: Icons.filter_alt_outlined,
    daysRemaining: 20,
    cycleDays: 30,
    progress: 0.3,
  );
}
```

- [ ] **Step 2: Run item detail tests and verify failure**

Run:

```powershell
flutter test test/screens/item_detail_screen_test.dart
```

Expected: FAIL because `ItemDetailScreen.priceComparisonGateway` does not exist and the UI has no explicit failure message state.

- [ ] **Step 3: Add injectable gateway typedef and state fields**

In `lib/screens/item_detail_screen.dart`, add after imports:

```dart
typedef PriceComparisonGateway =
    Future<PriceComparisonFetchResult> Function({
      required String itemName,
      required String brand,
      required int display,
    });
```

Update the widget:

```dart
class ItemDetailScreen extends StatefulWidget {
  final ConsumableItem item;
  final PriceComparisonGateway? priceComparisonGateway;

  const ItemDetailScreen({
    super.key,
    required this.item,
    this.priceComparisonGateway,
  });
```

Add an error field in `_ItemDetailScreenState`:

```dart
String? _priceErrorMessage;
```

- [ ] **Step 4: Use result API and disable direct fallback on web**

Replace `_fetchRealTimePrice()` service construction with:

```dart
final gateway = widget.priceComparisonGateway;
final result = gateway != null
    ? await gateway(itemName: _item.name, brand: _item.brand, display: 5)
    : await PriceComparisonService(
        serverProxy: kIsWeb
            ? const SupabasePriceComparisonProxy().fetchComparisons
            : null,
        allowDirectFallback: !kIsWeb,
      ).fetchComparisonResult(itemName: _item.name, brand: _item.brand);

if (result.comparisons.isNotEmpty) {
  _priceCache[_item.id] = PriceCacheData(
    priceData: result.comparisons,
    fetchedAt: DateTime.now(),
  );
}

if (mounted) {
  setState(() {
    _realPriceData = result.comparisons;
    _priceErrorMessage = result.failure == null ? null : result.message;
    _isLoadingPrice = false;
  });
}
```

In the `catch` block, set the message:

```dart
if (mounted) {
  setState(() {
    _priceErrorMessage = e.toString();
    _isLoadingPrice = false;
  });
}
```

- [ ] **Step 5: Render explicit failure before empty-state copy**

In `_buildPriceComparison()`, replace the empty branch with:

```dart
else if (_priceErrorMessage != null)
  Text(
    '가격 비교를 불러오지 못했습니다. $_priceErrorMessage',
    style: const TextStyle(color: AppColors.textMuted),
  )
else if (_realPriceData.isEmpty)
  const Text(
    '최저가 정보를 찾지 못했습니다.',
    style: TextStyle(color: AppColors.textMuted),
  )
```

- [ ] **Step 6: Run item detail tests**

Run:

```powershell
flutter test test/screens/item_detail_screen_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit**

```powershell
git add lib/screens/item_detail_screen.dart test/screens/item_detail_screen_test.dart
git commit -m "fix: show price comparison failures"
```

---

### Task 4: Return Structured Edge Function Diagnostics

**Files:**
- Modify: `supabase/functions/price-comparison/index.ts`

- [ ] **Step 1: Update error responses**

In `supabase/functions/price-comparison/index.ts`, change missing credential handling:

```ts
if (!naverClientId || !naverClientSecret) {
  throw new PriceComparisonError(
    'missing_naver_credentials',
    'Missing Naver API credentials',
    500,
  )
}
```

Add this class near the type declarations:

```ts
class PriceComparisonError extends Error {
  constructor(
    readonly code: string,
    message: string,
    readonly status: number,
  ) {
    super(message)
  }
}
```

Update the Naver failure:

```ts
if (!response.ok) {
  throw new PriceComparisonError(
    'naver_api_failed',
    `Naver API failed with status ${response.status}`,
    502,
  )
}
```

Update the top-level catch:

```ts
} catch (error) {
  if (error instanceof PriceComparisonError) {
    return jsonResponse(
      { code: error.code, error: error.message },
      error.status,
    )
  }

  return jsonResponse(
    { code: 'unknown_error', error: error instanceof Error ? error.message : 'Unknown error' },
    500,
  )
}
```

- [ ] **Step 2: Add analysis metadata to success response**

Change `fetchComparisons()` to return an object:

```ts
const { comparisons, analysisApplied } = await fetchComparisons({
  itemName: String(itemName ?? ''),
  brand: String(brand ?? ''),
  display: Number(display),
})

return jsonResponse({
  comparisons,
  analysisEnabled: Boolean(Deno.env.get('OPENAI_API_KEY')?.trim()),
  analysisApplied,
})
```

Inside `fetchComparisons()`, return:

```ts
return {
  comparisons: comparisons.map((item, index) => ({
    ...item,
    isLowest: index === 0,
  })),
  analysisApplied: analyses.size > 0,
}
```

For early empty returns, use:

```ts
return { comparisons: [], analysisApplied: false }
```

- [ ] **Step 3: Verify Edge Function TypeScript formatting manually**

Run:

```powershell
supabase functions serve price-comparison --env-file .env
```

Then in another terminal:

```powershell
$body = '{"itemName":"정수기 필터","brand":"","display":1}'
Invoke-RestMethod -Uri "http://127.0.0.1:54321/functions/v1/price-comparison" -Headers @{ Authorization = "Bearer $env:SUPABASE_ANON_KEY"; "Content-Type" = "application/json" } -Method POST -Body $body
```

Expected: response contains `comparisons`, `analysisEnabled`, and `analysisApplied`. If the local Supabase CLI is not installed, skip the local serve and deploy to a staging project first.

- [ ] **Step 4: Commit**

```powershell
git add supabase/functions/price-comparison/index.ts
git commit -m "fix: add price comparison edge diagnostics"
```

---

### Task 5: Add Debugging Documentation

**Files:**
- Create: `docs/price-comparison-debugging.md`

- [ ] **Step 1: Create the debugging runbook**

Create `docs/price-comparison-debugging.md`:

````markdown
# Price Comparison Debugging

## Local keys

Check only key presence. Do not print secret values.

```powershell
$envMap = @{}
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    $envMap[$matches[1].Trim()] = $matches[2].Trim()
  }
}
'SUPABASE_URL','SUPABASE_ANON_KEY','NAVER_CLIENT_ID','NAVER_CLIENT_SECRET','OPENAI_API_KEY' |
  ForEach-Object {
    $state = if ($envMap.ContainsKey($_) -and -not [string]::IsNullOrWhiteSpace($envMap[$_])) { 'SET' } else { 'MISSING' }
    "$_=$state"
  }
```

## Direct Naver probe

This verifies local Naver credentials without showing the credentials.

```powershell
Add-Type -AssemblyName System.Net.Http
$client = [System.Net.Http.HttpClient]::new()
$query = [System.Net.WebUtility]::UrlEncode('정수기 필터')
$req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, "https://openapi.naver.com/v1/search/shop.json?query=$query&display=1&sort=sim")
$req.Headers.Add('X-Naver-Client-Id', $envMap['NAVER_CLIENT_ID'])
$req.Headers.Add('X-Naver-Client-Secret', $envMap['NAVER_CLIENT_SECRET'])
$res = $client.SendAsync($req).GetAwaiter().GetResult()
"Naver direct HTTP $([int]$res.StatusCode)"
$client.Dispose()
```

## Deployed Supabase Edge probe

This verifies the deployed Edge Function and its deployed secrets.

```powershell
$functionUri = "$($envMap['SUPABASE_URL'].TrimEnd('/'))/functions/v1/price-comparison"
$body = '{"itemName":"정수기 필터","brand":"","display":1}'
Invoke-RestMethod -Uri $functionUri -Headers @{ Authorization = "Bearer $($envMap['SUPABASE_ANON_KEY'])"; "Content-Type" = "application/json" } -Method POST -Body $body
```

Expected: `comparisons` is present. `analysisApplied=true` means OpenAI enrichment was applied.
````

- [ ] **Step 2: Commit**

```powershell
git add docs/price-comparison-debugging.md
git commit -m "docs: add price comparison debugging runbook"
```

---

### Task 6: Final Verification

**Files:**
- Verify all modified files.

- [ ] **Step 1: Format Dart files**

Run:

```powershell
dart format lib/services/price_comparison_service.dart lib/services/supabase_price_comparison_proxy.dart lib/screens/item_detail_screen.dart test/services/price_comparison_service_test.dart test/services/supabase_price_comparison_proxy_test.dart test/screens/item_detail_screen_test.dart
```

Expected: formatter completes without syntax errors.

- [ ] **Step 2: Analyze changed Dart files**

Run:

```powershell
dart analyze lib/services/price_comparison_service.dart lib/services/supabase_price_comparison_proxy.dart lib/screens/item_detail_screen.dart test/services/price_comparison_service_test.dart test/services/supabase_price_comparison_proxy_test.dart test/screens/item_detail_screen_test.dart
```

Expected: no issues.

- [ ] **Step 3: Run focused tests**

Run:

```powershell
flutter test test/services/price_comparison_service_test.dart
flutter test test/services/supabase_price_comparison_proxy_test.dart
flutter test test/screens/item_detail_screen_test.dart
flutter test test/widget_test.dart --plain-name "loadEnvironmentForStartup"
```

Expected: all tests pass.

- [ ] **Step 4: Run live probes without printing secrets**

Run the commands from `docs/price-comparison-debugging.md`.

Expected:
- local key presence shows all required keys as `SET`;
- direct Naver probe returns HTTP 200;
- deployed Supabase Edge probe returns `comparisons`;
- `analysisApplied=true` when OpenAI enrichment succeeds.

- [ ] **Step 5: Review diff scope**

Run:

```powershell
git diff --stat HEAD
git diff -- lib/services/price_comparison_service.dart lib/services/supabase_price_comparison_proxy.dart lib/screens/item_detail_screen.dart supabase/functions/price-comparison/index.ts
```

Expected: diff only contains price comparison diagnostics, explicit error handling, web fallback behavior, tests, and runbook documentation.

---

## Self-Review

- Spec coverage: The plan answers whether this is currently an env problem, adds failure visibility for env/API/proxy/OpenAI boundaries, and gives a practical fix path.
- Business logic boundary: external-call decisions stay in services and Edge Function; Flutter widgets only receive typed state and render it.
- Test coverage: missing credentials, proxy error, OpenAI-disabled success, UI success, UI failure, and Edge payload parsing are covered.
- Placeholder scan: no unresolved implementation placeholders remain.
- Risk note: moving every platform to the Edge Function would remove client-side Naver secrets entirely, but this plan keeps native direct fallback for compatibility and disables it only for web where browser CORS makes direct Naver calls unreliable.
