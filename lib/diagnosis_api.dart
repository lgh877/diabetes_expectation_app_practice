import 'dart:convert';

import 'package:http/http.dart' as http;

class DiagnosisInput {
  const DiagnosisInput({
    required this.age,
    required this.weightKg,
    required this.heightCm,
    required this.bloodGlucoseMgDl,
    required this.pregnancyCount,
  });

  final int age;
  final double weightKg;
  final double heightCm;
  final double bloodGlucoseMgDl;
  final int pregnancyCount;

  Map<String, num> toJson() => {
    'age': age,
    'weightKg': weightKg,
    'heightCm': heightCm,
    'bloodGlucoseMgDl': bloodGlucoseMgDl,
    'pregnancyCount': pregnancyCount,
  };
}

class DiagnosisApi {
  const DiagnosisApi(this._client, this._url);

  final http.Client _client;
  final String _url;

  Future<String> check(DiagnosisInput input) async {
    final endpoint = Uri.tryParse(_url);
    if (endpoint == null ||
        !['http', 'https'].contains(endpoint.scheme) ||
        endpoint.host.isEmpty) {
      throw const DiagnosisException('검사 서버 주소를 설정해 주세요.');
    }

    final response = await _client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DiagnosisException('검사 요청에 실패했습니다. 다시 시도해 주세요.');
    }

    const invalidResponse = DiagnosisException('서버에서 검사 결과를 읽을 수 없습니다.');
    final Object? data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw invalidResponse;
    }
    if (data case {
      'result': final String result,
    } when result.trim().isNotEmpty) {
      return result.trim();
    }
    throw invalidResponse;
  }
}

class DiagnosisException implements Exception {
  const DiagnosisException(this.message);

  final String message;
}
