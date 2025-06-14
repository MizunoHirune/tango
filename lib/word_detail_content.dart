// lib/word_detail_content.dart

import 'package:flutter/material.dart';
import 'package:hive/hive.dart'; // Hiveをインポート
import 'flashcard_model.dart';
import '../history_entry_model.dart'; // 閲覧履歴用のモデルをインポート (libフォルダ直下にある想定)
import '../word_detail_controller.dart';

// Box名は他のファイルと共通にするため定数化
const String favoritesBoxName = 'favorites_box_v2';
const String historyBoxName = 'history_box_v2'; // ★閲覧履歴用のBox名を追加

class _ViewState {
  final List<Flashcard> list;
  final int index;
  _ViewState(this.list, this.index);
}

class WordDetailContent extends StatefulWidget {
  final List<Flashcard> flashcards;
  final int initialIndex;
  final WordDetailController? controller;

  const WordDetailContent({
    Key? key,
    required this.flashcards,
    required this.initialIndex,
    this.controller,
  }) : super(key: key);

  @override
  _WordDetailContentState createState() => _WordDetailContentState();
}

class _WordDetailContentState extends State<WordDetailContent> {
  late Box<Map> _favoritesBox;
  late Box<HistoryEntry> _historyBox; // ★閲覧履歴用のBoxインスタンスを保持する変数を宣言

  late PageController _pageController;
  late int _currentIndex;
  late List<Flashcard> _displayFlashcards;

  // History navigation state for back/forward arrows
  final List<_ViewState> _viewHistory = [];
  int _historyIndex = -1;
  bool _suppressHistoryPush = false;

  Flashcard get _currentFlashcard => _displayFlashcards[_currentIndex];

  // お気に入り状態のローカル管理用 (これは変更なし)
  Map<String, bool> _favoriteStatus = {
    'red': false,
    'yellow': false,
    'blue': false,
  };

  @override
  void initState() {
    super.initState();
    // Boxのインスタンスを取得
    _favoritesBox = Hive.box<Map>(favoritesBoxName);
    _historyBox = Hive.box<HistoryEntry>(historyBoxName); // ★履歴Boxのインスタンスを取得

    _displayFlashcards = widget.flashcards;
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    widget.controller?.attach(
      canGoBack: _canGoBack,
      canGoForward: _canGoForward,
      goBack: _handleBack,
      goForward: _handleForward,
    );

    _viewHistory.add(_ViewState(_displayFlashcards, _currentIndex));
    _historyIndex = 0;

    _loadFavoriteStatus(); // 既存：お気に入り状態を読み込む
    _addHistoryEntry(); // ★新規：閲覧履歴を追加するメソッドを呼び出す
  }

  // 既存：Hiveから現在の単語のお気に入り状態を読み込むメソッド (変更なし)
  void _loadFavoriteStatus() {
    final String wordId = _displayFlashcards[_currentIndex].id;
    if (_favoritesBox.containsKey(wordId)) {
      final Map<dynamic, dynamic>? storedStatusRaw = _favoritesBox.get(wordId);
      if (storedStatusRaw != null) {
        final Map<String, bool> storedStatus = storedStatusRaw
            .map((key, value) => MapEntry(key.toString(), value as bool));

        if (!mounted) return;
        setState(() {
          _favoriteStatus['red'] = storedStatus['red'] ?? false;
          _favoriteStatus['yellow'] = storedStatus['yellow'] ?? false;
          _favoriteStatus['blue'] = storedStatus['blue'] ?? false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _favoriteStatus['red'] = false;
        _favoriteStatus['yellow'] = false;
@@ -114,52 +138,105 @@ class _WordDetailContentState extends State<WordDetailContent> {
      await _historyBox.delete(oldEntryKeyToRemove);
      // print("Removed old history entry for $wordId with key $oldEntryKeyToRemove");
    }

    // 新しい履歴エントリを追加 (Hiveのaddメソッドは自動で整数キーを割り当てます)
    final newEntry = HistoryEntry(wordId: wordId, timestamp: now);
    await _historyBox.add(newEntry);
    print(
        "Added to history: ${newEntry.wordId} at ${newEntry.timestamp}. Box length: ${_historyBox.length}");
    // print("Added to history: $wordId at $now. New key: ${newEntry.key}. Total history: ${_historyBox.length}");

    // オプション：履歴の件数制限 (例: 最新100件まで)
    if (_historyBox.length > 100) {
      // タイムスタンプでソートして最も古いものを削除
      List<MapEntry<dynamic, HistoryEntry>> entries =
          _historyBox.toMap().entries.toList();
      if (entries.isNotEmpty) {
        entries.sort(
            (a, b) => a.value.timestamp.compareTo(b.value.timestamp)); // 古い順
        await _historyBox.delete(entries.first.key);
        // print("History limit reached, oldest entry with key ${entries.first.key} deleted.");
      }
    }
  }

  bool _canGoBack() => _historyIndex > 0;
  bool _canGoForward() => _historyIndex >= 0 && _historyIndex < _viewHistory.length - 1;

  void _pushHistory() {
    if (_suppressHistoryPush) {
      _suppressHistoryPush = false;
      return;
    }
    if (_historyIndex < _viewHistory.length - 1) {
      _viewHistory.removeRange(_historyIndex + 1, _viewHistory.length);
    }
    _viewHistory.add(_ViewState(_displayFlashcards, _currentIndex));
    _historyIndex = _viewHistory.length - 1;
    widget.controller?.update();
  }

  void _jumpToView(_ViewState view, {bool addToHistory = false}) {
    final newController = PageController(initialPage: view.index);
    _pageController.dispose();

    setState(() {
      _displayFlashcards = view.list;
      _currentIndex = view.index;
      _pageController = newController;
      _suppressHistoryPush = !addToHistory;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(view.index);
      }
    });

    _loadFavoriteStatus();
    _addHistoryEntry();
    widget.controller?.update();
  }

  void _handleBack() {
    if (_canGoBack()) {
      _historyIndex--;
      _jumpToView(_viewHistory[_historyIndex]);
    }
  }

  void _handleForward() {
    if (_canGoForward()) {
      _historyIndex++;
      _jumpToView(_viewHistory[_historyIndex]);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _pageController.dispose();
    super.dispose();
  }

  // 既存：星アイコンを生成するウィジェットメソッド (変更なし)
  Widget _buildStarIcon(String colorKey, Color color) {
    bool isFavorite = _favoriteStatus[colorKey] ?? false;
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.star : Icons.star_border,
        color: isFavorite ? color : Colors.grey[400],
        size: 28,
      ),
      onPressed: () => _toggleFavorite(colorKey),
      tooltip: colorKey == 'red'
          ? '赤星'
          : colorKey == 'yellow'
              ? '黄星'
              : '青星',
    );
  }

  // 既存：詳細項目を表示するウィジェットメソッド (変更なし)
  Widget _buildDetailItem(BuildContext context, String label, String? value) {
    if (value == null ||
@@ -196,97 +273,73 @@ class _WordDetailContentState extends State<WordDetailContent> {
                      ?.withOpacity(0.85),
                ),
          ),
        ],
      ),
    );
  }

  String? _resolveRelatedTerms(List<String>? ids) {
    if (ids == null) return null;
    List<String> terms = [];
    for (final id in ids) {
      try {
        final match = widget.flashcards.firstWhere((c) => c.id == id).term;
        terms.add(match);
      } catch (_) {
        terms.add(id);
      }
    }
    return terms.isEmpty ? null : terms.join('、');
  }

  void _navigateToFlashcard(Flashcard card) {
    final index = _displayFlashcards.indexWhere((c) => c.id == card.id);
    if (index == -1) return;

     _jumpToView(_ViewState(_displayFlashcards, index), addToHistory: true);
  }

  void _navigateToRelatedGroup(Flashcard origin, Flashcard selected) {
    final ids = origin.relatedIds;
    if (ids == null || ids.isEmpty) return;

    List<Flashcard> group = [];
    for (final id in ids) {
      try {
        final match = widget.flashcards.firstWhere((c) => c.id == id);
        group.add(match);
      } catch (_) {}
    }
    if (group.isEmpty) return;

    int newIndex = group.indexWhere((c) => c.id == selected.id);
    if (newIndex == -1) {
      group.insert(0, selected);
      newIndex = 0;
    }


    _ignorePageChange = true;
    _pageController.jumpToPage(index);
    setState(() {
      _currentIndex = index;
    });
   _pushHistory(index);
    _loadFavoriteStatus();
    _addHistoryEntry();
  }

  void _navigateToRelatedGroup(Flashcard origin, Flashcard selected) {
    final ids = origin.relatedIds;
    if (ids == null || ids.isEmpty) return;

    List<Flashcard> group = [];
    for (final id in ids) {
      try {
        final match = widget.flashcards.firstWhere((c) => c.id == id);
        group.add(match);
      } catch (_) {}
    }
    if (group.isEmpty) return;

    int newIndex = group.indexWhere((c) => c.id == selected.id);
    if (newIndex == -1) {
      group.insert(0, selected);
      newIndex = 0;
    }

  _jumpToView(_ViewState(group, newIndex), addToHistory: true);
  }

  void _showRelatedTermDialog(Flashcard selected, Flashcard origin) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
            _navigateToRelatedGroup(origin, selected);
          },
          child: AlertDialog(
            title: Text(selected.term),
            content: Text(selected.description),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('閉じる'),
              ),
            ],
          ),
        );
      },
    );
@@ -409,50 +462,51 @@ class _WordDetailContentState extends State<WordDetailContent> {
          _buildRelatedTermsSection(context, card),
          _buildDetailItem(
            context,
            'タグ (Tags):',
            card.tags?.join('、'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _displayFlashcards.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              _loadFavoriteStatus();
              _addHistoryEntry();
              _pushHistory();
            },
            itemBuilder: (context, index) {
              return _buildFlashcardDetail(context, _displayFlashcards[index]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: _currentIndex > 0
                    ? () {
                        _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      }
                    : null,
                child: const Text('前へ'),
              ),
              Text('${_currentIndex + 1} / ${_displayFlashcards.length}'),
              TextButton(
                onPressed: _currentIndex < _displayFlashcards.length - 1
                    ? () {


                        _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      }
                    : null,
                child: const Text('次へ'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
