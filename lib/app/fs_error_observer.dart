import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [임시 진단] 어떤 Provider 가 cloud_firestore/permission-denied 로 에러 상태에
/// 들어가는지 콘솔에 정확히 출력한다. handleError 흡수가 아니라 '관찰'만 한다.
/// 원인 확정 후 제거할 것.
class FsErrorObserver extends ProviderObserver {
  bool _denied(Object? e) => e != null && e.toString().contains('permission-denied');

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // permission-denied 만이 아니라 '모든' AsyncError 를 출력 — 실제 에러 종류 규명.
    if (newValue is AsyncError) {
      final tag = _denied(newValue.error) ? '🔥[FS-DENIED]' : '⚠️[PROVIDER-ERROR]';
      debugPrint(
        '$tag provider=${provider.name ?? provider.runtimeType} '
        ':: ${newValue.error} (${newValue.error.runtimeType})',
      );
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    final tag = _denied(error) ? '🔥[FS-DENIED:build]' : '⚠️[PROVIDER-ERROR:build]';
    debugPrint('$tag provider=${provider.name ?? provider.runtimeType} :: $error (${error.runtimeType})');
  }
}
