/// 質問に応じて、AIに渡すメモを選ぶ。
/// 保存されたメモは変更せず、送信する文章だけを組み立てる。
class NoteContextService {
  static const _maximumCharacters = 6000;
  static const _basicInformationBudget = 2000;

  // 分類名を直接質問した場合に加え、以下の言葉でも分類を選ぶ。
  static const _keywords = <String, List<String>>{
    '人材紹介': ['人材紹介', '求人', '採用', '視能訓練士', 'ort'],
    'ヒカリコンタクト': ['ヒカリコンタクト', 'コンタクト販売', 'コンタクトレンズ販売'],
    'ICL': ['icl', '眼内コンタクト', '視力矯正セミナー'],
    'H&U': ['h&u', 'h＆u', 'エイチアンドユー'],
    'アプリ開発': ['アプリ開発', 'flutter', 'dart', 'personal ai'],
  };

  String buildContext({required String question, required List<String> notes}) {
    final query = question.toLowerCase();
    final newestFirst = notes.reversed.toList();
    final matchedCategories = <String>{};

    for (final entry in _keywords.entries) {
      if (entry.value.any((word) => query.contains(word.toLowerCase()))) {
        matchedCategories.add(entry.key);
      }
    }

    // 今後追加した分類も、分類名を質問に含めれば使える。
    for (final note in newestFirst) {
      final category = _categoryOf(note);
      if (category != null && query.contains(category.toLowerCase())) {
        matchedCategories.add(category);
      }
    }

    final basicNotes = newestFirst
        .where((note) => _categoryOf(note) == '基本情報')
        .toList();

    final candidates = newestFirst.where((note) {
      final category = _categoryOf(note);
      if (category == '基本情報') return false;
      // 分類が判定できなければ、従来と同じく新しいメモを候補にする。
      return matchedCategories.isEmpty || matchedCategories.contains(category);
    });

    final basicText = _joinWithinBudget(basicNotes, _basicInformationBudget);
    final separator = basicText.isEmpty ? '' : '\n\n';
    final otherText = _joinWithinBudget(
      candidates,
      _maximumCharacters - basicText.length - separator.length,
    );

    if (otherText.isEmpty) return basicText;
    return '$basicText$separator$otherText';
  }

  String? _categoryOf(String note) {
    final match = RegExp(r'^\[([^\]\r\n]+)\]').firstMatch(note);
    final category = match?.group(1)?.trim();
    return category == null || category.isEmpty ? null : category;
  }

  String _joinWithinBudget(Iterable<String> notes, int budget) {
    final result = StringBuffer();
    var remaining = budget;

    for (final note in notes) {
      if (note.trim().isEmpty) continue;
      final separator = result.isEmpty ? '' : '\n\n';
      final available = remaining - separator.length;
      if (available <= 0) break;

      // 文字数の予算内で、絵文字の途中を切らずに追加する。
      final clipped = StringBuffer();
      var used = 0;
      for (final rune in note.runes) {
        final character = String.fromCharCode(rune);
        if (used + character.length > available) break;
        clipped.write(character);
        used += character.length;
      }
      if (used == 0) break;

      result.write(separator);
      result.write(clipped);
      remaining -= separator.length + used;
      if (used < note.length) break;
    }

    return result.toString();
  }
}
