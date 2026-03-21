// ignore_for_file: implementation_imports, invalid_use_of_internal_member

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/widgetbook/story_catalog.dart';
import 'package:widgetbook/widgetbook.dart' as wb;
import 'package:widgetbook/src/layout/desktop_layout.dart';
import 'package:widgetbook/src/navigation/widgets/navigation_panel.dart';
import 'package:widgetbook/src/routing/app_route_config.dart';
import 'package:widgetbook/src/routing/app_route_parser.dart';
import 'package:widgetbook/src/settings/mobile_settings_panel.dart';
import 'package:widgetbook/src/widgetbook_theme.dart' as wb_shell;
import 'package:widgetbook/src/workbench/workbench.dart';

class PocketRelayWidgetbook extends StatefulWidget {
  const PocketRelayWidgetbook({super.key});

  @override
  State<PocketRelayWidgetbook> createState() => _PocketRelayWidgetbookState();
}

class _PocketRelayWidgetbookState extends State<PocketRelayWidgetbook> {
  late final wb.WidgetbookState state;
  late final _PocketRelayAppRouter router;

  @override
  void initState() {
    super.initState();
    state = wb.WidgetbookState(
      appBuilder: wb.materialAppBuilder,
      addons: _addons,
      root: wb.WidgetbookRoot(children: buildPocketRelayWidgetbookCatalog()),
      home: const _PocketRelayWidgetbookHome(),
      header: const _PocketRelayWidgetbookHeader(),
    );
    router = _PocketRelayAppRouter(
      state: state,
      uri: Uri.base.fragment.isNotEmpty
          ? Uri.parse(Uri.base.fragment)
          : Uri.parse('/'),
    );
  }

  List<wb.WidgetbookAddon> get _addons => <wb.WidgetbookAddon>[
    wb.MaterialThemeAddon(
      themes: <wb.WidgetbookTheme<ThemeData>>[
        wb.WidgetbookTheme<ThemeData>(
          name: 'Pocket Light',
          data: buildPocketTheme(Brightness.light),
        ),
        wb.WidgetbookTheme<ThemeData>(
          name: 'Pocket Dark',
          data: buildPocketTheme(Brightness.dark),
        ),
      ],
    ),
    wb.ViewportAddon(<wb.ViewportData>[
      wb.Viewports.none,
      wb.IosViewports.iPhone13,
      wb.MacosViewports.desktop,
      wb.MacosViewports.macbookPro,
    ]),
    wb.TextScaleAddon(initialScale: 1.0, min: 0.8, max: 1.4, divisions: 3),
  ];

  @override
  Widget build(BuildContext context) {
    return wb.WidgetbookScope(
      state: state,
      child: MaterialApp.router(
        title: 'Pocket Relay Widgetbook',
        themeMode: ThemeMode.system,
        theme: _buildWidgetbookShellTheme(Brightness.light),
        darkTheme: _buildWidgetbookShellTheme(Brightness.dark),
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

ThemeData _buildWidgetbookShellTheme(Brightness brightness) {
  final base = buildPocketTheme(brightness);
  final palette = base.extension<PocketPalette>()!;
  final isDark = brightness == Brightness.dark;
  final solidSurface = palette.surface;

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      surface: solidSurface,
      onSurface: isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917),
      surfaceContainerHighest: isDark
          ? const Color(0xFF2B2924)
          : const Color(0xFFE9E2D5),
      outline: palette.surfaceBorder,
      primary: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0F766E),
      secondary: isDark ? const Color(0xFFC4B5FD) : const Color(0xFF7C3AED),
    ),
    canvasColor: solidSurface,
    scaffoldBackgroundColor: palette.backgroundBottom,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: solidSurface,
      modalBackgroundColor: solidSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: solidSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    cardTheme: CardThemeData(
      color: solidSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: palette.surfaceBorder),
      ),
    ),
    dividerColor: palette.surfaceBorder,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      isDense: true,
      fillColor: isDark ? const Color(0xFF454850) : const Color(0xFFE8E4DA),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0F766E),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.transparent),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: solidSurface,
      selectedItemColor: isDark
          ? const Color(0xFF7DD3FC)
          : const Color(0xFF0F766E),
      unselectedItemColor:
          (isDark ? const Color(0xFFF4F2ED) : const Color(0xFF1C1917))
              .withValues(alpha: 0.7),
      type: BottomNavigationBarType.fixed,
    ),
  );
}

class _PocketRelayAppRouter extends RouterConfig<AppRouteConfig> {
  _PocketRelayAppRouter({required wb.WidgetbookState state, required Uri uri})
    : super(
        routeInformationParser: AppRouteParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(uri: uri),
        ),
        routerDelegate: _PocketRelayRouterDelegate(uri: uri, state: state),
      );
}

class _PocketRelayRouterDelegate extends RouterDelegate<AppRouteConfig>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRouteConfig> {
  _PocketRelayRouterDelegate({required this.uri, required this.state})
    : _navigatorKey = GlobalKey<NavigatorState>(),
      _configuration = AppRouteConfig(uri: uri);

  final Uri uri;
  final wb.WidgetbookState state;
  final GlobalKey<NavigatorState> _navigatorKey;
  AppRouteConfig _configuration;

  @override
  AppRouteConfig? get currentConfiguration => _configuration;

  @override
  GlobalKey<NavigatorState>? get navigatorKey => _navigatorKey;

  @override
  Future<void> setNewRoutePath(AppRouteConfig configuration) async {
    _configuration = configuration;
    state.updateFromRouteConfig(configuration);
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return wb_shell.WidgetbookTheme(
      data: theme,
      child: Navigator(
        key: navigatorKey,
        onDidRemovePage: (_) => {},
        pages: <Page<dynamic>>[
          MaterialPage<dynamic>(
            child: _configuration.previewMode
                ? const Workbench()
                : _PocketRelayResponsiveLayout(
                    key: ValueKey<AppRouteConfig>(_configuration),
                    child: const Workbench(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PocketRelayResponsiveLayout extends StatelessWidget {
  const _PocketRelayResponsiveLayout({super.key, required this.child});

  final Widget child;

  Widget _buildNavigation(BuildContext context, bool isMobile) {
    final state = wb.WidgetbookState.of(context);
    return NavigationPanel(
      initialPath: state.path,
      root: state.root,
      header: state.header,
      onNodeSelected: (node) {
        wb.WidgetbookState.of(context).updatePath(node.path);
        if (isMobile) {
          Navigator.pop(context);
        }
      },
    );
  }

  List<Widget> _buildAddons(BuildContext context) {
    final state = wb.WidgetbookState.of(context);
    return state.effectiveAddons
            ?.map((addon) => addon.buildFields(context))
            .toList() ??
        const <Widget>[];
  }

  List<Widget> _buildKnobs(BuildContext context) {
    final state = wb.WidgetbookState.of(context);
    return state.knobs.values.map((knob) => knob.buildFields(context)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = wb.WidgetbookState.of(context);
    final isEmbedded = state.panels != null;
    final isMobile = MediaQuery.of(context).size.width < 840;

    return isMobile && !isEmbedded
        ? _PocketRelayMobileLayout(
            navigationBuilder: (context) => _buildNavigation(context, true),
            addonsBuilder: _buildAddons,
            knobsBuilder: _buildKnobs,
            workbench: child,
          )
        : DesktopLayout(
            navigationBuilder: (context) => _buildNavigation(context, false),
            addonsBuilder: _buildAddons,
            knobsBuilder: _buildKnobs,
            workbench: child,
          );
  }
}

class _PocketRelayMobileLayout extends StatelessWidget {
  const _PocketRelayMobileLayout({
    required this.navigationBuilder,
    required this.addonsBuilder,
    required this.knobsBuilder,
    required this.workbench,
  });

  final Widget Function(BuildContext context) navigationBuilder;
  final List<Widget> Function(BuildContext context) addonsBuilder;
  final List<Widget> Function(BuildContext context) knobsBuilder;
  final Widget workbench;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: workbench),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            label: 'Navigation',
            icon: Icon(Icons.list_outlined),
          ),
          BottomNavigationBarItem(
            label: 'Addons',
            icon: Icon(Icons.dashboard_customize_outlined),
          ),
          BottomNavigationBarItem(
            label: 'Knobs',
            icon: Icon(Icons.tune_outlined),
          ),
        ],
        onTap: (index) => _showPanel(context, index),
      ),
    );
  }

  Future<void> _showPanel(BuildContext context, int index) {
    final Widget panel = switch (index) {
      0 => navigationBuilder(context),
      1 => MobileSettingsPanel(name: 'Addons', builder: addonsBuilder),
      _ => MobileSettingsPanel(name: 'Knobs', builder: knobsBuilder),
    };

    final height = MediaQuery.of(context).size.height * 0.92;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
      builder: (context) {
        return SizedBox(
          height: height,
          child: Material(
            color: Theme.of(context).bottomSheetTheme.modalBackgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: panel),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PocketRelayWidgetbookHeader extends StatelessWidget {
  const _PocketRelayWidgetbookHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pocket Relay',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Design Review Catalog',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

class _PocketRelayWidgetbookHome extends StatelessWidget {
  const _PocketRelayWidgetbookHome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = wb.WidgetbookState.of(context);
    final counts =
        '${state.root.componentsCount} components · ${state.root.useCasesCount} use cases';

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 420,
                  child: _HomePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pocket Relay Widgetbook',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A reviewable catalog for transcript components, shared primitives, and product scenes.',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.76,
                            ),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _MetricPill(label: counts),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: _HomePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _ChecklistItem(
                          title: 'Foundations',
                          body:
                              'Review badges, panel surfaces, and transcript framing before feature-level states.',
                        ),
                        SizedBox(height: 16),
                        _ChecklistItem(
                          title: 'Transcript Cards',
                          body:
                              'Validate approval, plan, changed-file, work-log, and SSH variants across themes.',
                        ),
                        SizedBox(height: 16),
                        _ChecklistItem(
                          title: 'Review Scenes',
                          body:
                              'Use the mixed transcript scenes for real state-flow review instead of isolated widgets only.',
                        ),
                      ],
                    ),
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

class _HomePanel extends StatelessWidget {
  const _HomePanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<PocketPalette>()!;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: Padding(padding: const EdgeInsets.all(24), child: child),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
