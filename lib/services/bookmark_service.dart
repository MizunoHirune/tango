import 'package:hive/hive.dart';

import '../constants.dart';
import '../models/bookmark.dart';

class BookmarkService {
  final Box<Bookmark> _box;

  BookmarkService([Box<Bookmark>? box])
      : _box = box ?? Hive.box<Bookmark>(bookmarksBoxName);

  Future<void> addBookmark(int pageIndex) async {
    final entry = Bookmark(pageIndex: pageIndex, updated: DateTime.now());
    await _box.put(pageIndex, entry);
  }

  Future<void> removeBookmark(int pageIndex) async {
    await _box.delete(pageIndex);
  }

  bool isBookmarked(int pageIndex) => _box.containsKey(pageIndex);

  List<Bookmark> allBookmarks() {
    final bookmarks = _box.values.toList();
    bookmarks.sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    return bookmarks;
  }

  Future<int?> fetch() async {
    if (_box.isEmpty) return null;
    Bookmark? latest;
    for (final bookmark in _box.values) {
      if (latest == null || bookmark.updated.isAfter(latest.updated)) {
        latest = bookmark;
      }
    }
    return latest?.pageIndex;
  }
}
