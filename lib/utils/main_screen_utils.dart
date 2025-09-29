import '../app_view.dart';
import '../word_detail_controller.dart';

String getAppBarTitle(
  AppScreen screen,
  WordDetailController detailController,
  ScreenArguments? args,
) {
  switch (screen) {
    case AppScreen.home:
      return 'ホーム';
    case AppScreen.wordList:
      return '単語一覧';
    case AppScreen.wordDetail:
      final current = detailController.currentFlashcard;
      if (current != null) {
        return current.term;
      }
      if (args?.flashcards != null && args?.initialIndex != null) {
        final list = args!.flashcards!;
        final index = args.initialIndex!;
        if (index >= 0 && index < list.length) {
          return list[index].term;
        }
      }
      return '単語詳細';
    case AppScreen.wordbook:
      return '単語帳';
    case AppScreen.wordbookLibrary:
      return '単語帳ライブラリ';
    case AppScreen.favorites:
      return 'お気に入り';
    case AppScreen.history:
      return '閲覧履歴';
    case AppScreen.quiz:
      return 'クイズ';
    case AppScreen.todaySummary:
      return '今日の学習サマリー';
    case AppScreen.learningHistoryDetail:
      return '学習履歴詳細';
    case AppScreen.about:
      return 'このアプリについて';
    case AppScreen.settings:
      return '設定';
  }
}
