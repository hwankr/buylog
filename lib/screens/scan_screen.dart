import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import 'add_item_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum ScanState { camera, processing, result }

// OCR 스캔 결과 항목 (편집 가능)
class _OcrItem {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  _OcrItem(String name, String price)
      : nameCtrl = TextEditingController(text: name),
        priceCtrl = TextEditingController(text: price);

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  ScanState _state = ScanState.camera;
  late AnimationController _pulseController;

  // OCR 결과 상태 (편집 가능한 컨트롤러로 관리)
  late final TextEditingController _storeCtrl;
  DateTime _purchaseDate = DateTime.now();
  late final List<_OcrItem> _ocrItems;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _storeCtrl = TextEditingController(text: '이마트 성수점');
    _purchaseDate = DateTime(2026, 4, 8);
    // 더미 OCR 결과 데이터
    _ocrItems = [
      _OcrItem('정수기 필터 (코웨이)', '35000'),
      _OcrItem('주방세제 (퐁퐁)', '4500'),
      _OcrItem('세탁세제 (피죤)', '15900'),
    ];
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

  // 날짜 선택기 (Flutter 내장 - 웹/모바일 공통 지원)
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  // OCR 항목 1건을 AddItemScreen으로 넘겨 등록
  void _registerItem(int index) {
    final item = _ocrItems[index];
    final price = int.tryParse(
      item.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddItemScreen(
          isOcrReview: true,
          prefillData: OcrPrefillData(
            productName: item.nameCtrl.text.trim(),
            price: price,
            storeName: _storeCtrl.text.trim(),
            purchaseDate: _purchaseDate,
          ),
        ),
      ),
    );
  }

  // OCR 항목 추가
  void _addOcrItem() {
    setState(() => _ocrItems.add(_OcrItem('', '')));
  }

  // OCR 항목 삭제
  void _removeOcrItem(int index) {
    setState(() {
      _ocrItems[index].dispose();
      _ocrItems.removeAt(index);
    });
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddItemScreen(),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('직접 입력', style: TextStyle(fontSize: 15)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
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
    final total = _ocrItems.fold<int>(
      0,
      (sum, item) =>
          sum +
          (int.tryParse(
                item.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
              ) ??
              0),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 24),
              const SizedBox(width: 8),
              Text(
                '스캔 완료',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '추출된 데이터를 확인하고 항목별로 등록해주세요',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          // 영수증 정보 카드
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 매장명
                _editableField('매장명', _storeCtrl),
                const SizedBox(height: 14),

                // 구매일 (Date Picker)
                const Text(
                  '구매일',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
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
                          _formatDate(_purchaseDate),
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.border),
                ),

                // OCR 항목 목록
                const Text(
                  '인식된 제품',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                ..._ocrItems.asMap().entries.map(
                      (e) => _buildOcrItemRow(e.key, e.value),
                    ),

                // 항목 추가 버튼
                TextButton.icon(
                  onPressed: _addOcrItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('항목 추가', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppColors.border),
                ),

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
                      '${_formatPrice(total)}원',
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
          const SizedBox(height: 20),

          // 액션 버튼
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // OCR 항목 행: 이름/가격 편집 + 등록 버튼
  Widget _buildOcrItemRow(int index, _OcrItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 6),
          // 제품명
          Expanded(
            flex: 5,
            child: TextFormField(
              controller: item.nameCtrl,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: _compactInputDecoration(hint: '제품명'),
            ),
          ),
          const SizedBox(width: 8),
          // 가격
          SizedBox(
            width: 80,
            child: TextFormField(
              controller: item.priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              decoration: _compactInputDecoration(hint: '0'),
            ),
          ),
          const SizedBox(width: 8),
          // 등록 버튼
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: () => _registerItem(index),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('등록', style: TextStyle(fontSize: 13)),
            ),
          ),
          const SizedBox(width: 4),
          // 삭제 버튼
          GestureDetector(
            onTap: () => _removeOcrItem(index),
            child: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
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

  InputDecoration _compactInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      isDense: true,
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

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
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
