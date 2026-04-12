import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/services/ai/prediction_service.dart';
import 'package:buylog/services/ai/notification_trigger.dart';

void main() {
  test('D-7 알림', () {
    final result = checkNotificationTrigger(dDay: 7);
    print('트리거: $result');
    expect(result, NotificationTrigger.d7);
  });

  test('D-3 알림', () {
    final result = checkNotificationTrigger(dDay: 3);
    print('트리거: $result');
    expect(result, NotificationTrigger.d3);
  });

  test('D-1 알림', () {
    final result = checkNotificationTrigger(dDay: 1);
    print('트리거: $result');
    expect(result, NotificationTrigger.d1);
  });

  test('D-0 알림', () {
    final result = checkNotificationTrigger(dDay: 0);
    print('트리거: $result');
    expect(result, NotificationTrigger.d0);
  });

  test('알림 없음', () {
    final result = checkNotificationTrigger(dDay: 10);
    print('트리거: $result');
    expect(result, NotificationTrigger.none);
  });
}