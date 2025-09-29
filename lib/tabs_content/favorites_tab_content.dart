import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../app_view.dart';
import '../constants.dart';
import '../flashcard_model.dart';
import '../flashcard_repository_provider.dart';
import '../star_color.dart';

class FavoritesTabContent extends ConsumerStatefulWidget {
  final void Function(AppScreen, {ScreenArguments? args}) navigateTo;

  const FavoritesTabContent({super.key, required this.navigateTo});

  @override
  ConsumerState<FavoritesTabContent> createState() => _FavoritesTabContentState();
}

class _FavoriteEntry {
  final Flashcard card;
  final Set<StarColor> stars;

  const _FavoriteEntry(this.card, this.stars);
}

class _FavoritesTabContentState extends ConsumerState<FavoritesTabContent> {
  late final Box<Map> _favoritesBox;
  bool _loading = true;
  String? _error;
  List<Flashcard> _allCards = const [];
  final Set<StarColor> _filters = {};

  @override
  void initState() {
    super.initState();
    _favoritesBox = Hive.box<Map>(favoritesBoxName);
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await ref.read(flashcardRepositoryProvider).loadAll();
      if (!mounted) return;
      setState(() {
        _allCards = cards;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '単語データの読み込みに失敗しました。';
        _loading = false;
      });
    }
  }

  void _toggleFilter(StarColor color) {
    setState(() {
      if (_filters.contains(color)) {
        _filters.remove(color);
      } else {
        _filters.add(color);
      }
    });
  }

  StarColor? _starFromKey(String key) {
    for (final color in StarColor.values) {
      if (color.name == key) {
        return color;
      }
    }
    return null;
  }

  List<_FavoriteEntry> _entriesFrom(Box<Map> box) {
    if (_allCards.isEmpty) {
      return const [];
    }
    final idToCard = {for (final card in _allCards) card.id: card};
    final List<_FavoriteEntry> entries = [];
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final card = idToCard[key];
      if (card == null) continue;
      final stars = <StarColor>{};
      raw.forEach((dynamic k, dynamic v) {
        if (v == true) {
          final color = _starFromKey(k.toString());
          if (color != null) {
            stars.add(color);
          }
        }
      });
      if (stars.isEmpty) continue;
      entries.add(_FavoriteEntry(card, stars));
    }
    entries.sort((a, b) => a.card.term.compareTo(b.card.term));
    return entries;
  }

  Future<void> _toggleStar(String wordId, StarColor color) async {
    final raw = _favoritesBox.get(wordId);
    final status = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value == true))
        : <String, bool>{};
    final current = status[color.name] ?? false;
    status[color.name] = !current;
    await _favoritesBox.put(wordId, status);
  }

  Color _colorFor(ThemeData theme, StarColor color) {
    switch (color) {
      case StarColor.red:
        return theme.colorScheme.error;
      case StarColor.yellow:
        return theme.colorScheme.secondary;
      case StarColor.blue:
        return theme.colorScheme.primary;
    }
  }

  Widget _buildFilters(BuildContext context, {required bool hasFavorites}) {
    final theme = Theme.of(context);
    final chips = StarColor.values.map((color) {
      final selected = _filters.contains(color);
      return FilterChip(
        avatar: Icon(
          Icons.star,
          size: 18,
          color: selected ? Colors.white : _colorFor(theme, color),
        ),
        label: Text('${color.label}星'),
        selected: selected,
        onSelected: hasFavorites ? (_) => _toggleFilter(color) : null,
      );
    }).toList();
    if (_filters.isNotEmpty) {
      chips.add(
        TextButton.icon(
          onPressed: () => setState(() => _filters.clear()),
          icon: const Icon(Icons.clear),
          label: const Text('フィルター解除'),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: chips,
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context, {required bool hasAnyFavorites}) {
    final text = hasAnyFavorites
        ? '選択した星の条件に一致する単語がありません。'
        : 'お気に入りの単語はまだありません。';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  Widget _buildStarControls(_FavoriteEntry entry, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: StarColor.values.map((color) {
        final active = entry.stars.contains(color);
        return IconButton(
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          icon: Icon(
            active ? Icons.star : Icons.star_border,
            color: active ? _colorFor(theme, color) : theme.colorScheme.outline,
          ),
          tooltip: active ? '${color.label}星を解除' : '${color.label}星を付与',
          onPressed: () => _toggleStar(entry.card.id, color),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
            ElevatedButton(
              onPressed: _loadCards,
              child: const Text('再試行'),
            )
          ],
        ),
      );
    }

    return ValueListenableBuilder<Box<Map>>(
      valueListenable: _favoritesBox.listenable(),
      builder: (context, box, _) {
        final entries = _entriesFrom(box);
        final filtered = _filters.isEmpty
            ? entries
            : entries
                .where((entry) => entry.stars.any(_filters.contains))
                .toList();
        final cards = filtered.map((e) => e.card).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilters(context, hasFavorites: entries.isNotEmpty),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _filters.isEmpty
                    ? 'お気に入り: ${entries.length}件'
                    : 'お気に入り: ${filtered.length} / ${entries.length}件',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            if (filtered.isEmpty)
              Expanded(
                child: _buildEmptyView(
                  context,
                  hasAnyFavorites: entries.isNotEmpty,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final theme = Theme.of(context);
                    return Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(entry.card.term),
                        subtitle: Text(
                          entry.card.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: _buildStarControls(entry, theme),
                        onTap: () {
                          widget.navigateTo(
                            AppScreen.wordDetail,
                            args: ScreenArguments(
                              flashcards: cards,
                              initialIndex: index,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
