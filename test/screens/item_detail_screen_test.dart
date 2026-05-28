import 'package:buylog/models/item.dart';
import 'package:buylog/screens/item_detail_screen.dart';
import 'package:buylog/services/item_store.dart';
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
  });

  testWidgets('group item detail shows the registrant label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ItemDetailScreen(
          item: ConsumableItem(
            id: 'item-1',
            name: 'filter',
            brand: 'Coway',
            category: 'filter',
            icon: Icons.filter_alt_outlined,
            daysRemaining: 20,
            cycleDays: 30,
            progress: 0.3,
            groupId: 'group-1',
            registeredBy: 'user-1',
            registeredByDisplayName: 'Minseo',
            registeredByEmail: 'minseo@example.com',
          ),
        ),
      ),
    );

    expect(find.text('추가한 사람'), findsOneWidget);
    expect(find.text('Minseo'), findsOneWidget);
  });
}
