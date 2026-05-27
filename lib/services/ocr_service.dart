import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'camera_picker.dart';

/// OCR 파싱 결과 — 영수증 한 장에서 추출된 구조화 데이터
class OcrResult {
  final String storeName;
  final DateTime? date;
  final List<OcrItem> items;
  final String rawText;

  const OcrResult({
    required this.storeName,
    this.date,
    required this.items,
    required this.rawText,
  });
}

/// 영수증 한 줄에서 추출된 상품 + 가격
class OcrItem {
  final String name;
  final int price;

  const OcrItem({required this.name, required this.price});
}

class OcrService {
  static const _visionUrl = 'https://vision.googleapis.com/v1/images:annotate';

  // ────────────────────────────────────────────────────────────────────────────
  // 이미지 선택 (Step 2)
  // ────────────────────────────────────────────────────────────────────────────

  /// 기기 앨범에서 이미지 선택
  static Future<Uint8List?> pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    return file == null ? null : await file.readAsBytes();
  }

  /// 카메라로 촬영
  /// 웹: getUserMedia로 실제 카메라 오버레이 표시
  /// 네이티브: image_picker 카메라 사용
  static Future<Uint8List?> pickFromCamera() async {
    if (kIsWeb) return pickFromCameraWeb();
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    return file == null ? null : await file.readAsBytes();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Gemini 멀티모달 — 이미지 → OCR + 파싱 단일 호출 (메인 경로)
  // ────────────────────────────────────────────────────────────────────────────

  static const _geminiVisionUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const _geminiPrompt = '''
이 영수증 이미지에서 구매 정보를 추출하세요.

중요 규칙:
1. items에는 영수증에 인쇄된 모든 단품 상품을 빠짐없이 포함하세요.
2. 합계·소계·결제금액·부가세·봉사료·포인트·할인금액은 items에서 제외하세요.
3. 수량(예: 2개×3,000원)이 있으면 각 상품의 실제 결제 금액(6,000원)을 price로 사용하세요.
4. 상품명은 영수증에 표시된 그대로 사용하세요 (브랜드명 포함).
5. price는 정수(원 단위)만, 쉼표·원 기호 없이.
6. date는 YYYY-MM-DD 형식, 날짜가 없으면 null.
7. 영수증이 아닌 이미지면 items를 빈 배열로.
''';

  // responseSchema: Gemini가 JSON 구조를 절대 어기지 않도록 강제
  static const _responseSchema = {
    'type': 'object',
    'properties': {
      'storeName': {'type': 'string'},
      'date': {'type': 'string', 'nullable': true},
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'price': {'type': 'integer'},
          },
          'required': ['name', 'price'],
        },
      },
    },
    'required': ['storeName', 'items'],
  };

  /// 이미지를 Gemini에 직접 전송해 OCR + 파싱을 한 번에 처리
  static Future<OcrResult?> analyzeImage(Uint8List imageBytes) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    try {
      final mimeType = _detectMimeType(imageBytes);
      final response = await http.post(
        Uri.parse('$_geminiVisionUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'inlineData': {
                    'mimeType': mimeType,
                    'data': base64Encode(imageBytes),
                  },
                },
                {'text': _geminiPrompt},
              ],
            },
          ],
          'generationConfig': {
            'temperature': 0,
            'maxOutputTokens': 2048,
            'responseMimeType': 'application/json',
            'responseSchema': _responseSchema,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[OCR] Gemini Vision 오류 ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;

      final parsed = jsonDecode(text) as Map<String, dynamic>;
      final storeName = (parsed['storeName'] as String?) ?? '';
      final date = _parseFlexibleDate(parsed['date'] as String?);
      final itemsJson = parsed['items'] as List<dynamic>? ?? [];
      final items = itemsJson
          .map(
            (e) => OcrItem(
              name: (e['name'] as String?) ?? '',
              price: (e['price'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((i) => i.name.isNotEmpty && i.price > 0)
          .toList();

      debugPrint(
        '[OCR] Gemini Vision 완료 — 매장: $storeName | 날짜: $date | 상품: ${items.length}개',
      );
      return OcrResult(
        storeName: storeName,
        date: date,
        items: items,
        rawText: '',
      );
    } catch (e) {
      debugPrint('[OCR] Gemini Vision 예외: $e');
      return null;
    }
  }

  /// 이미지 바이트로 MIME 타입 감지
  static String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return 'image/jpeg';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Google Cloud Vision API 호출 (fallback)
  // ────────────────────────────────────────────────────────────────────────────

  /// 이미지 바이트를 Vision API에 전송하고 인식된 전체 텍스트를 반환
  static Future<String?> extractText(Uint8List imageBytes) async {
    final apiKey = dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'your_google_cloud_vision_api_key_here') {
      debugPrint('[OCR] GOOGLE_CLOUD_VISION_API_KEY가 .env에 설정되지 않았습니다.');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$_visionUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Encode(imageBytes)},
              'features': [
                {'type': 'TEXT_DETECTION', 'maxResults': 1},
              ],
              'imageContext': {
                'languageHints': ['ko', 'en'],
              },
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final annotations = data['responses']?[0]?['textAnnotations'] as List?;
        if (annotations != null && annotations.isNotEmpty) {
          final text = annotations[0]['description'] as String?;
          debugPrint('[OCR] 텍스트 추출 완료 (${text?.length ?? 0}자)');
          return text;
        }
        debugPrint('[OCR] 텍스트를 찾을 수 없습니다.');
        return null;
      } else {
        debugPrint(
          '[OCR] Vision API 오류 ${response.statusCode}: ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('[OCR] 네트워크 오류: $e');
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // 파싱 (Step 4) — Gemini 우선, 실패 시 Regex fallback
  // ────────────────────────────────────────────────────────────────────────────

  /// 영수증 rawText에서 매장명 · 날짜 · 상품 목록 추출
  static Future<OcrResult> parseReceiptText(String rawText) async {
    // Gemini로 먼저 시도
    final geminiResult = await _parseWithGemini(rawText);
    if (geminiResult != null) return geminiResult;

    // Gemini 실패 시 Regex fallback
    debugPrint('[OCR] Gemini 실패 → Regex fallback');
    return _parseWithRegex(rawText);
  }

  // ── Gemini 파싱 ────────────────────────────────────────────────────────────

  static const _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static Future<OcrResult?> _parseWithGemini(String rawText) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint('[OCR] GEMINI_API_KEY 미설정 — Regex fallback');
      return null;
    }

    const prompt = '''
다음은 OCR로 추출한 영수증 텍스트입니다.
아래 JSON 형식으로 정보를 추출하세요. 반드시 JSON만 출력하고 다른 설명은 쓰지 마세요.

{
  "storeName": "매장명 (없으면 빈 문자열)",
  "date": "YYYY-MM-DD (없으면 null)",
  "items": [
    {"name": "상품명", "price": 숫자(원 단위, 정수)}
  ]
}

규칙:
- items에는 실제 구매 상품만 포함 (합계/소계/결제금액/부가세 제외)
- price는 쉼표·원 기호 없이 숫자만
- 상품명이 불분명하면 그대로 기록
''';

    try {
      final response = await http.post(
        Uri.parse('$_geminiUrl?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$prompt\n\n영수증 텍스트:\n$rawText'},
              ],
            },
          ],
          'generationConfig': {'temperature': 0, 'maxOutputTokens': 1024},
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          '[OCR] Gemini API 오류 ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;

      // ```json ... ``` 코드블록 제거
      final jsonStr = text
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

      final storeName = (parsed['storeName'] as String?) ?? '';
      final date = _parseFlexibleDate(parsed['date'] as String?);

      final itemsJson = parsed['items'] as List<dynamic>? ?? [];
      final items = itemsJson
          .map(
            (e) => OcrItem(
              name: (e['name'] as String?) ?? '',
              price: (e['price'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((i) => i.name.isNotEmpty && i.price > 0)
          .toList();

      debugPrint(
        '[OCR] Gemini 파싱 완료 — 매장: $storeName | 날짜: $date | 상품: ${items.length}개',
      );
      return OcrResult(
        storeName: storeName,
        date: date,
        items: items,
        rawText: rawText,
      );
    } catch (e) {
      debugPrint('[OCR] Gemini 파싱 예외: $e');
      return null;
    }
  }

  // ── Regex fallback 파싱 ───────────────────────────────────────────────────

  static OcrResult _parseWithRegex(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final date = _extractDate(lines);
    final storeName = _extractStoreName(lines);
    final items = _extractItems(lines);

    debugPrint(
      '[OCR] Regex 파싱 결과 — 매장: $storeName | 날짜: $date | 상품: ${items.length}개',
    );
    return OcrResult(
      storeName: storeName,
      date: date,
      items: items,
      rawText: rawText,
    );
  }

  /// 날짜 패턴 추출
  /// 지원 형식: 2026.04.08 / 2026-04-08 / 2026/04/08 / 26.04.08 / 2026년 4월 8일
  static DateTime? _extractDate(List<String> lines) {
    final patterns = [
      RegExp(r'(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})'),
      RegExp(r'(\d{4})년\s*(\d{1,2})월\s*(\d{1,2})일'),
      RegExp(r'(\d{2})[.\-/](\d{1,2})[.\-/](\d{1,2})'),
    ];

    for (final line in lines) {
      for (final pattern in patterns) {
        final m = pattern.firstMatch(line);
        if (m == null) continue;
        try {
          int year = int.parse(m.group(1)!);
          if (year < 100) year += 2000;
          final month = int.parse(m.group(2)!);
          final day = int.parse(m.group(3)!);
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// 매장명 추출 — 첫 5줄 중 한글 2자 이상이고 상품라인/헤더키워드가 아닌 첫 줄
  static String _extractStoreName(List<String> lines) {
    final koreanWord = RegExp(r'[가-힣]{2,}');
    // 영수증 헤더에 나타나는 레이블 단어 — 매장명이 아님
    final headerKeyword = RegExp(
      r'^(날짜|시간|일시|번호|주소|tel|fax|사업자|대표|전화|영수|receipt|date|time)',
      caseSensitive: false,
    );
    for (final line in lines.take(5)) {
      if (koreanWord.hasMatch(line) &&
          !_looksLikeProductLine(line) &&
          !headerKeyword.hasMatch(line.trim())) {
        return line.replaceAll(RegExp(r'[*=\-_]{2,}'), '').trim();
      }
    }
    return '';
  }

  /// 상품 + 가격 라인 추출
  /// 패턴 A: "[상품명] [숫자]" (같은 줄)
  /// 패턴 B: "[상품명]" 바로 다음 줄에 "[숫자만]" (교차 배치)
  /// 패턴 C: [상품명 블록] 다음에 [가격 블록] (컬럼 분리 OCR)
  static List<OcrItem> _extractItems(List<String> lines) {
    final priceAtEnd = RegExp(r'(\d{1,3}(?:,\d{3})+|\d{3,})\s*원?\s*$');
    final priceOnly = RegExp(r'^\s*(\d{1,3}(?:,\d{3})+|\d{3,})\s*원?\s*$');
    final hasKorLat = RegExp(r'[가-힣a-zA-Z]');

    final skipPattern = RegExp(
      r'합\s*계|소\s*계|총\s*계|결\s*제|카\s*드|현\s*금|거스름|부가세|vat|'
      r'영수|번호|주소|사업자|대표|tel|fax|환불|포인트|적립|할인|봉사|배달',
      caseSensitive: false,
    );

    final items = <OcrItem>[];
    final usedIdx = <int>{};

    String cleanName(String raw) => raw
        .replaceAll(RegExp(r'\s*[xX×]\s*\d+\s*$'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    int? parsePrice(String s) {
      final v = int.tryParse(s.replaceAll(',', ''));
      return (v != null && v >= 100 && v <= 10000000) ? v : null;
    }

    // ── 패턴 A: 같은 줄 ──────────────────────────────────────────────
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (skipPattern.hasMatch(line)) continue;
      final m = priceAtEnd.firstMatch(line);
      if (m == null) continue;
      final price = parsePrice(m.group(1)!);
      if (price == null) continue;
      final nameRaw = line.substring(0, m.start).trim();
      if (nameRaw.length < 2 || !hasKorLat.hasMatch(nameRaw)) continue;
      final name = cleanName(nameRaw);
      if (name.isNotEmpty) {
        items.add(OcrItem(name: name, price: price));
        usedIdx.add(i);
      }
    }

    // ── 패턴 B: 상품명 줄 바로 다음 줄이 가격만 ────────────────────
    for (int i = 0; i < lines.length - 1; i++) {
      if (usedIdx.contains(i)) continue;
      final line = lines[i];
      if (skipPattern.hasMatch(line) || !hasKorLat.hasMatch(line)) continue;
      final nextLine = lines[i + 1];
      if (usedIdx.contains(i + 1)) continue;
      final pm = priceOnly.firstMatch(nextLine);
      if (pm == null) continue;
      final price = parsePrice(pm.group(1)!);
      if (price == null) continue;
      final name = cleanName(line);
      if (name.length >= 2) {
        items.add(OcrItem(name: name, price: price));
        usedIdx.addAll([i, i + 1]);
        i++;
      }
    }

    // ── 패턴 C: 이름 블록 + 가격 블록 (컬럼 분리) ───────────────────
    // 미사용 줄만 추려서 연속된 이름 블록 / 가격 블록을 찾아 대응
    if (items.isEmpty) {
      final nameBlock = <int>[];
      final priceBlock = <int>[];
      for (int i = 0; i < lines.length; i++) {
        if (usedIdx.contains(i)) continue;
        final line = lines[i];
        if (skipPattern.hasMatch(line)) continue;
        if (priceOnly.hasMatch(line)) {
          final pm = priceOnly.firstMatch(line)!;
          if (parsePrice(pm.group(1)!) != null) priceBlock.add(i);
        } else if (hasKorLat.hasMatch(line) &&
            !priceAtEnd.hasMatch(line) &&
            line.length >= 2) {
          nameBlock.add(i);
        }
      }
      if (nameBlock.isNotEmpty &&
          priceBlock.isNotEmpty &&
          nameBlock.length == priceBlock.length) {
        for (int k = 0; k < nameBlock.length; k++) {
          final name = cleanName(lines[nameBlock[k]]);
          final pm = priceOnly.firstMatch(lines[priceBlock[k]])!;
          final price = parsePrice(pm.group(1)!);
          if (name.length >= 2 && price != null) {
            items.add(OcrItem(name: name, price: price));
          }
        }
      }
    }

    return items;
  }

  /// 가격이 포함된 상품 라인인지 판별 (매장명 추출 시 제외용)
  static bool _looksLikeProductLine(String line) {
    return RegExp(r'\d{3,}').hasMatch(line);
  }

  /// LLM이 반환하는 날짜 문자열을 유연하게 파싱
  /// 지원: "2026-04-08", "2026.04.08", "2026/04/08", "2026년 4월 8일"
  static DateTime? _parseFlexibleDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    // ISO 형식은 그대로 시도
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    // 구분자 변환 후 재시도
    final normalized = raw
        .replaceAll(RegExp(r'[./년]'), '-')
        .replaceAll(RegExp(r'[월일\s]'), '')
        .trim();
    return DateTime.tryParse(normalized);
  }
}
