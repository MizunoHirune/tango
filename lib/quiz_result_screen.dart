import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'flashcard_model.dart';

const String quizStatsBoxName = 'quiz_stats_box_v1';

class QuizResultScreen extends StatefulWidget {
  final List<Flashcard> words;
  final List<bool> answerResults;
  final int score;
  final int durationSeconds;

  const QuizResultScreen({
    Key? key,
    required this.words,
    required this.answerResults,
    required this.score,
    required this.durationSeconds,
  }) : super(key: key);

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  late Box<Map> _statsBox;
  bool _showDescriptions = true;

  @override
  void initState() {
    super.initState();
    _statsBox = Hive.box<Map>(quizStatsBoxName);
    _addStatsEntry();
  }

  Future<void> _addStatsEntry() async {
    final entry = {
      'timestamp': DateTime.now(),
      'questionCount': widget.words.length,
      'correctCount': widget.score,
      'durationSeconds': widget.durationSeconds,
      'wordIds': widget.words.map((w) => w.id).toList(),
      'results': widget.answerResults,
    };
    await _statsBox.add(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('結果')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'スコア: ${widget.score} / ${widget.words.length}',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SwitchListTile(
            title: const Text('単語概要を表示'),
            value: _showDescriptions,
            onChanged: (val) => setState(() => _showDescriptions = val),
          ),
          const SizedBox(height: 16),
          ...List.generate(widget.words.length, (index) {
            final card = widget.words[index];
            final bool correct = index < widget.answerResults.length &&
                widget.answerResults[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Q${index + 1}: ',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Expanded(
                            child: Text(card.term,
                                style: Theme.of(context).textTheme.bodyLarge)),
                        Icon(
                          correct ? Icons.circle : Icons.close,
                          color: correct
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                      ],
                    ),
                    if (_showDescriptions) ...[
                      const SizedBox(height: 8),
                      Text(card.description),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
