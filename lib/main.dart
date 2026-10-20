import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/daily_database.dart';
import 'models.dart';
import 'services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppPalette.canvas,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final refreshSignal = AppRefreshSignal();
  runApp(DailyBootstrap(refreshSignal: refreshSignal));
}

class DailyBootstrap extends StatefulWidget {
  const DailyBootstrap({required this.refreshSignal, super.key});

  final AppRefreshSignal refreshSignal;

  @override
  State<DailyBootstrap> createState() => _DailyBootstrapState();
}

class _DailyBootstrapState extends State<DailyBootstrap> {
  late final Future<({SqliteDailyStore store, NotificationService scheduler})>
  _initialization = _initialize();

  Future<({SqliteDailyStore store, NotificationService scheduler})>
  _initialize() async {
    final store = SqliteDailyStore();
    final scheduler = NotificationService(
      store: store,
      refreshSignal: widget.refreshSignal,
    );
    await Future.wait<void>([
      store.initialize(),
      scheduler.initialize(),
      // Keeps the branded first frame visible long enough to read without
      // delaying database or notification initialization.
      Future<void>.delayed(const Duration(milliseconds: 850)),
    ]);
    return (store: store, scheduler: scheduler);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home:
          FutureBuilder<
            ({SqliteDailyStore store, NotificationService scheduler})
          >(
            future: _initialization,
            builder: (context, snapshot) {
              final initialized = snapshot.data;
              if (initialized == null) return const BrandedSplash();
              return DailyShell(
                store: initialized.store,
                scheduler: initialized.scheduler,
                refreshSignal: widget.refreshSignal,
              );
            },
          ),
    );
  }
}

class BrandedSplash extends StatelessWidget {
  const BrandedSplash({super.key});

  static const background = Color(0xFFF7F6F2);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Image.asset(
                'assets/branding/splash-lockup.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                gaplessPlayback: true,
                semanticLabel: 'Daily',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
