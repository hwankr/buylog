import 'package:flutter/widgets.dart';

import '../../services/report_service.dart';

/// PR3에서 실 구현 예정. 현재는 placeholder.
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({super.key, required this.service});

  final ReportService service;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
