import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import 'flashcard_model.dart';
import 'quiz_in_progress_screen.dart';

// Quiz source selection options
enum QuizSourceMode { all, favorites, wrong }

// Quiz type options
enum QuizType { multipleChoice, flashcard }

/// Quiz setup screen widget.
/// Users configure quiz options before starting a session.
class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({Key? key}) : super(key: key);

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  QuizSourceMode _mode = QuizSourceMode.all;
  QuizType _quizType = QuizType.multipleChoice;
  int _questionCount = 10;
  bool _loadingCount = false;
  String? _countError;
  final Map<String, bool> _starFilter = {
    'red': true,
    'yellow': true,
    'blue': true,
  };

  /// Dummy function to simulate fetching available word count.
  Future<int> fetchAvailableWordCount(
      QuizSourceMode mode, Map<String, bool> stars) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // TODO: connect with real data source
    return 20;
  }

  Future<void> _setAllQuestionCount() async {
    setState(() {
      _loadingCount = true;
      _countError = null;
    });
    try {
      final count = await fetchAvailableWordCount(_mode, _starFilter);
      if (!mounted) return;
      setState(() {
        _questionCount = count;
        if (count == 0) {
          _countError = '利用可能な問題がありません';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _countError = '利用可能な問題数の取得に失敗しました';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCount = false;
        });
      }
    }
  }

  Future<List<Flashcard>> _loadAllFlashcards() async {
    final String jsonString =
        await DefaultAssetBundle.of(context).loadString('assets/words.json');
    final List<dynamic> jsonData = json.decode(jsonString) as List<dynamic>;
    List<Flashcard> cards = [];
    for (var item in jsonData) {
      if (item is Map<String, dynamic> &&
          item['id'] != null &&
          item['term'] != null) {
        try {
          cards.add(Flashcard.fromJson(item));
        } catch (_) {}
      }
    }
    return cards;
  }

  Future<void> _startQuiz() async {
    debugPrint('--- Quiz Setup ---');
    debugPrint('mode: $_mode');
    debugPrint('questionCount: $_questionCount');
    debugPrint('quizType: $_quizType');
    debugPrint('stars: $_starFilter');

    final allCards = await _loadAllFlashcards();
    if (!mounted) return;
    allCards.shuffle(Random());
    final sessionWords = allCards.take(_questionCount).toList();

    if (sessionWords.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizInProgressScreen(
          quizSessionWords: sessionWords,
          totalSessionQuestions: sessionWords.length,
          quizSessionType: _quizType,
        ),
      ),
    );
  }

  Widget _buildStarCheckbox(String key, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _starFilter[key],
          onChanged: (val) {
            setState(() {
              _starFilter[key] = val ?? false;
            });
          },
          activeColor: color,
        ),
        Text(key == 'red'
            ? '赤'
            : key == 'yellow'
                ? '黄'
                : '青'),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('出題モード', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        RadioListTile<QuizSourceMode>(
          title: const Text('全単語から出題'),
          value: QuizSourceMode.all,
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
        ),
        RadioListTile<QuizSourceMode>(
          title: const Text('お気に入りから出題'),
          value: QuizSourceMode.favorites,
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
        ),
        RadioListTile<QuizSourceMode>(
          title: const Text('間違えた単語から出題'),
          value: QuizSourceMode.wrong,
          groupValue: _mode,
          onChanged: (v) => setState(() => _mode = v!),
        ),
        const SizedBox(height: 24),
        Text('星フィルタ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildStarCheckbox('red', Colors.redAccent),
            _buildStarCheckbox('yellow', Colors.orangeAccent),
            _buildStarCheckbox('blue', Colors.blueAccent),
          ],
        ),
        const SizedBox(height: 24),
        Text('問題数', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<int>(
              value: _questionCount,
              items: const [5, 10, 20, 30]
                  .map((e) => DropdownMenuItem<int>(
                      value: e, child: Text(e.toString())))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _questionCount = v;
                  });
                }
              },
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _loadingCount ? null : _setAllQuestionCount,
              child: _loadingCount
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('全部出題する'),
            ),
          ],
        ),
        if (_countError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _countError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        Text('クイズタイプ', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ToggleButtons(
          isSelected: QuizType.values
              .map((type) => type == _quizType)
              .toList(),
          onPressed: (index) {
            setState(() {
              _quizType = QuizType.values[index];
            });
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('4択'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('単語帳'),
            ),
          ],
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _questionCount == 0 ? null : _startQuiz,
            child: const Text('クイズ開始'),
          ),
        ),
      ],
    );
  }
}
