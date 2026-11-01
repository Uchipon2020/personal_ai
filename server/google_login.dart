import 'dart:convert';
import 'dart:io';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as auth;

Future<void> main() async {
  final credentialsFile = File('server/google_credentials.json');

  if (!await credentialsFile.exists()) {
    print('server/google_credentials.json が見つかりません。');
    return;
  }

  auth.AutoRefreshingAuthClient? client;

  try {
    final json = jsonDecode(
      await credentialsFile.readAsString(),
    ) as Map<String, dynamic>;

    final installed = json['installed'];

    if (installed is! Map) {
      print('デスクトップアプリ用のJSONを使用してください。');
      return;
    }

    final clientId = auth.ClientId(
      installed['client_id'] as String,
      installed['client_secret'] as String,
    );

    client = await auth.clientViaUserConsent(
      clientId,
      [drive.DriveApi.driveFileScope],
          (url) {
        print('ブラウザでGoogleにログインしてください。');
        print('自動で開かない場合は、このURLを開いてください：');
        print(url);

        Process.run('open', [url]).then((result) {
          if (result.exitCode != 0) {
            print('表示されたURLを手動で開いてください。');
          }
        }).catchError((Object error) {
          print('表示されたURLを手動で開いてください。');
        });
      },
    );

    // Drive APIへ接続できるか確認する。
    final api = drive.DriveApi(client);
    await api.files.list(
      pageSize: 1,
      $fields: 'files(id,name)',
    );

    // 次回以降の接続に使う認証情報を保存する。
    final tokenFile = File('server/google_token.json');

    await tokenFile.writeAsString(
      jsonEncode(client.credentials.toJson()),
      flush: true,
    );

    await Process.run('chmod', ['600', tokenFile.path]);

    print('Google Driveへの接続に成功しました。');
    print('認証情報を保存しました。');
  } catch (error) {
    print('Google接続エラー：$error');
  } finally {
    client?.close();
  }
}