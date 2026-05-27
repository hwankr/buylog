import 'package:flutter/material.dart';
import '../models/item_scope.dart';
import '../theme/app_theme.dart';
import 'add_item_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.targetScope = const ItemScope.personal()});

  final ItemScope targetScope;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum ScanState { camera, processing, result }

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  ScanState _state = ScanState.camera;
  late AnimationController _pulseController;

  // OCR 결과 상태 (스캔 완료 후 편집 가능)
  final TextEditingController _storeCtrl = TextEditingController(
    text: '이마트 성수점',
  );
  DateTime _scanDate = DateTime(2026, 4, 8);
  final List<_OcrItemEntry> _ocrItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _ocrItems.addAll([
      _OcrItemEntry('정수기 필터 (코웨이)', 35000),
      _OcrItemEntry('주방세제 (퐁퐁)', 4500),
      _OcrItemEntry('세탁세제 (피죤)', 15900),
    ]);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _storeCtrl.dispose();
    for (final item in _ocrItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _startScan() {
    setState(() => _state = ScanState.processing);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _state = ScanState.result);
    });
  }

  void _rescan() {
    setState(() => _state = ScanState.camera);
  }

  Future<void> _pickScanDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scanDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scanDate = picked);
  }

  // 각 OCR 아이템을 AddItemScreen으로 순차 이동하여 저장
  Future<void> _confirmAndSave() async {
    setState(() => _isSaving = true);
    try {
      for (final ocrItem in _ocrItems) {
        final priceText = ocrItem.priceCtrl.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final price = int.tryParse(priceText);
        if (!mounted) break;
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => AddItemScreen(
              targetScope: widget.targetScope,
              prefillData: OcrPrefillData(
                productName: ocrItem.nameCtrl.text.trim(),
                price: price,
                storeName: _storeCtrl.text.trim(),
                purchaseDate: _scanDate,
              ),
              isOcrReview: true,
            ),
          ),
        );
      }
      if (mounted) setState(() => _state = ScanState.camera);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: switch (_state) {
        ScanState.camera => _buildCameraView(),
        ScanState.processing => _buildProcessing(),
        ScanState.result => _buildResult(),
      },
    );
  }

  Widget _buildCameraView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            '영수증 스캔',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '영수증을 프레임 안에 맞춰주세요',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    left: 30,
                    child: _cornerGuide(true, true),
                  ),
                  Positioned(
                    top: 40,
                    right: 30,
                    child: _cornerGuide(true, false),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 30,
                    child: _cornerGuide(false, true),
                  ),
                  Positioned(
                    bottom: 40,
                    right: 30,
                    child: _cornerGuide(false, false),
                  ),
                  const Center(
                    child: Text(
                      '카메라 미리보기',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.document_scanner_outlined, size: 20),
              label: const Text('스캔하기', style: TextStyle(fontSize: 16)),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cornerGuide(bool isTop, bool isLeft) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.9 + _pulseController.value * 0.1,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight2,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20 + _pulseController.value * 10,
                        spreadRadius: _pulseController.value * 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.document_scanner_outlined,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            '영수증 분석 중...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'OCR로 데이터를 추출하고 있습니다',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final total = _ocrItems.fold<int>(0, (sum, e) {
      final t = e.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      return sum + (int.tryParse(t) ?? 0);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text('스캔 완료', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '추출된 데이터를 확인하고 수정해주세요',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              children: [
                // 매장명
                _labeledTextField('매장명', _storeCtrl),
                const SizedBox(height: 14),
                // 구매일 (탭으로 날짜 선택)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '날짜',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickScanDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 15,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_scanDate.year}.${_scanDate.month.toString().padLeft(2, '0')}.${_scanDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 14),
                // 아이템 목록
                ...List.generate(_ocrItems.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.drag_indicator,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _ocrItems[i].nameCtrl,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                            decoration: _compactDecoration(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _ocrItems[i].priceCtrl,
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                            decoration: _compactDecoration(suffix: '원'),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16, color: AppColors.border),
                // 합계
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '합계',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      _formatPrice(total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '아이템 ${_ocrItems.length}개를 순서대로 검수 후 각각 저장합니다.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _confirmAndSave,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.check, size: 20),
              label: Text(
                _isSaving ? '저장 중...' : '확인 및 저장',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _rescan,
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('다시 스캔', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _labeledTextField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _compactDecoration({String? suffix}) {
    return InputDecoration(
      isDense: true,
      suffixText: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  String _formatPrice(int price) {
    final str = price.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '$buffer원';
  }
}

class _OcrItemEntry {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  _OcrItemEntry(String name, int price)
    : nameCtrl = TextEditingController(text: name),
      priceCtrl = TextEditingController(text: price.toString());

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;

  _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
