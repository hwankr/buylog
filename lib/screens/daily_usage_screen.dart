import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/daily_usage_service.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';

/// 카테고리별 일일 사용량 입력 폼.
///
/// 저장된 값은 [DailyUsageService]를 통해 SharedPreferences에 보존되며,
/// predictCycle()의 dailyUsage 파라미터로 자동 반영된다.
class DailyUsageScreen extends StatefulWidget {
  const DailyUsageScreen({super.key});

  @override
  State<DailyUsageScreen> createState() => _DailyUsageScreenState();
}

class _DailyUsageScreenState extends State<DailyUsageScreen> {
  static const _categories = ['가전/필터', '욕실/위생', '주방/세제', '세탁/청소', '헤어/바디'];

  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final svc = DailyUsageService.instance;
    for (final cat in _categories) {
      final saved = svc.getUiValue(cat);
      _controllers[cat] = TextEditingController(
        text: saved != null ? _fmt(saved) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _save() async {
    setState(() => _saving = true);
    final svc = DailyUsageService.instance;

    for (final cat in _categories) {
      final raw = _controllers[cat]!.text.trim();
      if (raw.isEmpty) {
        await svc.clear(cat);
      } else {
        final val = double.tryParse(raw);
        if (val != null && val > 0) {
          await svc.setUiValue(cat, val);
        }
      }
    }

    // 저장 후 아이템 목록 재로드하여 aiPredictedDays 갱신
    await ItemStore.instance.initialize();

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('사용량 설정이 저장되었습니다'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '일일 사용량 설정',
          style: TextStyle(
            color: AppColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _InfoBanner(),
          const SizedBox(height: 20),
          _sectionLabel('필터류'),
          _categoryCard('가전/필터'),
          const SizedBox(height: 20),
          _sectionLabel('액체류'),
          _categoryCard('주방/세제'),
          _divider(),
          _categoryCard('세탁/청소'),
          _divider(),
          _categoryCard('헤어/바디'),
          const SizedBox(height: 20),
          _sectionLabel('소모품류'),
          _categoryCard('욕실/위생'),
          const SizedBox(height: 32),
          _SaveButton(saving: _saving, onPressed: _save),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 0.5, indent: 52, color: AppColors.border);

  Widget _categoryCard(String category) {
    final svc = DailyUsageService.instance;
    final unit = svc.unitOf(category);
    final defaultVal = svc.defaultUiValue(category);
    final icon = _iconFor(category);

    return Container(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primaryLight2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '미입력 시 기본값 ${_fmt(defaultVal)} $unit 사용',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _controllers[category],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
                  hintText: _fmt(defaultVal),
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSoft,
                  ),
                  suffixText: unit,
                  suffixStyle: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String category) => switch (category) {
    '욕실/위생' => Icons.bathroom_outlined,
    '주방/세제' => Icons.kitchen_outlined,
    '세탁/청소' => Icons.local_laundry_service_outlined,
    '헤어/바디' => Icons.shower_outlined,
    '가전/필터' => Icons.air_outlined,
    _ => Icons.category_outlined,
  };
}

class _InfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '사용량을 입력하면 AI 교체 주기 예측이 더 정확해집니다.\n'
              '비워두면 카테고리 기본값이 자동으로 사용됩니다.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primaryDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '저장',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
