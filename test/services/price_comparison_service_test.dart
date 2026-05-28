import 'package:buylog/models/item.dart';
import 'package:buylog/services/price_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PriceComparisonService', () {
    test(
      'enriches Naver results with OpenAI analysis and sorts by lowest price',
      () async {
        final requestedHeaders = <String, String>{};
        final requestedUris = <Uri>[];
        final service = PriceComparisonService(
          client: MockClient((request) async {
            requestedUris.add(request.url);
            requestedHeaders.addAll(request.headers);

            if (request.url.host == 'openapi.naver.com') {
              return http.Response(
                '''
              {
                "items": [
                  {
                    "title": "<b>Coway</b> filter 2 pack",
                    "lprice": "12000",
                    "mallName": "StoreA",
                    "link": "https://example.com/a"
                  },
                  {
                    "title": "Coway filter single",
                    "lprice": "9000",
                    "mallName": "StoreB",
                    "link": "https://example.com/b"
                  }
                ]
              }
              ''',
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }

            return http.Response(
              '''
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"items\\":[{\\"index\\":0,\\"total_count\\":2,\\"unit_price\\":6000,\\"pure_name\\":\\"Coway filter\\"},{\\"index\\":1,\\"total_count\\":1,\\"unit_price\\":9000,\\"pure_name\\":\\"Coway filter\\"}]}"
                  }
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
          openAiApiKey: 'openai-key',
        );

        final result = await service.fetchComparisons(
          itemName: 'filter',
          brand: 'Coway',
        );

        expect(requestedHeaders['X-Naver-Client-Id'], 'naver-id');
        expect(requestedHeaders['X-Naver-Client-Secret'], 'naver-secret');
        expect(requestedHeaders['Authorization'], 'Bearer openai-key');
        expect(requestedUris.first.queryParameters['query'], 'Coway filter');
        expect(result, hasLength(2));
        expect(result.first.store, '[StoreB] Coway filter (총 1개 / 개당 9,000원)');
        expect(result.first.price, 9000);
        expect(result.first.link, 'https://example.com/b');
        expect(result.first.isLowest, isTrue);
        expect(result.last.store, '[StoreA] Coway filter (총 2개 / 개당 6,000원)');
        expect(result.last.isLowest, isFalse);
      },
    );

    test('keeps Naver results when OpenAI analysis fails', () async {
      final service = PriceComparisonService(
        client: MockClient((request) async {
          if (request.url.host == 'openapi.naver.com') {
            return http.Response(
              '''
              {
                "items": [
                  {
                    "title": "<b>Coway</b> filter 2 pack",
                    "lprice": "12000",
                    "mallName": "StoreA",
                    "link": "https://example.com/a"
                  }
                ]
              }
              ''',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }

          return http.Response('server error', 500);
        }),
        naverClientId: 'naver-id',
        naverClientSecret: 'naver-secret',
        openAiApiKey: 'openai-key',
      );

      final result = await service.fetchComparisons(
        itemName: 'filter',
        brand: 'Coway',
      );

      expect(result, hasLength(1));
      expect(result.single.store, '[StoreA] Coway filter 2 pack');
      expect(result.single.price, 12000);
      expect(result.single.link, 'https://example.com/a');
      expect(result.single.isLowest, isTrue);
    });

    test('uses server proxy before direct client calls', () async {
      var directCallCount = 0;
      var proxyCallCount = 0;
      final service = PriceComparisonService(
        client: MockClient((request) async {
          directCallCount++;
          return http.Response('unexpected', 500);
        }),
        serverProxy:
            ({required brand, required display, required itemName}) async {
              proxyCallCount++;
              return const [
                PriceComparison(
                  store: '[ProxyShop] Coway filter',
                  price: 7000,
                  link: 'https://example.com/proxy',
                  isLowest: true,
                ),
              ];
            },
      );

      final result = await service.fetchComparisons(
        itemName: 'filter',
        brand: 'Coway',
      );

      expect(proxyCallCount, 1);
      expect(directCallCount, 0);
      expect(result.single.store, '[ProxyShop] Coway filter');
    });

    test(
      'returns missing credentials failure when Naver env is unavailable',
      () async {
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
      },
    );

    test(
      'does not fall back to direct Naver call when proxy fallback is disabled',
      () async {
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
      },
    );

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
  });
}
