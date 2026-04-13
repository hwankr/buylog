import 'package:flutter/widgets.dart';

import '../../services/report_service.dart';

/// PR2에서 실 구현 예정. 현재는 placeholder.
class MonthFilterListView extends StatelessWidget {
  const MonthFilterListView({
    super.key,
    required this.selectedMonth,
    required this.service,
  });

  final DateTime? selectedMonth;
  final ReportService service;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
