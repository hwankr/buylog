import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item.dart';
import '../models/item_scope.dart';
import '../services/ai/category_defaults.dart';
import '../services/group_store.dart';
import '../services/supabase_service.dart';
import '../services/item_store.dart';
import '../theme/app_theme.dart';

/// OCR 스캔 결과에서 전달받는 사전 입력 데이터
class OcrPrefillData {
  final String? productName;
  final String? brandName;
  final int? price;
  final String? storeName;
  final DateTime? purchaseDate;

  const OcrPrefillData({
    this.productName,
    this.brandName,
    this.price,
    this.storeName,
    this.purchaseDate,
  });
}

/// 수동 제품 등록 및 구매 이력 입력 화면
///
/// [prefillData]  OCR 스캔 결과에서 전달받은 사전 입력 데이터 (선택)
/// [editItem]     편집할 기존 제품 (null이면 신규 등록 모드)
/// [isOcrReview]  true이면 AppBar 타이틀이 'OCR 결과 검수'로 표시됨
class AddItemScreen extends StatefulWidget {
  final OcrPrefillData? prefillData;
  final ConsumableItem? editItem;
  final bool isOcrReview;
  final ItemScope? targetScope;

  const AddItemScreen({
    super.key,
    this.prefillData,
    this.editItem,
    this.isOcrReview = false,
    this.targetScope,
  });

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // 기본 정보 컨트롤러
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _cycleDaysCtrl;
  String _selectedCategory = categoryDefaultDays.keys.first;
  late ItemScope _selectedScope;

  // 구매 이력 목록
  final List<_PurchaseEntry> _purchases = [];

  // 이미지 상태
  Uint8List? _imageBytes; // 새로 선택한 이미지 bytes
  bool _isSaving = false;

  bool get _hasImageSelected =>
      _imageBytes != null || (_isEditing && widget.editItem!.imageUrl != null);

  bool get _isEditing => widget.editItem != null;

  bool get _canChangeScope => !_isEditing;

  ItemScope get _initialScope {
    final explicit = widget.targetScope;
    if (explicit != null) return explicit;

    final editGroupId = widget.editItem?.groupId;
    if (editGroupId != null && editGroupId.isNotEmpty) {
      return ItemScope.group(id: editGroupId, label: '그룹');
    }

    return const ItemScope.personal();
  }

  ItemScope get _effectiveScope {
    if (_isEditing) return _initialScope;
    return _selectedScope;
  }

  @override
  void initState() {
    super.initState();
    _selectedScope = _initialScope;
    final edit = widget.editItem;
    final p = widget.prefillData;

    if (edit != null) {
      // 편집 모드: 기존 제품 데이터로 초기화
      _nameCtrl = TextEditingController(text: edit.name);
      _brandCtrl = TextEditingController(text: edit.brand);
      // 기존 카테고리가 드롭다운 목록에 없으면 첫 번째 항목으로 폴백
      _selectedCategory = categoryDefaultDays.containsKey(edit.category)
          ? edit.category
          : categoryDefaultDays.keys.first;
      _cycleDaysCtrl = TextEditingController(text: edit.cycleDays.toString());
      for (final r in edit.purchaseHistory) {
        _purchases.add(
          _PurchaseEntry(
            id: r.id,
            date: r.date,
            priceCtrl: TextEditingController(text: r.price.toString()),
            storeCtrl: TextEditingController(text: r.store),
          ),
        );
      }
    } else {
      // 신규 등록 모드: OCR 데이터 또는 빈 값으로 초기화
      _nameCtrl = TextEditingController(text: p?.productName ?? '');
      _brandCtrl = TextEditingController(text: p?.brandName ?? '');
      _cycleDaysCtrl = TextEditingController(
        text: getDefaultDays(_selectedCategory).toString(),
      );
      // 구매 이력 1건 기본 표시 (가격 입력 유도)
      _purchases.add(
        _PurchaseEntry(
          date: p?.purchaseDate ?? DateTime.now(),
          priceCtrl: TextEditingController(text: p?.price?.toString() ?? ''),
          storeCtrl: TextEditingController(text: p?.storeName ?? ''),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _cycleDaysCtrl.dispose();
    for (final e in _purchases) {
      e.priceCtrl.dispose();
      e.storeCtrl.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 카테고리 변경 시 교체 주기 기본값 자동 입력
  // ---------------------------------------------------------------------------
  void _onCategoryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedCategory = value;
      _cycleDaysCtrl.text = getDefaultDays(value).toString();
    });
  }

  // ---------------------------------------------------------------------------
  // 날짜 선택기 (Flutter 내장 showDatePicker - 웹/모바일 공통 지원)
  // ---------------------------------------------------------------------------
  Future<void> _pickDate(int index) async {
    final entry = _purchases[index];
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.date,
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
      setState(() => _purchases[index] = entry.copyWith(date: picked));
    }
  }

  // ---------------------------------------------------------------------------
  // 구매 이력 추가 / 삭제
  // ---------------------------------------------------------------------------
  void _addPurchaseEntry() {
    setState(() {
      _purchases.add(
        _PurchaseEntry(
          date: DateTime.now(),
          priceCtrl: TextEditingController(),
          storeCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removePurchaseEntry(int index) {
    setState(() {
      final entry = _purchases.removeAt(index);
      entry.priceCtrl.dispose();
      entry.storeCtrl.dispose();
    });
  }

  // ---------------------------------------------------------------------------
  // 이미지 선택 (image_picker — 웹/모바일 공통)
  // ---------------------------------------------------------------------------
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  List<ItemScope> _scopeOptions(GroupState state) {
    final options = <ItemScope>[
      const ItemScope.personal(),
      ...state.availableGroupScopes,
    ];

    final selectedAlreadyIncluded = options.any(
      (scope) => scope.storageKey == _selectedScope.storageKey,
    );
    if (!selectedAlreadyIncluded && _selectedScope.isGroup) {
      options.add(_selectedScope);
    }

    return options;
  }

  // ---------------------------------------------------------------------------
  // 등록 완료 제출
  // ---------------------------------------------------------------------------
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      // 편집 모드면 기존 id 유지, 신규면 Supabase용 UUID 생성
      final itemId = _isEditing
          ? widget.editItem!.id
          : SupabaseService.generateUuid();

      // 새로 선택한 이미지가 있으면 Supabase Storage에 업로드
      String? imageUrl = _isEditing ? widget.editItem!.imageUrl : null;
      if (_imageBytes != null) {
        imageUrl = await SupabaseService.uploadItemImage(
          imageBytes: _imageBytes!,
          itemId: itemId,
        );
      }

      // _purchases가 UI의 단일 진실 공급원 — 기존 id 보존, 신규는 null
      final purchases = _purchases
          .where((e) => e.priceCtrl.text.trim().isNotEmpty)
          .map(
            (e) => PurchaseRecord(
              id: e.id,
              date: e.date,
              price:
                  int.tryParse(
                    e.priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
                  ) ??
                  0,
              store: e.storeCtrl.text.trim(),
            ),
          )
          .toList();

      final cycleDays =
          int.tryParse(_cycleDaysCtrl.text) ??
          getDefaultDays(_selectedCategory);

      // 편집 시 UI에서 삭제된 구매 이력을 DB에서도 제거
      if (_isEditing) {
        final originalIds = widget.editItem!.purchaseHistory
            .where((r) => r.id != null)
            .map((r) => r.id!)
            .toSet();
        final keepIds = purchases
            .where((r) => r.id != null)
            .map((r) => r.id!)
            .toSet();
        final deletedIds = originalIds.difference(keepIds);
        if (deletedIds.isNotEmpty) {
          await SupabaseService.deletePurchases(deletedIds);
        }
      }

      // 신규 등록 시 동일 이름 제품이 있으면 병합 여부 확인
      if (!_isEditing) {
        final duplicate = ItemStore.instance.findDuplicateByName(
          _nameCtrl.text,
          scope: _effectiveScope,
        );

        if (duplicate != null && mounted) {
          final shouldMerge = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('동일 제품 발견'),
              content: Text(
                "'${duplicate.name}'이(가) 이미 등록되어 있습니다.\n구매 이력을 기존 제품에 추가하시겠습니까?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('새로 등록'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('이력 추가'),
                ),
              ],
            ),
          );

          if (shouldMerge == true) {
            final newPurchases = purchases
                .map(
                  (p) => PurchaseRecord(
                    date: p.date,
                    price: p.price,
                    store: p.store,
                  ),
                )
                .toList();
            final merged = ConsumableItem(
              id: duplicate.id,
              name: duplicate.name,
              brand: duplicate.brand,
              category: duplicate.category,
              icon: duplicate.icon,
              daysRemaining: duplicate.daysRemaining,
              cycleDays: duplicate.cycleDays,
              progress: duplicate.progress,
              aiPredictedDays: duplicate.aiPredictedDays,
              aiConfidence: duplicate.aiConfidence,
              imageUrl: imageUrl ?? duplicate.imageUrl,
              purchaseHistory: [...duplicate.purchaseHistory, ...newPurchases],
            );
            await ItemStore.instance.update(merged, scope: _effectiveScope);
            if (mounted) {
              Navigator.pop(context, true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${duplicate.name}에 구매 이력이 추가되었습니다!'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: AppColors.success,
                ),
              );
            }
            return;
          }
        }
      }

      final item = ConsumableItem(
        id: itemId,
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        category: _selectedCategory,
        icon: _categoryIcon(_selectedCategory),
        daysRemaining: cycleDays,
        cycleDays: cycleDays,
        progress: _isEditing ? widget.editItem!.progress : 0.0,
        aiPredictedDays: _isEditing ? widget.editItem!.aiPredictedDays : null,
        aiConfidence: _isEditing ? widget.editItem!.aiConfidence : null,
        imageUrl: imageUrl,
        purchaseHistory: purchases,
      );

      // Supabase 저장 + 인메모리 스토어 반영
      if (_isEditing) {
        await ItemStore.instance.update(item, scope: _effectiveScope);
      } else {
        await ItemStore.instance.add(item, scope: _effectiveScope);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? '${item.name} 수정 완료!' : '${item.name} 등록 완료!',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isOcrReview
              ? 'OCR 결과 검수'
              : _isEditing
              ? '제품 수정'
              : '제품 등록',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_effectiveScope.isGroup) ...[
                _buildScopeBanner(),
                const SizedBox(height: 20),
              ],
              if (widget.isOcrReview) ...[
                _buildOcrBanner(),
                const SizedBox(height: 20),
              ],
              _sectionTitle('제품 이미지'),
              const SizedBox(height: 12),
              _buildImagePicker(),
              const SizedBox(height: 24),
              _buildScopeToggle(),
              _sectionTitle('기본 정보'),
              const SizedBox(height: 12),
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _sectionTitle('구매 이력'),
              const SizedBox(height: 4),
              Text(
                '구매 이력을 추가하면 AI 교체 예측 정확도가 높아집니다.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              _buildPurchaseSection(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ---------------------------------------------------------------------------
  // 섹션 공통 위젯
  // ---------------------------------------------------------------------------

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }

  Widget _buildScopeBanner() {
    final scope = _effectiveScope;
    if (!scope.isGroup) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.group_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${scope.label}에 추가 중',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.document_scanner_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'OCR로 추출된 정보입니다. 내용을 확인 후 수정해주세요.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 이미지 선택 영역
  // ---------------------------------------------------------------------------

  Widget _buildImagePicker() {
    // 표시 우선순위: 새로 선택한 bytes > 기존 URL > 빈 상태
    final existingUrl = _isEditing ? widget.editItem!.imageUrl : null;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 160,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _hasImageSelected
              ? AppColors.primaryLight2
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _hasImageSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: _imageBytes != null
            // 새로 선택한 이미지 프리뷰
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(_imageBytes!, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Text(
                        '탭하여 변경',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            : existingUrl != null
            // 기존 등록된 이미지 URL 프리뷰
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(existingUrl, fit: BoxFit.cover),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black45,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Text(
                        '탭하여 변경',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            // 미선택 상태
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 36,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 10),
                  Text(
                    '제품 이미지 선택',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '탭하여 갤러리에서 선택 (선택 사항)',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildScopeToggle() {
    if (!_canChangeScope) return const SizedBox.shrink();

    return ValueListenableBuilder<GroupState>(
      valueListenable: GroupStore.instance,
      builder: (context, state, _) {
        final options = _scopeOptions(state);
        if (options.length <= 1) {
          return const SizedBox.shrink();
        }

        return Column(
          key: const ValueKey('add_item_scope_toggle'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '등록 위치',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final scope in options)
                  ChoiceChip(
                    key: ValueKey('add_item_scope_${scope.storageKey}'),
                    label: Text(scope.label),
                    selected: scope.storageKey == _selectedScope.storageKey,
                    onSelected: (_) {
                      setState(() {
                        _selectedScope = scope;
                      });
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: scope.storageKey == _selectedScope.storageKey
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                      side: BorderSide(
                        color: scope.storageKey == _selectedScope.storageKey
                            ? AppColors.primary
                            : AppColors.border,
                        width: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 기본 정보 섹션
  // ---------------------------------------------------------------------------

  Widget _buildBasicInfoSection() {
    return Column(
      children: [
        _labeledField(
          label: '제품명 *',
          controller: _nameCtrl,
          hint: '예) 정수기 필터',
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? '제품명을 입력해주세요' : null,
        ),
        const SizedBox(height: 14),
        _labeledField(
          label: '브랜드명',
          controller: _brandCtrl,
          hint: '예) 코웨이 (선택)',
        ),
        const SizedBox(height: 14),
        _buildCategoryDropdown(),
        const SizedBox(height: 14),
        _buildCycleDaysField(),
      ],
    );
  }

  Widget _labeledField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: _inputDecoration(hint: hint),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '카테고리 *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        // DropdownButton을 FormField로 감싸 deprecated value 파라미터 사용 회피
        InputDecorator(
          decoration: _inputDecoration(),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isDense: true,
              isExpanded: true,
              items: categoryDefaultDays.keys
                  .map(
                    (cat) => DropdownMenuItem(
                      value: cat,
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(cat),
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _onCategoryChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCycleDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '교체 주기 *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _cycleDaysCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return '교체 주기를 입력해주세요';
                  final n = int.tryParse(v);
                  if (n == null || n <= 0) return '1일 이상 입력해주세요';
                  return null;
                },
                style: const TextStyle(fontSize: 15, color: AppColors.text),
                decoration: _inputDecoration(hint: '30'),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: const Text(
                '일',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '카테고리 선택 시 기본값이 자동 입력됩니다.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 구매 이력 섹션
  // ---------------------------------------------------------------------------

  Widget _buildPurchaseSection() {
    return Column(
      children: [
        ..._purchases.asMap().entries.map(
          (entry) => _buildPurchaseEntry(entry.key),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addPurchaseEntry,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('구매 이력 추가'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseEntry(int index) {
    final entry = _purchases[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이력 헤더
          Row(
            children: [
              Text(
                '구매 이력 ${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _removePurchaseEntry(index),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 구매일 (Date Picker - Flutter 내장, 웹/모바일 공통)
          const Text(
            '구매일',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 5),
          InkWell(
            onTap: () => _pickDate(index),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(entry.date),
                    style: const TextStyle(fontSize: 15, color: AppColors.text),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 가격 + 매장명
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _compactField(
                  label: '가격 (원)',
                  controller: entry.priceCtrl,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _compactField(
                  label: '매장명',
                  controller: entry.storeCtrl,
                  hint: '예) 쿠팡',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: const TextStyle(fontSize: 14, color: AppColors.text),
          decoration: _inputDecoration(
            hint: hint,
            compact: true,
            fillColor: AppColors.surfaceAlt,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 하단 등록 버튼
  // ---------------------------------------------------------------------------

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            _isSaving
                ? '저장 중...'
                : _isEditing
                ? '수정 완료'
                : '등록 완료',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    );
  }

  // ---------------------------------------------------------------------------
  // 공통 InputDecoration
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration({
    String? hint,
    bool compact = false,
    Color fillColor = AppColors.surface,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: compact ? 10 : 12,
      ),
      filled: true,
      fillColor: fillColor,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 헬퍼
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      '욕실/위생' => Icons.bathroom_outlined,
      '주방/세제' => Icons.kitchen_outlined,
      '세탁/청소' => Icons.local_laundry_service_outlined,
      '헤어/바디' => Icons.shower_outlined,
      '가전/필터' => Icons.air_outlined,
      _ => Icons.category_outlined,
    };
  }
}

// ---------------------------------------------------------------------------
// 구매 이력 항목 내부 모델
// ---------------------------------------------------------------------------

class _PurchaseEntry {
  final String? id; // DB에 저장된 기존 이력은 id 보유, 신규는 null
  final DateTime date;
  final TextEditingController priceCtrl;
  final TextEditingController storeCtrl;

  _PurchaseEntry({
    this.id,
    required this.date,
    required this.priceCtrl,
    required this.storeCtrl,
  });

  _PurchaseEntry copyWith({DateTime? date}) {
    return _PurchaseEntry(
      id: id,
      date: date ?? this.date,
      priceCtrl: priceCtrl,
      storeCtrl: storeCtrl,
    );
  }
}
