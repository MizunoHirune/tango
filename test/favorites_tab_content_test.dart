import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:tango/app_view.dart';
import 'package:tango/constants.dart';
import 'package:tango/flashcard_model.dart';
import 'package:tango/flashcard_repository_provider.dart';
import 'package:tango/tabs_content/favorites_tab_content.dart';

import 'fakes/fake_flashcard_repository.dart';
import 'test_harness.dart';

void main() {
  initTestHarness();

  late Box<Map> favoritesBox;

  Flashcard _card(String id, String term) => Flashcard(
        id: id,
        term: term,
        reading: term,
        description: 'description $term',
        categoryLarge: 'A',
        categoryMedium: 'B',
        categorySmall: 'C',
        categoryItem: 'D',
        importance: 1,
      );

  setUp(() {
    favoritesBox = Hive.box<Map>(favoritesBoxName);
  });

  tearDown(() async {
    await favoritesBox.clear();
  });

  testWidgets('renders favorite words and filters by star color', (tester) async {
    final cards = [_card('1', 'Red'), _card('2', 'Yellow')];
    await favoritesBox.put('1', {'red': true});
    await favoritesBox.put('2', {'yellow': true});

    final repo = FakeFlashcardRepository(cards);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [flashcardRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: FavoritesTabContent(
            navigateTo: (_, {args}) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Yellow'), findsOneWidget);

    await tester.tap(find.text('赤星'));
    await tester.pumpAndSettle();

    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Yellow'), findsNothing);

    await tester.tap(find.text('赤星'));
    await tester.pumpAndSettle();

    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Yellow'), findsOneWidget);
  });

  testWidgets('toggling star removes word from filtered list', (tester) async {
    final cards = [_card('1', 'Entry')];
    await favoritesBox.put('1', {'red': true, 'blue': false});

    final repo = FakeFlashcardRepository(cards);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [flashcardRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: FavoritesTabContent(
            navigateTo: (_, {args}) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entry'), findsOneWidget);

    await tester.tap(find.byTooltip('赤星を解除'));
    await tester.pumpAndSettle();

    expect(favoritesBox.get('1'), containsPair('red', false));
    expect(find.text('Entry'), findsNothing);
  });

  testWidgets('tapping a word navigates to detail screen', (tester) async {
    final cards = [_card('1', 'Navigate'), _card('2', 'Also')];
    await favoritesBox.put('1', {'red': true});
    await favoritesBox.put('2', {'blue': true});

    final repo = FakeFlashcardRepository(cards);

    AppScreen? lastScreen;
    ScreenArguments? lastArgs;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [flashcardRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: FavoritesTabContent(
            navigateTo: (screen, {args}) {
              lastScreen = screen;
              lastArgs = args;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Navigate'));
    await tester.pumpAndSettle();

    expect(lastScreen, AppScreen.wordDetail);
    expect(lastArgs, isNotNull);
    expect(lastArgs!.flashcards!.first.id, '1');
    expect(lastArgs!.initialIndex, 0);
  });
}
