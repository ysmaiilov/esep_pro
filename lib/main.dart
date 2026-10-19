import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login.dart';
import 'screens.dart';
import 'sheets.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const EsepApp());
}

class EsepApp extends StatelessWidget {
  const EsepApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ЭСЕП',
          scaffoldMessengerKey: messengerKey,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          home: const Boot(),
        ),
      );
}

class Boot extends StatefulWidget {
  const Boot({super.key});
  @override
  State<Boot> createState() => _BootState();
}

class _BootState extends State<Boot> {
  bool ready = false;
  @override
  void initState() {
    super.initState();
    Future.wait([
      store.load().catchError((Object e) {
        debugPrint('store.load failed: $e');
        store.loaded = true;
      }),
      Future.delayed(const Duration(milliseconds: 2300)),
    ]).whenComplete(() {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOut,
        child: ready ? const AuthGate(key: ValueKey('shell'), child: Shell()) : const Splash(key: ValueKey('splash')),
      );
}

// =====================================================================
//  SPLASH — "ой, сонун болуптур" moment
// =====================================================================
class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..forward();
  @override
  void dispose() {
    ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF062314), Color(0xFF14532D), Color(0xFF1F7A45)]),
        ),
        child: AnimatedBuilder(
          animation: ac,
          builder: (context, _) {
            final logo = const Interval(0, .55, curve: Curves.elasticOut).transform(ac.value);
            final text = const Interval(.4, .8, curve: Curves.easeOut).transform(ac.value);
            final tag = const Interval(.6, 1, curve: Curves.easeOut).transform(ac.value);
            return Stack(children: [
              // soft decorative circles
              Positioned(top: -80, right: -60, child: _circle(240, .06 * text)),
              Positioned(bottom: -100, left: -70, child: _circle(300, .05 * text)),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Transform.scale(
                    scale: .3 + .7 * logo,
                    child: Opacity(
                      opacity: logo.clamp(0.0, 1.0),
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(34),
                          boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 40, offset: Offset(0, 16))],
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, size: 56, color: Color(0xFF14532D)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - text)),
                      child: const Text('ЭСЕП', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: 8)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: tag,
                    child: Text(s_(store.settings['shopSubtitle']), style: const TextStyle(color: Color(0xFFCFE0D2), fontSize: 15, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 44),
                  Opacity(
                    opacity: tag,
                    child: const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white54)),
                  ),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _circle(double size, double opacity) => Container(
      width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))));
}

// =====================================================================
//  SHELL
// =====================================================================
class Shell extends StatelessWidget {
  const Shell({super.key});

  // NOT const on purpose: new instances force a rebuild when the store changes
  static Widget _screen(int i) {
    switch (i) {
      case 1:
        return InventoryScreen();
      case 2:
        return SalesScreen();
      case 3:
        return ClientsScreen();
      case 4:
        return KassaScreen();
      default:
        return DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final dark = context.isDark;
          final headBg = dark ? context.cs.surface : const Color(0xFF14532D);
          final months = tr('months').split(',');
          final days = tr('weekdays').split(',');
          final now = DateTime.now();
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 68,
              backgroundColor: headBg,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              titleSpacing: 16,
              title: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF14532D), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(s_(store.settings['shopName']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(s_(store.settings['shopSubtitle']), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFFCFE0D2))),
                ])),
              ]),
              actions: [
                Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Center(
                        child: Text('${now.day} ${months[now.month - 1]}, ${days[now.weekday % 7]}', style: const TextStyle(fontSize: 11.5, color: Color(0xFFCFE0D2))))),
                IconButton(
                    style: IconButton.styleFrom(backgroundColor: const Color.fromRGBO(255, 255, 255, .14)),
                    onPressed: () => openMenuSheet(context),
                    icon: const Icon(Icons.menu_rounded)),
                const SizedBox(width: 10),
              ],
            ),
            body: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOut,
              child: KeyedSubtree(key: ValueKey(store.tab), child: _screen(store.tab)),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: store.tab,
              onDestinationSelected: (i) {
                store.tab = i;
                store.notify();
              },
              destinations: [
                NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: tr('nav_home')),
                NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: tr('nav_inventory')),
                NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long_rounded), label: tr('nav_sales')),
                NavigationDestination(icon: const Icon(Icons.people_alt_outlined), selectedIcon: const Icon(Icons.people_alt_rounded), label: tr('nav_clients')),
                NavigationDestination(icon: const Icon(Icons.point_of_sale_outlined), selectedIcon: const Icon(Icons.point_of_sale_rounded), label: tr('nav_kassa')),
              ],
            ),
          );
        },
      );
}
