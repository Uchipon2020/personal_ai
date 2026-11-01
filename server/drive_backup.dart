import 'dart:convert';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

Future<String> saveDriveBackup(Map<String, dynamic> data) async {
  final configFile = File('server/google_credentials.json');
  final tokenFile = File('server/google_token.json');

  if (!await configFile.exists() || !await tokenFile.exists()) {
    throw Exception('先にGoogleログインを実行してください。');
  }

  final config = jsonDecode(
    await configFile.readAsString(),
  ) as Map<String, dynamic>;

  final installed = config['installed'] as Map<String, dynamic>;

  final clientId = auth.ClientId(
    installed['client_id'] as String,
    installed['client_secret'] as String,
  );

  final credentials = auth.AccessCredentials.fromJson(
    jsonDecode(await tokenFile.readAsString())
    as Map<String, dynamic>,
  );

  final baseClient = http.Client();
  auth.AutoRefreshingAuthClient? client;

  try {
    client = auth.autoRefreshingClient(
      clientId,
      credentials,
      baseClient,
    );

    final api = drive.DriveApi(client);
    final now = DateTime.now().toUtc();

    final filename =
        'personal_ai_${now.toIso8601String().replaceAll(':', '-')}.json';

    final bytes = utf8.encode(jsonEncode({
      'version': 1,
      'createdAt': now.toIso8601String(),
      'data': data,
    }));

    await api.files.create(
      drive.File()
        ..name = filename
        ..mimeType = 'application/json',
      uploadMedia: drive.Media(
        Stream<List<int>>.value(bytes),
        bytes.length,
        contentType: 'application/json',
      ),
      $fields: 'id,name',
    );

    // 更新された認証情報を保存する。
    await tokenFile.writeAsString(
      jsonEncode(client.credentials.toJson()),
      flush: true,
    );

    return filename;
  } finally {
    client?.close();
    baseClient.close();
  }
}
Future<List<Map<String, dynamic>>> listDriveBackups() async {
  final configFile = File('server/google_credentials.json');
  final tokenFile = File('server/google_token.json');

  if (!await configFile.exists() || !await tokenFile.exists()) {
    throw Exception('先にGoogleログインを実行してください。');
  }

  final config = jsonDecode(
    await configFile.readAsString(),
  ) as Map<String, dynamic>;

  final installed = config['installed'] as Map<String, dynamic>;

  final clientId = auth.ClientId(
    installed['client_id'] as String,
    installed['client_secret'] as String,
  );

  final credentials = auth.AccessCredentials.fromJson(
    jsonDecode(await tokenFile.readAsString())
    as Map<String, dynamic>,
  );

  final baseClient = http.Client();
  auth.AutoRefreshingAuthClient? client;

  try {
    client = auth.autoRefreshingClient(
      clientId,
      credentials,
      baseClient,
    );

    final api = drive.DriveApi(client);

    final result = await api.files.list(
      q: "trashed = false "
          "and mimeType = 'application/json' "
          "and name contains 'personal_ai_'",
      orderBy: 'createdTime desc',
      pageSize: 100,
      $fields: 'files(id,name,createdTime)',
    );

    await tokenFile.writeAsString(
      jsonEncode(client.credentials.toJson()),
      flush: true,
    );

    return (result.files ?? <drive.File>[])
        .where((file) =>
    file.id != null &&
        (file.name ?? '').startsWith('personal_ai_'))
        .map((file) => <String, dynamic>{
      'id': file.id,
      'name': file.name,
      'createdAt': file.createdTime?.toIso8601String(),
    })
        .toList();
  } finally {
    client?.close();
    baseClient.close();
  }
}

Future<Map<String, dynamic>> readDriveBackup(String fileId) async {
  final config = jsonDecode(
    await File('server/google_credentials.json').readAsString(),
  ) as Map<String, dynamic>;

  final installed = config['installed'] as Map<String, dynamic>;

  final clientId = auth.ClientId(
    installed['client_id'] as String,
    installed['client_secret'] as String,
  );

  final tokenFile = File('server/google_token.json');

  final credentials = auth.AccessCredentials.fromJson(
    jsonDecode(await tokenFile.readAsString())
    as Map<String, dynamic>,
  );

  final baseClient = http.Client();
  auth.AutoRefreshingAuthClient? client;

  try {
    client = auth.autoRefreshingClient(
      clientId,
      credentials,
      baseClient,
    );

    final api = drive.DriveApi(client);

    final metadata = await api.files.get(
      fileId,
      $fields: 'id,name,mimeType,trashed,size',
    ) as drive.File;

    if (metadata.trashed == true ||
        metadata.mimeType != 'application/json' ||
        !(metadata.name ?? '').startsWith('personal_ai_')) {
      throw const FormatException('対象のバックアップではありません。');
    }

    final size = int.tryParse(metadata.size ?? '');

    if (size == null || size > 4000000) {
      throw const FormatException('ファイルサイズが大きすぎます。');
    }

    final media = await api.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];

    await for (final chunk in media.stream) {
      bytes.addAll(chunk);

      if (bytes.length > 4000000) {
        throw const FormatException('ファイルサイズが大きすぎます。');
      }
    }

    final backup = jsonDecode(utf8.decode(bytes));

    if (backup is! Map<String, dynamic> ||
        backup['version'] != 1 ||
        backup['data'] is! Map<String, dynamic>) {
      throw const FormatException('バックアップ形式が違います。');
    }

    final data = backup['data'] as Map<String, dynamic>;

    if (data['notes'] is! List ||
        data['display'] is! List ||
        data['history'] is! List) {
      throw const FormatException('必要なデータがありません。');
    }

    for (final note in data['notes'] as List) {
      if (note is! String) {
        throw const FormatException('メモの形式が違います。');
      }
    }

    for (final item in data['display'] as List) {
      if (item is! Map ||
          item['isUser'] is! bool ||
          item['text'] is! String) {
        throw const FormatException('会話の表示データが違います。');
      }
    }

    final history = data['history'] as List;

    if (history.length.isOdd) {
      throw const FormatException('会話履歴の組み合わせが違います。');
    }

    for (var i = 0; i < history.length; i++) {
      final item = history[i];
      final expectedRole = i.isEven ? 'user' : 'assistant';

      if (item is! Map ||
          item['role'] != expectedRole ||
          item['content'] is! String ||
          (item['content'] as String).trim().isEmpty) {
        throw const FormatException('会話履歴の形式が違います。');
      }
    }

    await tokenFile.writeAsString(
      jsonEncode(client.credentials.toJson()),
      flush: true,
    );

    return {
      'filename': metadata.name,
      'createdAt': backup['createdAt'],
      'data': data,
    };
  } finally {
    client?.close();
    baseClient.close();
  }
}