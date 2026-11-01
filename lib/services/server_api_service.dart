import 'dart:convert';

import 'package:http/http.dart' as http;

/// Mac上のDart Serverとの通信を１か所にまとめる。
/// APIキーやGoogleの認証情報はFlutterには置かない。
class ServerApiService {
  static const _host = '127.0.0.1:8080';

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    int timeoutSeconds = 120,
  }) async {
    final client = http.Client();
    try {
      final uri = Uri.http(_host, path, query);
      final response =
          await (body == null
                  ? client.get(uri)
                  : client.post(
                      uri,
                      headers: {
                        'Content-Type': 'application/json; charset=utf-8',
                      },
                      body: jsonEncode(body),
                    ))
              .timeout(Duration(seconds: timeoutSeconds));

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw Exception(data['error'] ?? '接続に失敗しました。');
      }
      return data;
    } finally {
      client.close();
    }
  }

  Future<String> sendMessage({
    required List<Map<String, String>> messages,
    required String notes,
  }) async {
    final data = await _request(
      '/chat',
      body: {'messages': messages, 'notes': notes},
      timeoutSeconds: 210,
    );
    final answer = data['reply'];
    if (answer is! String || answer.trim().isEmpty) {
      throw Exception('回答が空でした。');
    }
    return answer;
  }

  Future<String> saveBackup(Map<String, dynamic> snapshot) async {
    final data = await _request('/backup', body: snapshot);
    return data['filename'] as String;
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final data = await _request('/backups');
    return (data['backups'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> readBackup(String fileId) {
    return _request('/backup-content', query: {'id': fileId});
  }
}
