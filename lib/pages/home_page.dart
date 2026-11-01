import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../models/conversation_data.dart';
import '../services/local_storage_service.dart';
import '../services/server_api_service.dart';
import '../widgets/add_note_dialog.dart';
import '../widgets/backup_picker_dialog.dart';
import '../widgets/chat_panel.dart';
import '../widgets/notes_panel.dart';
import '../widgets/restore_confirmation_dialog.dart';
import '../services/note_context_service.dart';
import '../widgets/note_preview_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<ChatMessage> _messages = [
    const ChatMessage(isUser: false, text: 'こんにちは。ここから自分専用のAIアシスタントを作っていきます。'),
  ];

  final List<String> _notes = [];
  int _page = 0;
  bool _sending = false;
  bool _backingUp = false;
  bool _restoring = false;
  Timer? _driveTimer;
  int _driveRevision = 0;
  bool _driveDirty = false;

  final List<Map<String, String>> _apiHistory = [];
  bool _conversationLoaded = false;

  final _storage = LocalStorageService();
  final _serverApi = ServerApiService();
  final _noteContext = NoteContextService();
  bool _notesLoaded = false;

  // ── 自動バックアップの予約 ──

  void _queueDriveBackup() {
    if (!mounted) return;

    setState(() {
      _driveRevision++;
      _driveDirty = true;
    });

    _startDriveTimer();
  }

  void _startDriveTimer() {
    _driveTimer?.cancel();

    _driveTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_driveDirty) return;

      _backupToDrive(automatic: true);
    });
  }
  // ── 起動時の読み込み・端末内保存 ──

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _loadConversation();
  }

  Future<void> _loadNotes() async {
    try {
      final savedNotes = await _storage.loadNotes();

      if (!mounted) return;

      setState(() {
        _notes
          ..clear()
          ..addAll(savedNotes);
        _notesLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('メモの読み込みに失敗しました：$error')));
    }
  }

  Future<void> _saveNotes() async {
    try {
      await _storage.saveNotes(_notes);
      _queueDriveBackup();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('メモの保存に失敗しました：$error')));
    }
  }

  Future<void> _loadConversation() async {
    try {
      final saved = await _storage.loadConversation();
      if (saved == null) {
        if (!mounted) return;
        setState(() => _conversationLoaded = true);
        return;
      }
      final display = saved.messages;
      final history = saved.apiHistory;

      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(display);

        _apiHistory
          ..clear()
          ..addAll(history);

        _conversationLoaded = true;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('会話を読み込めませんでした：$error')));
    }
  }

  Future<void> _saveConversation() async {
    try {
      await _storage.saveConversation(
        ConversationData(messages: _messages, apiHistory: _apiHistory),
      );
      _queueDriveBackup();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('会話の保存に失敗しました：$error')));
    }
  }

  @override
  void dispose() {
    _driveTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;

      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Driveからの復元 ──

  Future<void> _restoreFromDrive() async {
    if (_restoring ||
        _backingUp ||
        _sending ||
        !_conversationLoaded ||
        !_notesLoaded) {
      return;
    }

    setState(() => _restoring = true);

    try {
      final backups = await _serverApi.listBackups();

      if (!mounted) return;

      if (backups.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('バックアップがありません。')));
        return;
      }

      // 復元するファイルを選ぶ。
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => BackupPickerDialog(backups: backups),
      );

      if (selected == null || !mounted) return;

      final content = await _serverApi.readBackup(selected['id'] as String);
      final data = content['data'] as Map<String, dynamic>;
      final restoredNotes = List<String>.from(data['notes'] as List);
      final restored = ConversationData.fromJson(data);
      ConversationData.trimHistory(restored.apiHistory);
      final restoredDisplay = restored.messages;
      final restoredHistory = restored.apiHistory;

      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => RestoreConfirmationDialog(
          noteCount: restoredNotes.length,
          messageCount: restoredDisplay.length,
        ),
      );

      if (confirmed != true || !mounted) return;

      try {
        await _storage.restoreBackup(
          oldNotes: List<String>.from(_notes),
          oldConversation: ConversationData(
            messages: List<ChatMessage>.from(_messages),
            apiHistory: _apiHistory
                .map((item) => Map<String, String>.from(item))
                .toList(),
          ),
          newNotes: restoredNotes,
          newConversation: restored,
        );
      } on RestoreRollbackException {
        if (mounted) {
          setState(() {
            _notesLoaded = false;
            _conversationLoaded = false;
          });
        }
        rethrow;
      }

      if (!mounted) return;

      setState(() {
        _notes
          ..clear()
          ..addAll(restoredNotes);

        _messages
          ..clear()
          ..addAll(restoredDisplay);

        _apiHistory
          ..clear()
          ..addAll(restoredHistory);
      });

      _scrollToBottom();

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('会話とメモを復元しました。')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('復元エラー：$error')));
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  // ── Driveへの手動・自動保存 ──

  Future<void> _backupToDrive({bool automatic = false}) async {
    if (!_conversationLoaded || !_notesLoaded) return;

    if (_backingUp || _sending || _restoring) {
      if (automatic && _driveDirty) {
        _startDriveTimer();
      }
      return;
    }

    _driveTimer?.cancel();

    final revision = _driveRevision;

    final snapshot = {
      'notes': List<String>.from(_notes),
      'display': _messages
          .map((item) => {'isUser': item.isUser, 'text': item.text})
          .toList(),
      'history': _apiHistory
          .map((item) => Map<String, String>.from(item))
          .toList(),
    };

    setState(() => _backingUp = true);

    var succeeded = false;

    try {
      final filename = await _serverApi.saveBackup(snapshot);

      succeeded = true;

      if (!mounted) return;

      setState(() {
        // 保存中に新しい変更があれば、未保存として残す。
        _driveDirty = _driveRevision != revision;
      });

      if (!automatic) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Driveに保存しました：$filename')));
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => _driveDirty = true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Driveへの保存に失敗しました：$error\n'
            'サーバーと通信状態を確認し、「Driveに保存」で再試行してください。',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _backingUp = false);

        if (succeeded && _driveDirty) {
          _startDriveTimer();
        }
      }
    }
  }

  Future<void> _previewNotesForAi() async {
    if (_sending || _restoring) return;

    if (!_conversationLoaded || !_notesLoaded) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('会話とメモの読み込みをお待ちください。')));
      return;
    }

    final question = _input.text.trim();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先に質問を入力してください。')));
      return;
    }

    final notesText = _noteContext.buildContext(
      question: question,
      notes: _notes,
    );

    await showDialog<void>(
      context: context,
      builder: (_) => NotePreviewDialog(
        question: question,
        notesText: notesText,
        historyMessageCount: _apiHistory.length,
      ),
    );
  }

  // ── 会話の送信 ──

  Future<void> _send() async {
    final text = _input.text.trim();

    if (text.isEmpty || _sending || _restoring) return;

    if (!_conversationLoaded || !_notesLoaded) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('会話とメモの読み込みが完了していません。')));
      return;
    }

    if (text.length > 3000) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('入力は3000文字以内にしてください。')));
      return;
    }

    final requestMessages = [
      ..._apiHistory,
      {'role': 'user', 'content': text},
    ];

    setState(() {
      _sending = true;
      _messages.add(ChatMessage(isUser: true, text: text));
      _input.clear();
    });

    _scrollToBottom();

    try {
      final answer = await _serverApi.sendMessage(
        messages: requestMessages,
        notes: _noteContext.buildContext(question: text, notes: _notes),
      );

      if (!mounted) return;

      // 成功した質問と回答だけを、AIに渡す履歴へ追加する。
      _apiHistory.addAll([
        {'role': 'user', 'content': text},
        {'role': 'assistant', 'content': answer},
      ]);

      ConversationData.trimHistory(_apiHistory);

      setState(() {
        _messages.add(ChatMessage(isUser: false, text: answer));
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(ChatMessage(isUser: false, text: '送信に失敗しました：$error'));
      });

      // 再送しやすいよう、入力欄が空なら質問を戻す。
      if (_input.text.isEmpty) {
        _input.text = text;
      }
    } finally {
      await _saveConversation();

      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  // ── メモ追加 ──

  Future<void> _addNote() async {
    if (!_notesLoaded || _restoring) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const AddNoteDialog(),
    );
    if (!mounted || result == null) return;
    setState(() => _notes.add(result));
    await _saveNotes();
  }

  // ── 全体画面 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal AI'),
        actions: [
          TextButton.icon(
            onPressed:
                _restoring ||
                    _backingUp ||
                    _sending ||
                    !_conversationLoaded ||
                    !_notesLoaded
                ? null
                : _restoreFromDrive,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(_restoring ? '読込・復元中…' : '復元'),
          ),
          TextButton.icon(
            onPressed:
                _restoring ||
                    _backingUp ||
                    _sending ||
                    !_conversationLoaded ||
                    !_notesLoaded
                ? null
                : _backupToDrive,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(
              _backingUp
                  ? '保存中…'
                  : _driveDirty
                  ? 'Driveに保存（未保存あり）'
                  : 'Driveに保存',
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('GPT-6 Luna・メモはMac内に保存'),
          ),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _page,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (value) {
              setState(() => _page = value);
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                label: Text('会話'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.note_outlined),
                label: Text('メモ'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: _page == 0
                ? ChatPanel(
                    messages: _messages,
                    inputController: _input,
                    scrollController: _scroll,
                    sending: _sending,
                    enabled: _conversationLoaded && _notesLoaded && !_restoring,
                    onSend: _send,
                    onPreviewNotes: _previewNotesForAi,
                  )
                : NotesPanel(
                    notes: _notes,
                    enabled: _notesLoaded && !_restoring,
                    onAddNote: _addNote,
                  ),
          ),
        ],
      ),
    );
  }
}
