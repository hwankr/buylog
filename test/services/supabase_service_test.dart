import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buylog/services/supabase_service.dart';

class _FailingImageStorageGateway implements ProductImageStorageGateway {
  @override
  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  ) {
    throw StateError('upload failed');
  }

  @override
  String getPublicUrl(String path) => 'https://example.com/$path';
}

class _RecordingImageStorageGateway implements ProductImageStorageGateway {
  String? uploadedPath;
  Uint8List? uploadedBytes;
  FileOptions? uploadedOptions;

  @override
  Future<void> uploadBinary(
    String path,
    Uint8List imageBytes,
    FileOptions fileOptions,
  ) async {
    uploadedPath = path;
    uploadedBytes = imageBytes;
    uploadedOptions = fileOptions;
  }

  @override
  String getPublicUrl(String path) => 'https://cdn.example.com/$path';
}

void main() {
  group('SupabaseService.uploadItemImage', () {
    tearDown(() {
      SupabaseService.debugImageStorageGateway = null;
    });

    test('propagates upload failures instead of returning null', () async {
      SupabaseService.debugImageStorageGateway = _FailingImageStorageGateway();

      await expectLater(
        SupabaseService.uploadItemImage(
          imageBytes: Uint8List.fromList([1, 2, 3]),
          itemId: 'item-1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'uploads item images under the stable items path and returns public URL',
      () async {
        final gateway = _RecordingImageStorageGateway();
        SupabaseService.debugImageStorageGateway = gateway;
        final bytes = Uint8List.fromList([255, 216, 255, 217]);

        final url = await SupabaseService.uploadItemImage(
          imageBytes: bytes,
          itemId: 'item-1',
        );

        expect(gateway.uploadedPath, 'items/item-1.jpg');
        expect(gateway.uploadedBytes, bytes);
        expect(gateway.uploadedOptions?.upsert, isTrue);
        expect(gateway.uploadedOptions?.contentType, 'image/jpeg');
        expect(url, 'https://cdn.example.com/items/item-1.jpg');
      },
    );
  });
}
