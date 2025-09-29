import 'package:flutter/material.dart';

import '../tabs_content/favorites_tab_content.dart';
import '../app_view.dart';

class FavoritesContent extends StatelessWidget {
  final void Function(AppScreen, {ScreenArguments? args}) navigateTo;

  const FavoritesContent({super.key, required this.navigateTo});

  @override
  Widget build(BuildContext context) {
    return FavoritesTabContent(
      key: const ValueKey('FavoritesTabContent'),
      navigateTo: navigateTo,
    );
  }
}
