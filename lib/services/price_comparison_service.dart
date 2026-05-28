import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/item.dart';

typedef PriceComparisonServerProxy =
    Future<List<PriceComparison>> Function({
      required String itemName,
      required String brand,
      required int display,
    });

class PriceComparisonService {
  PriceComparisonService({
    http.Client? client,
    String? naverClientId,
    String? naverClientSecret,
    String? openAiApiKey,
    PriceComparisonServerProxy? serverProxy,
  }) : _client = client ?? http.Client(),
       _naverClientId = naverClientId,
       _naverClientSecret = naverClientSecret,
       _openAiApiKey = openAiApiKey,
       _serverProxy = serverProxy;

  final http.Client _client;
  final String? _naverClientId;
  final String? _naverClientSecret;
  final String? _openAiApiKey;
  final PriceComparisonServerProxy? _serverProxy;

  Future<List<PriceComparison>> fetchComparisons({
    required String itemName,
    required String brand,
    int display = 5,
  }) async {
    final serverProxy = _serverProxy;
    if (serverProxy != null) {
      try {
        final proxiedData = await serverProxy(
          itemName: itemName,
          brand: brand,
          display: display,
        );
        if (proxiedData.isNotEmpty) return proxiedData;
      } catch (_) {
        // Fall back to direct calls on native platforms.
      }
    }

    final naverClientId =
        (_naverClientId ?? dotenv.env['NAVER_CLIENT_ID'] ?? '').trim();
    final naverClientSecret =
        (_naverClientSecret ?? dotenv.env['NAVER_CLIENT_SECRET'] ?? '').trim();

    if (naverClientId.isEmpty || naverClientSecret.isEmpty) {
      return const [];
    }

    final query = [
      brand.trim(),
      itemName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (query.isEmpty) return const [];

    final uri = Uri.https('openapi.naver.com', '/v1/search/shop.json', {
      'query': query,
      'display': display.clamp(1, 10).toString(),
      'sort': 'sim',
    });

    final response = await _client.get(
      uri,
      headers: {
        'X-Naver-Client-Id': naverClientId,
        'X-Naver-Client-Secret': naverClientSecret,
      },
    );

    if (response.statusCode != 200) return const [];

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final rawItems = decoded is Map<String, dynamic>
        ? decoded['items'] as List<dynamic>? ?? const []
        : const [];
    final shopItems = rawItems
        .whereType<Map<String, dynamic>>()
        .toList()
        .asMap()
        .entries
        .map((entry) => _NaverShopItem.fromJson(entry.key, entry.value))
        .where((item) => item != null)
        .cast<_NaverShopItem>()
        .toList();

    if (shopItems.isEmpty) return const [];

    final analyses = await _analyzeWithOpenAi(shopItems);

    final comparisons = shopItems.map((item) {
      final analysis = analyses[item.index];
      final productName = analysis?.pureName ?? item.title;
      final count = analysis?.totalCount;
      final unitPrice = analysis?.unitPrice;
      final suffix = count != null && unitPrice != null
          ? ' (총 $count개 / 개당 ${_formatPrice(unitPrice)})'
          : '';

      return PriceComparison(
        store: '[${item.mallName}] $productName$suffix',
        price: item.price,
        link: item.link,
      );
    }).toList()..sort((a, b) => a.price.compareTo(b.price));

    return [
      for (var i = 0; i < comparisons.length; i++)
        PriceComparison(
          store: comparisons[i].store,
          price: comparisons[i].price,
          link: comparisons[i].link,
          isLowest: i == 0,
        ),
    ];
  }

  Future<Map<int, _OpenAiProductAnalysis>> _analyzeWithOpenAi(
    List<_NaverShopItem> items,
  ) async {
    final openAiApiKey = (_openAiApiKey ?? dotenv.env['OPENAI_API_KEY'] ?? '')
        .trim();
    if (openAiApiKey.isEmpty) return const {};

    try {
      final response = await _client.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $openAiApiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o-mini',
          'messages': [
            {
              'role': 'system',
              'content': '너는 쇼핑 데이터 분석가야. 상품명에서 총 수량과 단가를 계산하고 JSON 스키마로만 응답해.',
            },
            {
              'role': 'user',
              'content': jsonEncode({
                'products': items
                    .map(
                      (item) => {
                        'index': item.index,
                        'title': item.title,
                        'price': item.price,
                      },
                    )
                    .toList(),
              }),
            },
          ],
          'response_format': {
            'type': 'json_schema',
            'json_schema': {
              'name': 'product_price_analysis',
              'strict': true,
              'schema': {
                'type': 'object',
                'properties': {
                  'items': {
                    'type': 'array',
                    'items': {
                      'type': 'object',
                      'properties': {
                        'index': {'type': 'integer'},
                        'total_count': {'type': 'integer'},
                        'unit_price': {'type': 'integer'},
                        'pure_name': {'type': 'string'},
                      },
                      'required': [
                        'index',
                        'total_count',
                        'unit_price',
                        'pure_name',
                      ],
                      'additionalProperties': false,
                    },
                  },
                },
                'required': ['items'],
                'additionalProperties': false,
              },
            },
          },
        }),
      );

      if (response.statusCode != 200) return const {};

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final choices = decoded is Map<String, dynamic>
          ? decoded['choices'] as List<dynamic>? ?? const []
          : const [];
      final firstChoice = choices.isEmpty ? null : choices.first;
      final message = firstChoice is Map<String, dynamic>
          ? firstChoice['message'] as Map<String, dynamic>?
          : null;
      final content = message?['content'] as String?;
      if (content == null || content.isEmpty) return const {};

      final contentJson = jsonDecode(content);
      final rawAnalyses = contentJson is Map<String, dynamic>
          ? contentJson['items'] as List<dynamic>? ?? const []
          : const [];

      final analyses = rawAnalyses
          .whereType<Map<String, dynamic>>()
          .map(_OpenAiProductAnalysis.fromJson)
          .whereType<_OpenAiProductAnalysis>();

      return {for (final analysis in analyses) analysis.index: analysis};
    } catch (_) {
      return const {};
    }
  }
}

class _NaverShopItem {
  const _NaverShopItem({
    required this.index,
    required this.title,
    required this.price,
    required this.mallName,
    required this.link,
  });

  final int index;
  final String title;
  final int price;
  final String mallName;
  final String link;

  static _NaverShopItem? fromJson(int index, Map<String, dynamic> json) {
    final price = int.tryParse((json['lprice'] as String? ?? '').trim());
    if (price == null || price <= 0) return null;

    return _NaverShopItem(
      index: index,
      title: _cleanTitle(json['title'] as String? ?? ''),
      price: price,
      mallName: (json['mallName'] as String? ?? '네이버쇼핑').trim(),
      link: (json['link'] as String? ?? '').trim(),
    );
  }
}

class _OpenAiProductAnalysis {
  const _OpenAiProductAnalysis({
    required this.index,
    required this.totalCount,
    required this.unitPrice,
    required this.pureName,
  });

  final int index;
  final int totalCount;
  final int unitPrice;
  final String pureName;

  static _OpenAiProductAnalysis? fromJson(Map<String, dynamic> json) {
    final index = (json['index'] as num?)?.toInt();
    final totalCount = (json['total_count'] as num?)?.toInt();
    final unitPrice = (json['unit_price'] as num?)?.toInt();
    final pureName = (json['pure_name'] as String?)?.trim();

    if (index == null ||
        totalCount == null ||
        unitPrice == null ||
        pureName == null ||
        pureName.isEmpty) {
      return null;
    }

    return _OpenAiProductAnalysis(
      index: index,
      totalCount: totalCount,
      unitPrice: unitPrice,
      pureName: pureName,
    );
  }
}

String _cleanTitle(String value) {
  return value
      .replaceAll(RegExp('<[^>]*>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

String _formatPrice(int price) {
  final digits = price.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer원';
}
