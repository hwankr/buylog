import 'package:flutter_test/flutter_test.dart';
import 'package:buylog/services/notification_service.dart';

void main() {
  test('Notification Service 초기화 테스트', () async {
    final service = NotificationService();
    
    // 초기화가 에러 없이 완료되는지 확인
    expect(() async => await service.initialize(), returnsNormally);
  });
}