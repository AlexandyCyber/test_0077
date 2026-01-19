import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.loadPrefs();
  runApp(AppStateScope(notifier: appState, child: const MyApp()));
}

/* =========================
   App State (Theme + Data + Tabs)
========================= */

enum TxType { income, expense }

class Category {
  final String id;
  final String name;
  final String emoji;
  final TxType type;

  Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
  });
}

class TxItem {
  final String id;
  TxType type;
  double amount;
  String categoryId;
  String note;
  DateTime date;

  TxItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.note,
    required this.date,
  });
}

class AppState extends ChangeNotifier {
  static const _kPrefOnboarded = 'onboarded';
  static const _kPrefThemeMode = 'themeMode'; // 0=system 1=light 2=dark

  bool onboarded = false;
  ThemeMode themeMode = ThemeMode.light;

  // Bottom nav
  int currentTabIndex = 0;
  void setTab(int index) {
    currentTabIndex = index;
    notifyListeners();
  }

  String searchQuery = '';
  TxType? filterType; // null = all

  final List<Category> categories = [
    Category(id: 'c_food', name: 'อาหาร', emoji: '🍔', type: TxType.expense),
    Category(id: 'c_car', name: 'รถยนต์', emoji: '🚗', type: TxType.expense),
    Category(id: 'c_fun', name: 'ความบันเทิง', emoji: '🎮', type: TxType.expense),
    Category(id: 'c_home', name: 'บ้าน', emoji: '🏠', type: TxType.expense),
    Category(id: 'c_salary', name: 'เงินเดือน', emoji: '💰', type: TxType.income),
  ];

  final List<TxItem> transactions = [
    TxItem(
      id: 't1',
      type: TxType.expense,
      amount: 150,
      categoryId: 'c_food',
      note: '',
      date: DateTime(2026, 1, 22),
    ),
    TxItem(
      id: 't2',
      type: TxType.expense,
      amount: 800,
      categoryId: 'c_car',
      note: 'เติมเต็มถัง',
      date: DateTime(2026, 1, 21),
    ),
    TxItem(
      id: 't3',
      type: TxType.income,
      amount: 20000,
      categoryId: 'c_salary',
      note: 'เงินเดือน',
      date: DateTime(2026, 1, 20),
    ),
  ];

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool(_kPrefOnboarded) ?? false;

    final tm = prefs.getInt(_kPrefThemeMode) ?? 1;
    themeMode = switch (tm) {
      0 => ThemeMode.system,
      2 => ThemeMode.dark,
      _ => ThemeMode.light,
    };
  }

  Future<void> setOnboarded(bool value) async {
    onboarded = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefOnboarded, value);
  }

  Future<void> toggleTheme() async {
    themeMode = (themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefThemeMode, themeMode == ThemeMode.dark ? 2 : 1);
  }

  void setSearch(String q) {
    searchQuery = q;
    notifyListeners();
  }

  void setFilter(TxType? type) {
    filterType = type;
    notifyListeners();
  }

  void clearSearchAndFilter() {
    searchQuery = '';
    filterType = null;
    notifyListeners();
  }

  Category categoryById(String id) => categories.firstWhere((c) => c.id == id);

  List<TxItem> get visibleTransactions {
    List<TxItem> list = [...transactions];
    list.sort((a, b) => b.date.compareTo(a.date));

    if (filterType != null) {
      list = list.where((t) => t.type == filterType).toList();
    }

    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((t) {
        final cat = categoryById(t.categoryId);
        final hay = '${cat.name} ${cat.emoji} ${t.note}'.toLowerCase();
        return hay.contains(q);
      }).toList();
    }
    return list;
  }

  double get totalIncome => transactions
      .where((t) => t.type == TxType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => t.type == TxType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  void addTransaction(TxItem item) {
    transactions.add(item);
    notifyListeners();
  }

  void updateTransaction(TxItem updated) {
    final idx = transactions.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      transactions[idx] = updated;
      notifyListeners();
    }
  }

  void deleteTransaction(String id) {
    transactions.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void reorderCategories(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);
    notifyListeners();
  }

  void addCategory(Category c) {
    categories.add(c);
    notifyListeners();
  }

  void deleteCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    notifyListeners();
  }
}

/* =========================
   AppStateScope
========================= */

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found');
    return scope!.notifier!;
  }
}

/* =========================
   MyApp + Theme
========================= */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    );

    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B5CF6),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1020),
    );

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return MaterialApp(
          
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavKey,
          title: 'My Money Tracker',
          theme: light,
          darkTheme: dark,
          themeMode: state.themeMode,
          home: state.onboarded ? const RootShell() : const OnboardingScreen(),
        );
      },
    );
  }
}

/* =========================
   UI Helpers: Animated Tap (AnimatedContainer) + AppButton
========================= */

class ScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
  });

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(14);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_down ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: br),
        child: ClipRRect(borderRadius: br, child: widget.child),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? foreground;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.foreground,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ScaleTap(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              color ?? scheme.primary,
              (color ?? scheme.primary).withOpacity(0.85),
            ],
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: (color ?? scheme.primary).withOpacity(0.25),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground ?? Colors.white),
              const SizedBox(width: 10),
            ],
            Text(
              text,
              style: TextStyle(
                color: foreground ?? Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).cardTheme.color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
      ),
      child: child,
    );
  }
}

/* =========================
   RootShell (Bottom Navigation: Dashboard / Add / Categories / Settings)
   - ใช้ Offstage Navigators เพื่อจำสถานะแต่ละแท็บ
========================= */

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final _keys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  Future<bool> _onWillPop(AppState state) async {
    final nav = _keys[state.currentTabIndex].currentState!;
    if (nav.canPop()) {
      nav.pop();
      return false;
    }
    return true; // ออกแอป
  }

  void _selectTab(AppState state, int index) {
    if (index == state.currentTabIndex) {
      _keys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    state.setTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return WillPopScope(
          onWillPop: () => _onWillPop(state),
          child: Scaffold(
            body: Stack(
              children: [
                _buildOffstageNavigator(0, state.currentTabIndex == 0, _keys[0], (_) => const DashboardScreen()),
                _buildOffstageNavigator(1, state.currentTabIndex == 1, _keys[1], (_) => const TransactionFormScreen(asRootTab: true)),
                _buildOffstageNavigator(2, state.currentTabIndex == 2, _keys[2], (_) => const CategoriesScreen(asTab: true)),
                _buildOffstageNavigator(3, state.currentTabIndex == 3, _keys[3], (_) => const SettingsScreen()),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: state.currentTabIndex,
              onDestinationSelected: (i) => _selectTab(state, i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                NavigationDestination(icon: Icon(Icons.add_circle_rounded), label: 'Add'),
                NavigationDestination(icon: Icon(Icons.category_rounded), label: 'Categories'),
                NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOffstageNavigator(
    int index,
    bool active,
    GlobalKey<NavigatorState> key,
    WidgetBuilder rootBuilder,
  ) {
    return Offstage(
      offstage: !active,
      child: TickerMode(
        enabled: active,
        child: Navigator(
          key: key,
          onGenerateRoute: (settings) => MaterialPageRoute(builder: rootBuilder),
        ),
      ),
    );
  }
}

/* =========================
   Onboarding (3 pages PageView)
========================= */

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _index = 0;

  final _pages = const [
    _OnboardPageData(
      icon: Icons.savings_rounded,
      title: 'บันทึกรายรับรายจ่าย',
      desc: 'เพิ่มรายการไว ๆ พร้อมหมวดหมู่ ชัดเจน ดูยอดคงเหลือทันที',
    ),
    _OnboardPageData(
      icon: Icons.search_rounded,
      title: 'ค้นหา & ฟิลเตอร์',
      desc: 'หา “อาหาร/รถ/เงินเดือน” ได้ทันที และกรองรายรับ/รายจ่ายได้',
    ),
    _OnboardPageData(
      icon: Icons.dark_mode_rounded,
      title: 'Dark Mode ทั้งแอป',
      desc: 'สลับโหมดสว่าง/มืดได้จริง พร้อมจำค่าไว้',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final state = AppStateScope.of(context);
    await state.setOnboarded(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    'My Money Tracker',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  ScaleTap(
                    onTap: _finish,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(
                        'ข้าม',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _OnboardPage(p: _pages[i]),
                ),
              ),

              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? scheme.primary : scheme.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              AppButton(
                text: _index == _pages.length - 1 ? 'เริ่มใช้งาน' : 'ถัดไป',
                icon: _index == _pages.length - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onPressed: () async {
                  if (_index < _pages.length - 1) {
                    _pc.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
                  } else {
                    await _finish();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardPageData {
  final IconData icon;
  final String title;
  final String desc;

  const _OnboardPageData({
    required this.icon,
    required this.title,
    required this.desc,
  });
}

class _OnboardPage extends StatelessWidget {
  final _OnboardPageData p;
  const _OnboardPage({required this.p});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(colors: [
                    scheme.primary,
                    scheme.secondary.withOpacity(0.9),
                  ]),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                      color: scheme.primary.withOpacity(0.25),
                    )
                  ],
                ),
                child: Icon(p.icon, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 18),
              Text(
                p.title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              Text(
                p.desc,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
   Dashboard Tab
========================= */

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _fmtMoney(double v) => '฿ ${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final scheme = Theme.of(context).colorScheme;
        final list = state.visibleTransactions;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            actions: [
              // Theme toggle (animated)
              ScaleTap(
                onTap: () => state.toggleTheme(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    state.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Summary
                  Row(
                    children: [
                      Expanded(
                        child: _GlassCard(
                          child: _SummaryTile(
                            title: 'ยอดคงเหลือ',
                            value: _fmtMoney(state.balance),
                            valueStyle: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _GlassCard(
                          child: Column(
                            children: [
                              _SummaryTile(
                                title: 'รายรับ',
                                value: '+${_fmtMoney(state.totalIncome)}',
                                valueStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF16A34A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SummaryTile(
                                title: 'รายจ่าย',
                                value: '-${_fmtMoney(state.totalExpense)}',
                                valueStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Search
                  _GlassCard(
                    child: TextField(
                      onChanged: state.setSearch,
                      decoration: InputDecoration(
                        hintText: 'ค้นหา หมวดหมู่ / หมายเหตุ ...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filter + quick to Categories
                  Row(
                    children: [
                      _FilterChip(
                        label: 'ทั้งหมด',
                        active: state.filterType == null,
                        onTap: () => state.setFilter(null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'รายรับ',
                        active: state.filterType == TxType.income,
                        onTap: () => state.setFilter(TxType.income),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'รายจ่าย',
                        active: state.filterType == TxType.expense,
                        onTap: () => state.setFilter(TxType.expense),
                      ),
                      const Spacer(),
                      ScaleTap(
                        onTap: () => state.setTab(2), // ไปแท็บ Categories
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: scheme.primary.withOpacity(0.12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.category_rounded, color: scheme.primary, size: 18),
                              const SizedBox(width: 6),
                              Text('หมวดหมู่', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // List (Dismissible 2-way)
                  Expanded(
                    child: list.isEmpty
                        ? Center(
                            child: Text(
                              'ไม่พบรายการที่ตรงกับเงื่อนไข',
                              style: TextStyle(color: Theme.of(context).hintColor),
                            ),
                          )
                        : ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final t = list[i];
                              final cat = state.categoryById(t.categoryId);

                              return Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TxDismissibleTile(
    t: t,
    cat: cat,
    state: state,
    dismissBgBuilder: _dismissBg,
    child: _TxCard(cat: cat, t: t),
  ),
);

                            },
                          ),
                  ),

                  AppButton(
                    text: 'เพิ่มรายการใหม่',
                    icon: Icons.add_rounded,
                    onPressed: () => state.setTab(1), // ไปแท็บ Add
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissBg({
    required Color color,
    required IconData icon,
    required String label,
    required bool alignLeft,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _TxCard extends StatelessWidget {
  final Category cat;
  final TxItem t;

  const _TxCard({required this.cat, required this.t});

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isIncome = t.type == TxType.income;
    final amountColor = isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    final sign = isIncome ? '+' : '-';

    return _GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: amountColor.withOpacity(0.12),
            ),
            alignment: Alignment.center,
            child: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  t.note.isEmpty ? _fmtDate(t.date) : '${_fmtDate(t.date)} • ${t.note}',
                  style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$sign฿${t.amount.toStringAsFixed(0)}',
            style: TextStyle(fontWeight: FontWeight.w900, color: amountColor),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final TextStyle? valueStyle;

  const _SummaryTile({
    required this.title,
    required this.value,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: valueStyle ?? const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ScaleTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: active ? scheme.primary : scheme.primary.withOpacity(0.10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : scheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/* =========================
   Add Tab / Transaction Form
   - ถ้า asRootTab=true: บันทึกแล้วเด้งไป Dashboard + เคลียร์ฟอร์ม
========================= */

class TransactionFormScreen extends StatefulWidget {
  final TxItem? existing;
  final bool asRootTab;

  const TransactionFormScreen({super.key, this.existing, this.asRootTab = false});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TxType _type;
  late DateTime _date;
  String? _categoryId;

  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final t = widget.existing;

    _type = t?.type ?? TxType.expense;
    _date = t?.date ?? DateTime.now();
    _categoryId = t?.categoryId;

    if (t != null) {
      _amountCtrl.text = t.amount.toStringAsFixed(0);
      _noteCtrl.text = t.note;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _resetForm(AppState state) {
    _type = TxType.expense;
    _date = DateTime.now();
    _noteCtrl.clear();
    _amountCtrl.clear();
    final cats = state.categories.where((c) => c.type == _type).toList();
    _categoryId = cats.isNotEmpty ? cats.first.id : null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    final availableCats = state.categories.where((c) => c.type == _type).toList();
    _categoryId ??= availableCats.firstOrNull?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add' : 'แก้ไขรายการ'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ประเภท *', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _TypeToggle(
                              label: 'รายรับ',
                              active: _type == TxType.income,
                              color: const Color(0xFF16A34A),
                              onTap: () => setState(() {
                                _type = TxType.income;
                                _categoryId = state.categories.where((c) => c.type == _type).firstOrNull?.id;
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TypeToggle(
                              label: 'รายจ่าย',
                              active: _type == TxType.expense,
                              color: const Color(0xFFDC2626),
                              onTap: () => setState(() {
                                _type = TxType.expense;
                                _categoryId = state.categories.where((c) => c.type == _type).firstOrNull?.id;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('จำนวนเงิน (฿) *', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.payments_rounded),
                        ),
                        validator: (v) {
                          final x = double.tryParse((v ?? '').trim());
                          if (x == null) return 'กรุณากรอกเป็นตัวเลข';
                          if (x <= 0) return 'ต้องมากกว่า 0';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('หมวดหมู่ *', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _categoryId,
                        items: availableCats
                            .map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}')))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.category_rounded),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'กรุณาเลือกหมวดหมู่' : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('หมายเหตุ', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          hintText: 'รายละเอียดเพิ่มเติม...',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _GlassCard(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'วันที่ *  •  ${_fmtDate(_date)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      ScaleTap(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: scheme.primary.withOpacity(0.12),
                          ),
                          child: Text('เลือกวันที่', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                AppButton(
                  text: 'บันทึก',
                  icon: Icons.check_rounded,
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;

                    final amount = double.parse(_amountCtrl.text.trim());
                    final catId = _categoryId!;

                    if (widget.existing == null) {
                      final id = 't_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
                      state.addTransaction(
                        TxItem(
                          id: id,
                          type: _type,
                          amount: amount,
                          categoryId: catId,
                          note: _noteCtrl.text.trim(),
                          date: _date,
                        ),
                      );
                    } else {
                      state.updateTransaction(
                        TxItem(
                          id: widget.existing!.id,
                          type: _type,
                          amount: amount,
                          categoryId: catId,
                          note: _noteCtrl.text.trim(),
                          date: _date,
                        ),
                      );
                    }

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกแล้ว ✅')));

                    if (widget.asRootTab) {
                      _resetForm(state);
                      state.setTab(0); // กลับ Dashboard
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active ? color : color.withOpacity(0.12),
          border: Border.all(color: color.withOpacity(active ? 0.0 : 0.22)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/* =========================
   Categories Tab (ReorderableListView)
========================= */

class CategoriesScreen extends StatelessWidget {
  final bool asTab;
  const CategoriesScreen({super.key, this.asTab = false});

  Future<void> _addCategoryDialog(BuildContext context, AppState state) async {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '✨');
    TxType type = TxType.expense;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('เพิ่มหมวดหมู่ใหม่'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่ *')),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MiniType(
                    label: 'รายจ่าย',
                    active: type == TxType.expense,
                    onTap: () => type = TxType.expense,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniType(
                    label: 'รายรับ',
                    active: type == TxType.income,
                    onTap: () => type = TxType.income,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final name = nameCtrl.text.trim();
      final emoji = emojiCtrl.text.trim().isEmpty ? '✨' : emojiCtrl.text.trim();
      final id = 'c_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999)}';
      state.addCategory(Category(id: id, name: name, emoji: emoji, type: type));
    }

    nameCtrl.dispose();
    emojiCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            actions: [
              ScaleTap(
                onTap: () => _addCategoryDialog(context, state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.add_rounded, color: scheme.primary),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _GlassCard(
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'กดค้างแล้วลากเพื่อจัดเรียงลำดับ (ReorderableListView)',
                            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ReorderableListView.builder(
                      itemCount: state.categories.length,
                      onReorder: state.reorderCategories,
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 0,
                          color: Colors.transparent,
                          child: ScaleTransition(
                            scale: animation.drive(Tween(begin: 1.0, end: 1.03)),
                            child: child,
                          ),
                        );
                      },
                      itemBuilder: (context, i) {
                        final c = state.categories[i];
                        final isIncome = c.type == TxType.income;
                        final color = isIncome ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

                        return Dismissible(
                          key: ValueKey(c.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(18)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete_rounded, color: Colors.white),
                          ),
                          confirmDismiss: (dir) async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                title: const Text('ลบหมวดหมู่นี้?'),
                                content: Text('${c.emoji} ${c.name}'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('ยกเลิก')),
                                  TextButton(onPressed: () => Navigator.pop(dialogCtx, true), child: const Text('ลบ', style: TextStyle(color: Color(0xFFDC2626)))),
                                ],
                              ),
                            );
                            return ok ?? false;
                          },
                          onDismissed: (dir) {
                            state.deleteCategory(c.id);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบหมวดหมู่แล้ว')));
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _GlassCard(
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: color.withOpacity(0.12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(c.emoji, style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 3),
                                        Text(
                                          isIncome ? 'ประเภท: รายรับ' : 'ประเภท: รายจ่าย',
                                          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.drag_handle_rounded, color: Theme.of(context).hintColor),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AppButton(
                    text: 'ไป Dashboard',
                    icon: Icons.dashboard_rounded,
                    onPressed: () => state.setTab(0),
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniType extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MiniType({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ScaleTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: active ? scheme.primary : scheme.primary.withOpacity(0.10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : scheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/* =========================
   Settings Tab
========================= */

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final isDark = state.themeMode == ThemeMode.dark;
        final scheme = Theme.of(context).colorScheme;

        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: ListView(
                children: [
                  _GlassCard(
                    child: Row(
                      children: [
                        Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: scheme.primary),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 2),
                              Text('สลับโหมดสว่าง/มืด ทั้งแอป', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        Switch(
                          value: isDark,
                          onChanged: (_) => state.toggleTheme(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ตัวช่วย', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          '• ปัดขวา = แก้ไข\n• ปัดซ้าย = ลบ\n• Search/Filter อยู่ที่ Dashboard',
                          style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          text: 'ดู Onboarding อีกครั้ง',
                          icon: Icons.slideshow_rounded,
                          color: scheme.secondary,
                          onPressed: () async {
                            await state.setOnboarded(false); // MyApp จะพากลับ Onboarding เอง
                          },
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          text: 'ล้าง Search/Filter',
                          icon: Icons.filter_alt_off_rounded,
                          color: scheme.primary,
                          onPressed: () {
                            state.clearSearchAndFilter();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ล้างแล้ว ✅')));
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('เกี่ยวกับแอป', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text(
                          'My Money Tracker (Prototype)\nBottom Nav: Dashboard / Add / Categories / Settings',
                          style: TextStyle(color: Theme.of(context).hintColor, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* =========================
   Helpers
========================= */

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class TxDismissibleTile extends StatefulWidget {
  final TxItem t;
  final Category cat;
  final AppState state;
  final Widget child;
  final Widget Function({
    required Color color,
    required IconData icon,
    required String label,
    required bool alignLeft,
  }) dismissBgBuilder;

  const TxDismissibleTile({
    super.key,
    required this.t,
    required this.cat,
    required this.state,
    required this.child,
    required this.dismissBgBuilder,
  });

  @override
  State<TxDismissibleTile> createState() => _TxDismissibleTileState();
}

class _TxDismissibleTileState extends State<TxDismissibleTile> {
  bool _opening = false;

  Future<void> _openEdit() async {
    if (_opening) return;
    _opening = true;

    await rootNavKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(existing: widget.t),
      ),
    );

    _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final cat = widget.cat;
    final state = widget.state;

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.horizontal,

      // ✅ ลด threshold ให้ปัดนิดเดียวก็เข้า confirmDismiss
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.08, // ขวา = แก้ไข
        DismissDirection.endToStart: 0.08, // ซ้าย = ลบ
      },

      background: widget.dismissBgBuilder(
        color: const Color(0xFF16A34A),
        icon: Icons.edit_rounded,
        label: 'แก้ไข',
        alignLeft: true,
      ),
      secondaryBackground: widget.dismissBgBuilder(
        color: const Color(0xFFDC2626),
        icon: Icons.delete_rounded,
        label: 'ลบ',
        alignLeft: false,
      ),

      confirmDismiss: (dir) async {
        // ขวา = แก้ไข (ไม่ dismiss)
        if (dir == DismissDirection.startToEnd) {
          await _openEdit();
          return false;
        }

        // ✅ ให้ชัดเจนว่าซ้ายเท่านั้นที่ลบ
        if (dir != DismissDirection.endToStart) return false;

        // ✅ ใช้ root context กันหลุด navigator เพราะมี nested navigators
        final dialogContext = rootNavKey.currentContext ?? context;

        final ok = await showDialog<bool>(
          context: dialogContext,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('ลบรายการนี้?'),
            content: Text('${cat.emoji} ${cat.name}  •  ฿${t.amount.toStringAsFixed(0)}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('ลบ', style: TextStyle(color: Color(0xFFDC2626))),
              ),
            ],
          ),
        );

        return ok ?? false;
      },

      onDismissed: (dir) {
        // ✅ ลบจริงเมื่อปัดซ้าย
        if (dir == DismissDirection.endToStart) {
          state.deleteTransaction(t.id);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบรายการแล้ว')),
          );
        }
      },

      child: widget.child,
    );
  }
}

