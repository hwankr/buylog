import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List?> pickFromCameraWeb() async {
  // getUserMedia 지원 확인
  final mediaDevices = web.window.navigator.mediaDevices;
  if (!mediaDevices.isDefinedAndNotNull) {
    return _fileFallback();
  }

  final completer = Completer<Uint8List?>();

  // ── 오버레이 레이아웃 생성 ──────────────────────────────────────────
  final overlay = web.document.createElement('div') as web.HTMLDivElement
    ..style.cssText =
        'position:fixed;top:0;left:0;width:100%;height:100%;'
        'background:#000;z-index:9999;display:flex;'
        'flex-direction:column;align-items:center;justify-content:center;';

  final video = web.document.createElement('video') as web.HTMLVideoElement
    ..autoplay = true
    ..setAttribute('playsinline', 'true')
    ..style.cssText = 'width:100%;max-height:78vh;object-fit:contain;';

  const btnBase =
      'padding:12px 32px;border:none;border-radius:24px;'
      'font-size:16px;font-weight:bold;cursor:pointer;margin:8px;';

  final captureBtn =
      web.document.createElement('button') as web.HTMLButtonElement
        ..innerText = '📸 촬영'
        ..style.cssText = '${btnBase}background:#fff;color:#222;';

  final cancelBtn =
      web.document.createElement('button') as web.HTMLButtonElement
        ..innerText = '취소'
        ..style.cssText =
            '${btnBase}background:rgba(255,255,255,0.2);color:#fff;';

  final btnRow = web.document.createElement('div') as web.HTMLDivElement
    ..style.cssText = 'display:flex;gap:12px;margin-top:12px;';
  btnRow.append(captureBtn);
  btnRow.append(cancelBtn);

  overlay.append(video);
  overlay.append(btnRow);
  web.document.body!.append(overlay);

  // ── 카메라 스트림 연결 ──────────────────────────────────────────────
  web.MediaStream? stream;

  void cleanup() {
    stream?.getTracks().toDart.forEach((t) => t.stop());
    overlay.remove();
  }

  try {
    final constraints = web.MediaStreamConstraints(
      video: {'facingMode': 'environment'}.jsify()!,
      audio: false.toJS,
    );
    stream = await mediaDevices.getUserMedia(constraints).toDart;
    video.srcObject = stream;
  } catch (_) {
    cleanup();
    return _fileFallback();
  }

  // ── 버튼 핸들러 ───────────────────────────────────────────────────
  cancelBtn.addEventListener(
    'click',
    (web.MouseEvent _) {
      cleanup();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS,
  );

  captureBtn.addEventListener(
    'click',
    (web.MouseEvent _) {
      try {
        final canvas =
            web.document.createElement('canvas') as web.HTMLCanvasElement
              ..width = video.videoWidth
              ..height = video.videoHeight;
        (canvas.getContext('2d') as web.CanvasRenderingContext2D).drawImage(
          video,
          0,
          0,
        );
        final dataUrl = canvas.toDataURL('image/jpeg', 0.9.toJS);
        final bytes = base64Decode(dataUrl.split(',')[1]);
        cleanup();
        if (!completer.isCompleted) completer.complete(bytes);
      } catch (_) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }
    }.toJS,
  );

  return completer.future;
}

// getUserMedia 불가 시 파일 피커로 fallback
Future<Uint8List?> _fileFallback() async {
  final completer = Completer<Uint8List?>();

  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'file'
    ..accept = 'image/*'
    ..setAttribute('capture', 'environment')
    ..style.display = 'none';

  web.document.body!.append(input);

  input.addEventListener(
    'change',
    (web.Event _) {
      final files = input.files;
      if (files != null && files.length > 0) {
        final reader = web.FileReader();
        reader.addEventListener(
          'load',
          (web.Event _) {
            final result = reader.result;
            if (result != null) {
              final bytes = Uint8List.fromList(
                (result as JSArrayBuffer).toDart.asUint8List(),
              );
              completer.complete(bytes);
            } else {
              completer.complete(null);
            }
            input.remove();
          }.toJS,
        );
        reader.readAsArrayBuffer(files.item(0)!);
      } else {
        completer.complete(null);
        input.remove();
      }
    }.toJS,
  );

  input.click();
  return completer.future;
}
