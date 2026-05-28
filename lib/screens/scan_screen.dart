import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/item_scope.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';
import 'add_item_screen.dart';

// Step 2: 카메라/앨범 선택 → Step 3: API 호출 → Step 4: 파싱 결과 표시
enum ScanState { idle, preview, processing, result }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.targetScope = const ItemScope.personal()});

  final ItemScope targetScope;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  ScanState _state = ScanState.idle;
  late AnimationController _pulseController;

  // 선택된 이미지
  Uint8List? _imageBytes;

  // OCR 결과 편집용 컨트롤러 (Step 5)
  final TextEditingController _storeCtrl = TextEditingController();
  DateTime _scanDate = DateTime.now();
  final List<_OcrItemEntry> _ocrItems = [];
  bool _isSaving = false;

  // 오류 메시지
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
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

  // ────────────────────────────────────────────────────────────────────────────
  // Step 2: 이미지 선택
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    final bytes = await OcrService.pickFromGallery();
    if (bytes != null) _onImageSelected(bytes);
  }

  Future<void> _pickFromCamera() async {
    final bytes = await OcrService.pickFromCamera();
    if (bytes != null) _onImageSelected(bytes);
  }

  void _onImageSelected(Uint8List bytes) {
    setState(() {
      _imageBytes = bytes;
      _state = ScanState.preview;
      _errorMessage = null;
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 3 & 4: Vision API 호출 + Regex 파싱
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _startOcr() async {
    if (_imageBytes == null) return;
    setState(() {
      _state = ScanState.processing;
      _errorMessage = null;
    });

    // Gemini 멀티모달 우선 (이미지 → OCR + 파싱 단일 호출)
    // 실패 시 Vision API + Regex fallback
    OcrResult? result = await OcrService.analyzeImage(_imageBytes!);

    if (result == null) {
      final rawText = await OcrService.extractText(_imageBytes!);
      if (rawText == null || rawText.trim().isEmpty) {
        setState(() {
          _state = ScanState.preview;
          _errorMessage = 'OCR 인식에 실패했습니다. API 키를 확인하거나 다른 이미지를 선택해주세요.';
        });
        return;
      }
      result = await OcrService.parseReceiptText(rawText);
    }

    // Step 5: 추출된 데이터를 편집 컨트롤러에 매핑
    _storeCtrl.text = result.storeName;
    _scanDate = result.date ?? DateTime.now();

    for (final item in _ocrItems) {
      item.dispose();
    }
    _ocrItems.clear();

    if (result.items.isNotEmpty) {
      for (final item in result.items) {
        _ocrItems.add(_OcrItemEntry(item.name, item.price));
      }
    } else {
      // 상품을 찾지 못하면 빈 항목 1개 제공
      _ocrItems.add(_OcrItemEntry('', 0));
    }

    setState(() {
      _state = ScanState.result;
      _errorMessage = result!.items.isEmpty
          ? '상품을 자동 인식하지 못했습니다. 직접 입력해주세요.'
          : null;
    });
  }

  void _resetToIdle() {
    for (final item in _ocrItems) {
      item.dispose();
    }
    _ocrItems.clear();
    setState(() {
      _imageBytes = null;
      _state = ScanState.idle;
      _errorMessage = null;
      _storeCtrl.clear();
      _scanDate = DateTime.now();
    });
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Step 5: 결과 → AddItemScreen 순차 이동
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _confirmAndSave() async {
    setState(() => _isSaving = true);
    try {
      for (final ocrItem in _ocrItems) {
        final priceStr = ocrItem.priceCtrl.text.replaceAll(
          RegExp(r'[^0-9]'),
          '',
        );
        final price = int.tryParse(priceStr);
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
      if (mounted) _resetToIdle();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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

  // ────────────────────────────────────────────────────────────────────────────
  // Build
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: switch (_state) {
        ScanState.idle => _buildIdle(),
        ScanState.preview => _buildPreview(),
        ScanState.processing => _buildProcessing(),
        ScanState.result => _buildResult(),
      },
    );
  }

  // ── idle: 카메라 / 앨범 선택 화면 ──────────────────────────────────────────

  Widget _buildIdle() {
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
          '영수증 사진을 찍거나 앨범에서 선택하세요',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        _buildScopeBanner(),
        const SizedBox(height: 32),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 카메라 버튼 (웹에서는 브라우저 카메라 사용)
                _sourceButton(
                  icon: Icons.camera_alt_outlined,
                  label: '카메라로 촬영',
                  subtitle: '카메라를 열어 영수증을 촬영합니다',
                  onTap: _pickFromCamera,
                ),
                const SizedBox(height: 16),
                _sourceButton(
                  icon: Icons.photo_library_outlined,
                  label: '앨범에서 선택',
                  subtitle: '갤러리에서 영수증 사진을 선택합니다',
                  onTap: _pickFromGallery,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLight),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Google Cloud Vision API로 제품명·날짜·가격을 자동 추출합니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScopeBanner() {
    if (!widget.targetScope.isGroup) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primaryLight2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primaryLight, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.group_outlined,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.targetScope.label}에 스캔 추가',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primaryLight2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ── preview: 선택된 이미지 미리보기 + 분석 시작 ────────────────────────────

  Widget _buildPreview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _resetToIdle,
              ),
              Text('이미지 확인', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetToIdle,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('다시 선택'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _startOcr,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('OCR 분석 시작'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── processing: 로딩 애니메이션 ───────────────────────────────────────────

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
            'Google Cloud Vision OCR로 텍스트를 추출하고 있습니다',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── result: 파싱 결과 편집 ────────────────────────────────────────────────

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
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
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
                // 구매일
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
                              '${_scanDate.year}.'
                              '${_scanDate.month.toString().padLeft(2, '0')}.'
                              '${_scanDate.day.toString().padLeft(2, '0')}',
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
                // 상품 목록
                ...List.generate(_ocrItems.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            _ocrItems[i].dispose();
                            _ocrItems.removeAt(i);
                          }),
                          child: const Icon(
                            Icons.remove_circle_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
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
                            decoration: _compactDecoration(hint: '상품명'),
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
                // 상품 추가 버튼
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _ocrItems.add(_OcrItemEntry('', 0))),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('상품 추가', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const Divider(height: 16, color: AppColors.border),
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
            '상품 ${_ocrItems.length}개를 순서대로 검수 후 각각 저장합니다.',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_isSaving || _ocrItems.isEmpty)
                  ? null
                  : _confirmAndSave,
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
              onPressed: _resetToIdle,
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

  // ────────────────────────────────────────────────────────────────────────────
  // 공통 위젯
  // ────────────────────────────────────────────────────────────────────────────

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

  InputDecoration _compactDecoration({String? hint, String? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
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
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write(',');
      buf.write(str[i]);
    }
    return '$buf원';
  }
}

// ────────────────────────────────────────────────────────────────────────────
// OCR 결과 아이템 편집용 내부 모델
// ────────────────────────────────────────────────────────────────────────────

class _OcrItemEntry {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;

  _OcrItemEntry(String name, int price)
    : nameCtrl = TextEditingController(text: name),
      priceCtrl = TextEditingController(
        text: price > 0 ? price.toString() : '',
      );

  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
  }
}
