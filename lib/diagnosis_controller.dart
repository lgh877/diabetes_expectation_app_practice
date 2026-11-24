import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'diagnosis_api.dart';

final diagnosisApiProvider = Provider<DiagnosisApi>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  final localHost = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';
  return DiagnosisApi(
    client,
    const bool.hasEnvironment('DIAGNOSIS_API_URL')
        ? const String.fromEnvironment('DIAGNOSIS_API_URL')
        : kDebugMode
        ? 'http://$localHost:8000/diagnosis'
        : '',
  );
});

final diagnosisProvider =
    NotifierProvider<DiagnosisController, AsyncValue<String?>>(
      DiagnosisController.new,
    );

class DiagnosisController extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncData(null);

  void reset() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<void> check(DiagnosisInput input) async {
    if (state.isLoading) return;
    final api = ref.read(diagnosisApiProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard<String?>(() => api.check(input));
    if (ref.mounted) state = result;
  }
}
