import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnosis_api.dart';
import 'diagnosis_controller.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key});

  static const title = '간단하게 당뇨병 진단해보기';

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _glucose = TextEditingController();
  final _pregnancyCount = TextEditingController();

  @override
  void dispose() {
    _age.dispose();
    _weight.dispose();
    _height.dispose();
    _glucose.dispose();
    _pregnancyCount.dispose();
    super.dispose();
  }

  void _check() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    ref
        .read(diagnosisProvider.notifier)
        .check(
          DiagnosisInput(
            age: int.parse(_age.text.trim(), radix: 10),
            weightKg: double.parse(_weight.text.trim()),
            heightCm: double.parse(_height.text.trim()),
            bloodGlucoseMgDl: double.parse(_glucose.text.trim()),
            pregnancyCount: int.parse(_pregnancyCount.text.trim(), radix: 10),
          ),
        );
  }

  Widget _field(
    String label,
    String unit,
    TextEditingController controller, {
    required bool enabled,
    bool integer = false,
    bool last = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => ref.read(diagnosisProvider.notifier).reset(),
        onFieldSubmitted: last ? (_) => _check() : null,
        validator: (text) {
          final value = text?.trim() ?? '';
          if (value.isEmpty) return '$label 항목을 입력해 주세요.';
          if (integer) {
            final number = int.tryParse(value, radix: 10);
            return number == null || number < 0 ? '0 이상의 정수를 입력해 주세요.' : null;
          }
          final number = double.tryParse(value);
          return number == null || !number.isFinite || number <= 0
              ? '0보다 큰 숫자를 입력해 주세요.'
              : null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(diagnosisProvider);
    final enabled = !state.isLoading;
    final result = state.when(
      data: (result) => result ?? '대기중',
      loading: () => '검사 중…',
      error: (error, _) => switch (error) {
        DiagnosisException(:final message) => message,
        TimeoutException() => '서버 응답 시간이 초과되었습니다. 다시 시도해 주세요.',
        _ => '서버에 연결할 수 없습니다. 다시 시도해 주세요.',
      },
    );

    return Scaffold(
      appBar: AppBar(title: const Text(Home.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('나이', '세', _age, enabled: enabled, integer: true),
                    _field('몸무게', 'kg', _weight, enabled: enabled),
                    _field('키', 'cm', _height, enabled: enabled),
                    _field('혈당', 'mg/dL', _glucose, enabled: enabled),
                    _field(
                      '임신 횟수',
                      '회',
                      _pregnancyCount,
                      enabled: enabled,
                      integer: true,
                      last: true,
                    ),
                    FilledButton(
                      onPressed: enabled ? _check : null,
                      child: const Text('검사'),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '결과',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Semantics(liveRegion: true, child: Text(result)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
