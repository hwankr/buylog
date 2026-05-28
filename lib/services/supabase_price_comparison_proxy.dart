import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/item.dart';

class SupabasePriceComparisonProxy {
  const SupabasePriceComparisonProxy();

  Future<List<PriceComparison>> fetchComparisons({
    required String itemName,
    required String brand,
    required int display,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'price-comparison',
      body: {'itemName': itemName, 'brand': brand, 'display': display},
    );

    final data = _decodeResponseData(response.data);
    final rawComparisons = data['comparisons'] as List<dynamic>? ?? const [];

    return rawComparisons
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => PriceComparison(
            store: row['store'] as String? ?? '',
            price: (row['price'] as num?)?.toInt() ?? 0,
            isLowest: row['isLowest'] as bool? ?? false,
            link: row['link'] as String?,
          ),
        )
        .where((comparison) => comparison.store.isNotEmpty)
        .toList(growable: false);
  }
}

Map<String, dynamic> _decodeResponseData(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is String && data.isNotEmpty) {
    final decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) return decoded;
  }
  return const {};
}
