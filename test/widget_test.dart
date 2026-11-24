import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:team_app_34/diagnosis_api.dart';
import 'package:team_app_34/diagnosis_controller.dart';
import 'package:team_app_34/main.dart';

void main() {
  testWidgets('검사 입력 검증, 요청 상태와 결과 표시', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final response = Completer<http.Response>();
    http.Request? request;
    final client = MockClient((incoming) {
      request = incoming;
      return response.future;
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          diagnosisApiProvider.overrideWithValue(
            DiagnosisApi(client, 'https://example.com/diagnosis'),
          ),
        ],
        child: const MyApp(),
      ),
    );

    final button = find.widgetWithText(FilledButton, '검사');
    expect(find.text('간단하게 당뇨병 진단해보기'), findsOneWidget);
    expect(find.text('결과'), findsOneWidget);
    expect(find.text('임신 횟수'), findsOneWidget);
    expect(find.text('대기중'), findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('나이 항목을 입력해 주세요.'), findsOneWidget);
    expect(request, isNull);

    final fields = find.byType(TextFormField);
    final values = ['25', '65.5', '170', '95', '0'];
    expect(fields, findsNWidgets(values.length));
    for (var index = 0; index < values.length; index++) {
      await tester.enterText(fields.at(index), values[index]);
    }
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(find.text('검사 중…'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(request!.method, 'POST');
    expect(jsonDecode(request!.body), {
      'age': 25,
      'weightKg': 65.5,
      'heightCm': 170,
      'bloodGlucoseMgDl': 95,
      'pregnancyCount': 0,
    });

    response.complete(
      http.Response.bytes(utf8.encode('{"result":"서버 검사 결과"}'), 200),
    );
    await tester.pumpAndSettle();
    expect(find.text('서버 검사 결과'), findsOneWidget);

    await tester.enterText(fields.last, '1');
    await tester.pump();
    expect(find.text('대기중'), findsOneWidget);
  });
}
