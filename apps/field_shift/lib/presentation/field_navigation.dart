import 'package:flutter/material.dart';

import '../application/field_controller.dart';
import '../application/field_language.dart';
import 'field_strings.dart';
import 'workspace_widgets.dart';

const _icons = {
  FieldPage.home: Icons.home_outlined,
  FieldPage.parcels: Icons.grid_view_outlined,
  FieldPage.map: Icons.map_outlined,
  FieldPage.analysis: Icons.insights_outlined,
  FieldPage.rotations: Icons.eco_outlined,
  FieldPage.settings: Icons.settings_outlined,
};

IconData _connectionIcon(FieldController model) {
  if (model.offline) return Icons.cloud_off_outlined;
  return switch (model.networkStatus) {
    NetworkStatus.unverified => Icons.cloud_outlined,
    NetworkStatus.reachable => Icons.cloud_done_outlined,
    NetworkStatus.failed => Icons.cloud_off_outlined,
  };
}

class FieldAppBar extends StatelessWidget implements PreferredSizeWidget {
  final FieldController model;

  const FieldAppBar(this.model, {super.key});

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: preferredSize.height,
    automaticallyImplyLeading: false,
    titleSpacing: 14,
    title: const _Wordmark(color: pine),
    actions: [
      _LanguageMenu(model, color: pine),
      Tooltip(
        message: connectionLabel(context, model),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            _connectionIcon(model),
            size: 22,
            semanticLabel: connectionLabel(context, model),
          ),
        ),
      ),
    ],
  );
}

class FieldSidebar extends StatelessWidget {
  final FieldController model;
  const FieldSidebar(this.model, {super.key});

  @override
  Widget build(BuildContext context) => Material(
    color: pine,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 23, 14, 30),
          child: _Wordmark(color: Colors.white),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final page in FieldPage.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: ListTile(
                    key: ValueKey(page),
                    dense: true,
                    minTileHeight: 48,
                    horizontalTitleGap: 12,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 11),
                    leading: Icon(_icons[page], size: 20),
                    selected: page == model.page,
                    selectedColor: leaf,
                    textColor: const Color(0xffebf0e8),
                    iconColor: const Color(0xffb1c5b7),
                    selectedTileColor: const Color(0xff29483b),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    title: Text(
                      pageLabel(context, page),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: page == model.page
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    onTap: () => model.goTo(page),
                  ),
                ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          indent: 14,
          endIndent: 14,
          color: Color(0xff446255),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 16),
          child: Row(
            children: [
              Icon(_connectionIcon(model), color: leaf, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  connectionLabel(context, model),
                  style: const TextStyle(
                    color: Color(0xffd0ddcf),
                    fontSize: 11,
                  ),
                ),
              ),
              _LanguageMenu(model, color: Colors.white),
            ],
          ),
        ),
      ],
    ),
  );
}

class FieldBottomNavigation extends StatelessWidget {
  final FieldController model;
  const FieldBottomNavigation(this.model, {super.key});

  static const _mainPages = [
    FieldPage.home,
    FieldPage.parcels,
    FieldPage.map,
    FieldPage.rotations,
  ];

  Future<void> _more(BuildContext context) async {
    final page = await showModalBottomSheet<FieldPage>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final page in [FieldPage.analysis, FieldPage.settings])
                ListTile(
                  leading: Icon(_icons[page], color: forest),
                  title: Text(pageLabel(context, page)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  selected: page == model.page,
                  onTap: () => Navigator.pop(context, page),
                ),
            ],
          ),
        ),
      ),
    );
    if (context.mounted && page != null) model.goTo(page);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _mainPages.indexOf(model.page);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 5, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2c152d24),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final active = states.contains(WidgetState.selected);
                return IconThemeData(
                  size: 21,
                  color: active ? pine : const Color(0xffe7f1e5),
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final active = states.contains(WidgetState.selected);
                return TextStyle(
                  color: active ? leaf : const Color(0xffe7f1e5),
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0,
                );
              }),
            ),
            child: NavigationBar(
              height: 66,
              backgroundColor: const Color(0xf3143028),
              surfaceTintColor: Colors.transparent,
              indicatorColor: leaf,
              selectedIndex: selected < 0 ? _mainPages.length : selected,
              onDestinationSelected: (index) {
                if (index == _mainPages.length) {
                  _more(context);
                } else {
                  model.goTo(_mainPages[index]);
                }
              },
              destinations: [
                for (final (page, label) in [
                  (FieldPage.home, context.t('Home', 'Inicio')),
                  (FieldPage.parcels, context.t('Fields', 'Parcelas')),
                  (FieldPage.map, context.t('Map', 'Mapa')),
                  (FieldPage.rotations, context.t('Plan', 'Plan')),
                ])
                  NavigationDestination(
                    key: ValueKey(page),
                    icon: Icon(_icons[page]),
                    label: label,
                    tooltip: pageLabel(context, page),
                  ),
                NavigationDestination(
                  key: const ValueKey('more-navigation'),
                  icon: const Icon(Icons.more_horiz),
                  label: context.t('More', 'Más'),
                  tooltip: context.t(
                    'Observations and settings',
                    'Observaciones y configuración',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  final Color color;
  const _Wordmark({required this.color});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(
          color: leaf,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const SizedBox(
          width: 35,
          height: 35,
          child: Icon(Icons.grass_rounded, color: pine, size: 21),
        ),
      ),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          'NASA Field Shift',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 17,
            letterSpacing: -0.35,
          ),
        ),
      ),
    ],
  );
}

class _LanguageMenu extends StatelessWidget {
  final FieldController model;
  final Color color;
  const _LanguageMenu(this.model, {required this.color});

  @override
  Widget build(BuildContext context) => PopupMenuButton<FieldLanguage>(
    key: const ValueKey('language-menu'),
    tooltip: context.t('Change language', 'Cambiar idioma'),
    initialValue: model.language.value,
    enabled: !model.isBusy,
    onSelected: model.setLanguage,
    itemBuilder: (_) => [
      for (final language in FieldLanguage.values)
        PopupMenuItem(value: language, child: Text(language.label)),
    ],
    child: Padding(
      padding: const EdgeInsets.all(9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            model.language.value.code.toUpperCase(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: color, size: 15),
        ],
      ),
    ),
  );
}
