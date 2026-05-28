import 'package:buylog/models/item.dart';
import 'package:buylog/services/price_comparison_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('PriceComparisonService', () {
    test('네이버 쇼핑 결과를 OpenAI 분석값으로 보강하고 최저가순으로 정렬한다', () async {
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
                    "title": "<b>브랜드</b> 샴푸 2개",
                    "lprice": "12000",
                    "mallName": "스토어A",
                    "link": "https://example.com/a"
                  },
                  {
                    "title": "브랜드 샴푸 단품",
                    "lprice": "9000",
                    "mallName": "스토어B",
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
                    "content": "{\\"items\\":[{\\"index\\":0,\\"total_count\\":2,\\"unit_price\\":6000,\\"pure_name\\":\\"브랜드 샴푸\\"},{\\"index\\":1,\\"total_count\\":1,\\"unit_price\\":9000,\\"pure_name\\":\\"브랜드 샴푸\\"}]}"
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
        itemName: '샴푸',
        brand: '브랜드',
      );

      expect(requestedHeaders['X-Naver-Client-Id'], 'naver-id');
      expect(requestedHeaders['X-Naver-Client-Secret'], 'naver-secret');
      expect(requestedHeaders['Authorization'], 'Bearer openai-key');
      expect(requestedUris.first.queryParameters['query'], '브랜드 샴푸');
      expect(result, hasLength(2));
      expect(result.first.store, '[스토어B] 브랜드 샴푸 (총 1개 / 개당 9,000원)');
      expect(result.first.price, 9000);
      expect(result.first.link, 'https://example.com/b');
      expect(result.first.isLowest, isTrue);
      expect(result.last.store, '[스토어A] 브랜드 샴푸 (총 2개 / 개당 6,000원)');
      expect(result.last.isLowest, isFalse);
    });

    test('OpenAI 분석 실패 시 네이버 쇼핑 결과만으로 가격 비교를 유지한다', () async {
      final service = PriceComparisonService(
        client: MockClient((request) async {
          if (request.url.host == 'openapi.naver.com') {
            return http.Response(
              '''
              {
                "items": [
                  {
                    "title": "<b>브랜드</b> 샴푸 2개",
                    "lprice": "12000",
                    "mallName": "스토어A",
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
        itemName: '샴푸',
        brand: '브랜드',
      );

      expect(result, hasLength(1));
      expect(result.single.store, '[스토어A] 브랜드 샴푸 2개');
      expect(result.single.price, 12000);
      expect(result.single.link, 'https://example.com/a');
      expect(result.single.isLowest, isTrue);
    });

    test('서버 프록시가 있으면 클라이언트 직접 호출보다 우선 사용한다', () async {
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
                  store: '[프록시몰] 브랜드 샴푸',
                  price: 7000,
                  link: 'https://example.com/proxy',
                  isLowest: true,
                ),
              ];
            },
      );

      final result = await service.fetchComparisons(
        itemName: '샴푸',
        brand: '브랜드',
      );

      expect(proxyCallCount, 1);
      expect(directCallCount, 0);
      expect(result.single.store, '[프록시몰] 브랜드 샴푸');
    });
  });
}
