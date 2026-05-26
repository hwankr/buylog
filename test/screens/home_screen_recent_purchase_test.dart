import 'package:buylog/models/item.dart';
import 'package:buylog/screens/home_screen.dart';
import 'package:buylog/services/item_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ConsumableItem _buildItem({
  required String id,
  required String name,
  required String brand,
  required IconData icon,
  required int daysRemaining,
  List<PurchaseRecord> purchaseHistory = const [],
}) {
  return ConsumableItem(
    id: id,
    name: name,
    brand: brand,
    category: '생활용품',
    icon: icon,
    daysRemaining: daysRemaining,
    cycleDays: 30,
    progress: 0.3,
    purchaseHistory: purchaseHistory,
    createdAt: DateTime.now(),
  );
}

Widget _wrapHome() {
  return const MaterialApp(home: Scaffold(body: HomeScreen()));
}

void main() {
  setUp(() {
    ItemStore.instance.value = [];
  });

  tearDown(() {
    ItemStore.instance.value = [];
  });

  testWidgets('uses neutral user name in the latest home UI', (tester) async {
    await tester.pumpWidget(_wrapHome());

    expect(find.textContaining('사용자'), findsOneWidget);
    expect(find.textContaining('지민'), findsNothing);
  });

  testWidgets('renders recent ledger rows from ItemStore purchase history', (
    tester,
  ) async {
    ItemStore.instance.value = [
      _buildItem(
        id: 'filter',
        name: '샤워기 필터',
        brand: '바디럽',
        icon: Icons.water_drop_outlined,
        daysRemaining: 2,
        purchaseHistory: [
          PurchaseRecord(
            date: DateTime(2026, 5, 5),
            price: 34900,
            store: '코웨이몰',
          ),
        ],
      ),
      _buildItem(
        id: 'capsule',
        name: '세탁 캡슐',
        brand: '퍼실',
        icon: Icons.local_laundry_service_outlined,
        daysRemaining: 10,
        purchaseHistory: [
          PurchaseRecord(
            date: DateTime(2026, 4, 27),
            price: 17900,
            store: '쿠팡',
          ),
        ],
      ),
    ];

    await tester.pumpWidget(_wrapHome());

    expect(find.text('최근 기록'), findsOneWidget);
    expect(find.text('샤워기 필터 구매 기록됨 · 코웨이몰 · 34,900원'), findsOneWidget);
    expect(find.text('세탁 캡슐 구매 기록됨 · 쿠팡 · 17,900원'), findsOneWidget);
    expect(find.text('05.05'), findsOneWidget);
    expect(find.text('04.27'), findsOneWidget);
    expect(find.text('이마트 영수증 3개 항목 자동 추가'), findsNothing);
    expect(find.text('세탁세제 주기 45일로 업데이트'), findsNothing);
  });

  testWidgets('shows an honest empty state when no purchase history exists', (
    tester,
  ) async {
    ItemStore.instance.value = [
      _buildItem(
        id: 'tissue',
        name: '미용 티슈',
        brand: '크리넥스',
        icon: Icons.inventory_2_outlined,
        daysRemaining: 5,
      ),
    ];

    await tester.pumpWidget(_wrapHome());

    expect(find.text('최근 기록'), findsOneWidget);
    expect(find.text('최근 기록이 없습니다.'), findsOneWidget);
    expect(find.textContaining('영수증'), findsNothing);
  });
}
