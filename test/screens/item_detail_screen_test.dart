import 'package:buylog/models/item.dart';
import 'package:buylog/models/manual_quantity_snapshot.dart';
import 'package:buylog/screens/item_detail_screen.dart';
import 'package:buylog/services/item_store.dart';
import 'package:buylog/services/price_comparison_service.dart';
import 'package:buylog/services/supabase_service.dart';
import 'package:buylog/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    dotenv.loadFromString(envString: '', isOptional: true);
    ItemStore.instance.value = [];
  });

  tearDown(() {
    ItemStore.instance.value = [];
    SupabaseService.debugItemDatabaseGateway = null;
  });

  testWidgets('group item detail shows the registrant label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        item: _item(
          id: 'item-registrant',
          groupId: 'group-1',
          registeredBy: 'user-1',
          registeredByDisplayName: 'Minseo',
          registeredByEmail: 'minseo@example.com',
        ),
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    expect(find.text('추가한 사람'), findsOneWidget);
    expect(find.text('Minseo'), findsOneWidget);
  });

  testWidgets('item detail shows fetched price comparisons', (tester) async {
    await tester.pumpWidget(
      _wrap(
        item: _item(id: 'item-success'),
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
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
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('[Shop] Coway filter'), findsOneWidget);
    expect(find.text('9,000원'), findsOneWidget);
  });

  testWidgets('item detail shows explicit price comparison failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        item: _item(id: 'item-failure'),
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
                failure: PriceComparisonFailure.proxyFailed,
                message: 'Missing Naver API credentials',
              );
            },
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.textContaining('가격 비교를 불러오지 못했습니다'), findsOneWidget);
    expect(
      find.textContaining('Missing Naver API credentials'),
      findsOneWidget,
    );
  });

  testWidgets('item detail shows empty state when no comparison exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        item: _item(id: 'item-empty'),
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.text('최저가 정보를 찾지 못했습니다.'), findsOneWidget);
  });

  testWidgets(
    'item detail shows current inventory section when snapshot exists',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          item: _item(
            id: 'item-inventory',
            remainingQuantity: 2,
            inventoryConfidence: 0.91,
            inventorySourceName: 'Milk',
            inventoryObservedAt: DateTime.parse('2026-05-29T06:12:00.000Z'),
          ),
          priceComparisonGateway:
              ({required brand, required display, required itemName}) async {
                return const PriceComparisonFetchResult(
                  comparisons: [],
                  source: PriceComparisonSource.proxy,
                );
              },
        ),
      );

      await tester.pump();

      expect(find.text('현재 남은 수량'), findsOneWidget);
      expect(find.text('2개'), findsOneWidget);
      expect(find.textContaining('신뢰도 91%'), findsOneWidget);
      expect(find.textContaining('2026.05.29'), findsOneWidget);
    },
  );

  testWidgets('item detail can decrement one remaining item manually', (
    tester,
  ) async {
    final gateway = _RecordingItemDatabaseGateway()
      ..manualUsageRemainingQuantity = 1;
    SupabaseService.debugItemDatabaseGateway = gateway;
    final item = _item(id: 'item-usage', remainingQuantity: 2);
    ItemStore.instance.value = [item];

    await tester.pumpWidget(
      _wrap(
        item: item,
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('manual_use_one_button')));
    await tester.pumpAndSettle();

    expect(gateway.manualUsageProductItemId, 'item-usage');
    expect(gateway.manualUsageUsedQuantity, 1);
    expect(find.text('1개'), findsOneWidget);
  });

  testWidgets('manual use button is disabled at zero quantity', (tester) async {
    final item = _item(id: 'item-zero', remainingQuantity: 0);
    ItemStore.instance.value = [item];

    await tester.pumpWidget(
      _wrap(
        item: item,
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('manual_use_one_button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('item detail can manually set remaining quantity', (
    tester,
  ) async {
    final gateway = _RecordingItemDatabaseGateway()
      ..manualSetRemainingQuantity = 6;
    SupabaseService.debugItemDatabaseGateway = gateway;
    final item = _item(id: 'item-set', remainingQuantity: 2);
    ItemStore.instance.value = [item];

    await tester.pumpWidget(
      _wrap(
        item: item,
        priceComparisonGateway:
            ({required brand, required display, required itemName}) async {
              return const PriceComparisonFetchResult(
                comparisons: [],
                source: PriceComparisonSource.proxy,
              );
            },
      ),
    );

    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('manual_set_quantity_button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('manual_quantity_input')),
      '6',
    );
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(gateway.manualQuantityProductItemId, 'item-set');
    expect(gateway.manualQuantityRemainingQuantity, 6);
    expect(find.text('6개'), findsOneWidget);
  });
}

Widget _wrap({
  required ConsumableItem item,
  required PriceComparisonGateway priceComparisonGateway,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: ItemDetailScreen(
      item: item,
      priceComparisonGateway: priceComparisonGateway,
    ),
  );
}

class _RecordingItemDatabaseGateway implements ItemDatabaseGateway {
  int manualUsageRemainingQuantity = 0;
  int manualSetRemainingQuantity = 0;
  String? manualUsageProductItemId;
  int? manualUsageUsedQuantity;
  String? manualQuantityProductItemId;
  int? manualQuantityRemainingQuantity;

  @override
  Future<List<Map<String, dynamic>>> loadItems({
    required String? userId,
    required String? groupId,
  }) async {
    return const <Map<String, dynamic>>[];
  }

  @override
  Future<String> ensureCategory({
    required String name,
    required String? userId,
    required String? groupId,
  }) async {
    return 'category-1';
  }

  @override
  Future<void> upsertItem(Map<String, dynamic> payload) async {}

  @override
  Future<void> insertPurchase(Map<String, dynamic> payload) async {}

  @override
  Future<void> updatePurchase({
    required String purchaseId,
    required Map<String, dynamic> payload,
  }) async {}

  @override
  Future<ManualQuantitySnapshot> setManualQuantity({
    required String productItemId,
    required int remainingQuantity,
    required DateTime observedAt,
  }) async {
    manualQuantityProductItemId = productItemId;
    manualQuantityRemainingQuantity = remainingQuantity;
    return ManualQuantitySnapshot(
      remainingQuantity: manualSetRemainingQuantity,
      confidence: 1,
      sourceName: 'manual',
      observedAt: observedAt,
    );
  }

  @override
  Future<ManualQuantitySnapshot> recordManualUsage({
    required String productItemId,
    required int usedQuantity,
    required DateTime usedAt,
  }) async {
    manualUsageProductItemId = productItemId;
    manualUsageUsedQuantity = usedQuantity;
    return ManualQuantitySnapshot(
      remainingQuantity: manualUsageRemainingQuantity,
      confidence: 1,
      sourceName: 'manual',
      observedAt: usedAt,
    );
  }
}

ConsumableItem _item({
  required String id,
  String? groupId,
  String? registeredBy,
  String? registeredByDisplayName,
  String? registeredByEmail,
  int? remainingQuantity,
  double? inventoryConfidence,
  String? inventorySourceName,
  DateTime? inventoryObservedAt,
}) {
  return ConsumableItem(
    id: id,
    name: 'filter',
    brand: 'Coway',
    category: 'filter',
    icon: Icons.filter_alt_outlined,
    daysRemaining: 20,
    cycleDays: 30,
    progress: 0.3,
    groupId: groupId,
    registeredBy: registeredBy,
    registeredByDisplayName: registeredByDisplayName,
    registeredByEmail: registeredByEmail,
    remainingQuantity: remainingQuantity,
    inventoryConfidence: inventoryConfidence,
    inventorySourceName: inventorySourceName,
    inventoryObservedAt: inventoryObservedAt,
  );
}
