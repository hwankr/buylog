class ManualQuantitySnapshot {
  const ManualQuantitySnapshot({
    required this.remainingQuantity,
    required this.confidence,
    required this.sourceName,
    required this.observedAt,
  });

  final int remainingQuantity;
  final double confidence;
  final String sourceName;
  final DateTime observedAt;

  factory ManualQuantitySnapshot.fromSupabase(Map<String, dynamic> row) {
    final observedAtRaw = row['observed_at'];
    return ManualQuantitySnapshot(
      remainingQuantity: (row['remaining_quantity'] as num).toInt(),
      confidence: (row['confidence'] as num).toDouble(),
      sourceName: row['source_detected_name'] as String? ?? 'manual',
      observedAt: observedAtRaw is DateTime
          ? observedAtRaw
          : DateTime.parse(observedAtRaw as String),
    );
  }
}
