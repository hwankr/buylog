import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/main.dart';

void main() {
  testWidgets('App should render', (WidgetTester tester) async {
    await tester.pumpWidget(const BuylogApp());
    expect(find.text('내 아이템'), findsOneWidget);
  });
}
