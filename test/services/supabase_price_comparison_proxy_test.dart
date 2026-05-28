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
              .having(
                (error) => error.code,
                'code',
                'missing_naver_credentials',
              )
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
