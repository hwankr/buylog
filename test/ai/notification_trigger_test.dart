import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/services/ai/notification_trigger.dart';

void main() {
  test('D-7 알림', () {
    final result = checkNotificationTrigger(dDay: 7);
    expect(result, NotificationTrigger.d7);
  });

  test('D-3 알림', () {
    final result = checkNotificationTrigger(dDay: 3);
    expect(result, NotificationTrigger.d3);
  });

  test('D-1 알림', () {
    final result = checkNotificationTrigger(dDay: 1);
    expect(result, NotificationTrigger.d1);
  });

  test('D-0 알림', () {
    final result = checkNotificationTrigger(dDay: 0);
    expect(result, NotificationTrigger.d0);
  });

  test('알림 없음', () {
    final result = checkNotificationTrigger(dDay: 10);
    expect(result, NotificationTrigger.none);
  });
}
