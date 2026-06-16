import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/vocab/vocab_word.dart';

/// On-device OCR (Google ML Kit) for 단어장 사진 → 단어 추출.
/// Android/iOS only; safe no-op (empty) on web.
class OcrService {
  OcrService._();
  static final ImagePicker _picker = ImagePicker();

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Pick a photo (camera/gallery) → recognize text on-device → parse pairs.
  static Future<List<VocabWord>> scanWords(ImageSource source) async {
    if (!supported) return const [];
    final XFile? file = await _picker.pickImage(source: source, maxWidth: 2200, imageQuality: 92);
    if (file == null) return const [];
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean); // 한글+라틴
    try {
      final input = InputImage.fromFilePath(file.path);
      final result = await recognizer.processImage(input);
      return VocabWord.parseLines(result.text);
    } catch (_) {
      return const [];
    } finally {
      await recognizer.close();
    }
  }

  /// Pick a photo → recognize text on-device → return the RAW recognized text
  /// (줄바꿈 보존). 호출부에서 사용자가 검토·수정한 뒤 카드로 파싱한다.
  /// 전부 기기 내 ML Kit 처리 — 서버/네트워크/과금 없음, 오프라인 동작.
  /// 반환값: null = 사용자가 선택을 취소함, '' = 인식 실패/빈 결과.
  static Future<String?> scanRawText(ImageSource source) async {
    if (!supported) return null;
    final XFile? file = await _picker.pickImage(source: source, maxWidth: 2200, imageQuality: 92);
    if (file == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final input = InputImage.fromFilePath(file.path);
      final result = await recognizer.processImage(input);
      return result.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
