// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_view.dart'; // AppScreen enum と ScreenArguments クラス
import 'flashcard_model.dart'; // Flashcard モデル

// 各タブや詳細画面の「コンテンツ」ウィジェットをインポート
import 'main_screen/home_content.dart';
import 'main_screen/word_list_content.dart';
import 'main_screen/favorites_content.dart';
import 'main_screen/history_content.dart';
import 'main_screen/quiz_content.dart';
import 'main_screen/settings_content.dart';
import 'main_screen/learning_history_detail_content.dart';
import 'main_screen/about_content.dart';
import 'main_screen/today_summary_content.dart';
import 'main_screen/word_detail_content.dart';
import 'main_screen/wordbook_content.dart';
import 'tabs_content/word_list_tab_content.dart';
import 'wordbook_screen.dart';
import 'review_mode_ext.dart';
import 'review_service.dart';
import 'word_detail_controller.dart';
import 'word_list_query.dart';
import 'overflow_menu.dart';
import 'navigation_helper.dart';
import 'utils/main_screen_utils.dart';
import 'main_screen/main_navigation_bar.dart';
import 'models/word.dart';
import 'flashcard_repository_provider.dart';
import 'manga_word_viewer.dart';
import 'tabs_content/wordbook_library_tab_content.dart';
import 'sample_decks.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _bottomNavIndex = 0;
  AppScreen _currentScreen = AppScreen.home;
  ScreenArguments? _currentArguments;
  final WordDetailController _detailController = WordDetailController();
  final GlobalKey<WordListTabContentState> _wordListKey =
      GlobalKey<WordListTabContentState>();
  final GlobalKey<WordbookScreenState> _wordbookKey =
      GlobalKey<WordbookScreenState>();
  int _wordbookIndex = 0;
  ReviewMode _reviewMode = ReviewMode.random;

  /// Convert [Flashcard] to [Word] for MangaWordViewer.
  Word _toWord(Flashcard fc) {
    return Word(
      id: fc.id,
      term: fc.term,
      reading: fc.reading,
      description: fc.description,
      relatedIds: fc.relatedIds,
      tags: fc.tags,
      examExample: fc.examExample,
      examPoint: fc.examPoint,
      practicalTip: fc.practicalTip,
      categoryLarge: fc.categoryLarge,
      categoryMedium: fc.categoryMedium,
      categorySmall: fc.categorySmall,
      categoryItem: fc.categoryItem,
      importance: fc.importance,
      english: fc.english,
    );
  }


  Widget _buildCurrentScreenContent() {
    switch (_currentScreen) {
      case AppScreen.home:
        return HomeContent(navigateTo: _navigateTo);
      case AppScreen.wordList:
        return WordListContent(
          listKey: _wordListKey,
          navigateTo: _navigateTo,
        );
      case AppScreen.wordDetail:
        return WordDetailContentWrapper(
          arguments: _currentArguments,
          controller: _detailController,
          navigateTo: _navigateTo,
        );
      case AppScreen.wordbook:
        return WordbookContent(
          arguments: _currentArguments,
          wordbookKey: _wordbookKey,
          onIndexChanged: (i) {
            setState(() {
              _wordbookIndex = i;
            });
          },
        );
      case AppScreen.wordbookLibrary:
        final decks = _currentArguments?.decks;
        if (decks != null) {
          return WordbookLibraryTabContent(decks: decks);
        }
        return const Center(child: CircularProgressIndicator());
      case AppScreen.favorites:
        return FavoritesContent(navigateTo: _navigateTo);
      case AppScreen.history:
        return const HistoryContent();
      case AppScreen.quiz:
        return QuizContent(
          mode: _reviewMode,
          navigateTo: _navigateTo,
        );
      case AppScreen.todaySummary:
        return TodaySummaryContent(navigateTo: _navigateTo);
      case AppScreen.learningHistoryDetail:
        return const LearningHistoryDetailContent();
      case AppScreen.about:
        return const AboutContent();
      case AppScreen.settings:
        return const SettingsContent();
    }
  }

  Future<void> _openWordbookLibrary() async {
    final repo = ref.read(flashcardRepositoryProvider);
    final decks = await loadDefaultDecks(repo);
    if (!mounted) return;
    _navigateTo(
      AppScreen.wordbookLibrary,
      args: ScreenArguments(decks: decks),
    );
  }

  void _onBottomNavItemTapped(int index) {
    if (_bottomNavIndex == index &&
        _currentScreen == appScreenFromIndex(index) &&
        _currentScreen != AppScreen.wordDetail &&
        _currentScreen != AppScreen.settings) {
      return;
    }
    if (index == 2) {
      _openWordbookLibrary();
      return;
    }
    setState(() {
      _bottomNavIndex = index;
      _currentScreen = appScreenFromIndex(index);
      _currentArguments = null;
    });
  }

  void _navigateTo(AppScreen screen, {ScreenArguments? args}) {
    if (!mounted) return;
    setState(() {
      _currentScreen = screen;
      _currentArguments = args;
      _bottomNavIndex = indexFromAppScreen(screen, _bottomNavIndex);
    });
  }


  @override
  Widget build(BuildContext context) {
    final words = ref.watch(wordListForModeProvider);
    final query = ref.watch(currentQueryProvider);
    final filtered = words != null ? query.apply(words) : <Flashcard>[];

    bool canGoBack = _currentScreen == AppScreen.wordDetail ||
        _currentScreen == AppScreen.settings ||
        _currentScreen == AppScreen.learningHistoryDetail ||
        _currentScreen == AppScreen.todaySummary ||
        _currentScreen == AppScreen.about;
    AppScreen screenToNavigateBack =
        appScreenFromIndex(_bottomNavIndex); // デフォルトは現在のタブのトップ
    if (_currentScreen == AppScreen.wordDetail) {
      screenToNavigateBack = AppScreen.wordList;
    } else if (_currentScreen == AppScreen.settings) {
      // 設定画面から戻る場合は、最後にアクティブだったボトムナビのタブ、または固定でホームなど
      screenToNavigateBack = appScreenFromIndex(_bottomNavIndex);
    } else if (_currentScreen == AppScreen.learningHistoryDetail ||
        _currentScreen == AppScreen.todaySummary) {
      screenToNavigateBack = AppScreen.home;
    } else if (_currentScreen == AppScreen.about) {
      screenToNavigateBack = AppScreen.home;
    }

    return Scaffold(
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: _detailController,
          builder: (context, _) {
            final baseTitle =
                getAppBarTitle(_currentScreen, _detailController, _currentArguments);
            if (_currentScreen == AppScreen.wordList && words != null) {
              return Text(
                  '$baseTitle (${filtered.length} / ${words.length} 件)');
            } else if (_currentScreen == AppScreen.wordbook &&
                _currentArguments?.flashcards != null) {
              final total = _currentArguments!.flashcards!.length;
              return Text('$baseTitle (${_wordbookIndex + 1} / $total)');
            }
            return Text(baseTitle);
          },
        ),
        leadingWidth: _currentScreen == AppScreen.wordDetail ? 96 : null,
        leading: _currentScreen == AppScreen.wordDetail
            ? AnimatedBuilder(
                animation: _detailController,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _detailController.canGoBack
                            ? () {
                                _detailController.back();
                              }
                            : null,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _detailController.canGoForward
                            ? () {
                                _detailController.forward();
                              }
                            : null,
                      ),
                    ],
                  );
                },
              )
            : (canGoBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _navigateTo(screenToNavigateBack,
                          args: _currentArguments);
                    },
                  )
                : null),
        actions: [
          if (_currentScreen == AppScreen.wordList ||
              _currentScreen == AppScreen.quiz)
            DropdownButtonHideUnderline(
              child: DropdownButton<ReviewMode>(
                value: _reviewMode,
                icon: const Icon(Icons.arrow_drop_down),
                onChanged: (mode) {
                  if (mode == null) return;
                  setState(() {
                    _reviewMode = mode;
                  });
                  _wordListKey.currentState?.updateMode(mode);
                },
                items: ReviewMode.values
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.label),
                        ))
                    .toList(),
              ),
            ),
          if (_currentScreen == AppScreen.wordList)
            OverflowMenu(
              onOpenSheet: () {
                _wordListKey.currentState?.openFilterSheet(context);
              },
            ),
          if (_currentScreen == AppScreen.wordbook)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _wordbookKey.currentState?.openSearch();
              },
            ),
          if (_currentScreen != AppScreen.settings)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '設定',
              onPressed: () {
                _navigateTo(AppScreen.settings,
                    args: _currentArguments);
              },
            ),
        ],
      ),
      body: _buildCurrentScreenContent(),
      bottomNavigationBar: MainNavigationBar(
        currentIndex: _bottomNavIndex,
        currentScreen: _currentScreen,
        onTap: _onBottomNavItemTapped,
      ),
    );
  }
}
