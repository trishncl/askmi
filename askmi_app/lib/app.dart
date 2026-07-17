import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

/// PHASE 0 checkpoint. If this screen shows up when you run the app, it
/// means Firebase.initializeApp() succeeded against your real project —
/// that's the whole definition of done for Phase 0.
///
/// PHASE 2 will replace `home:` below with AuthGate (features/auth/
/// auth_gate.dart) once login + role-based routing exist. Don't build that
/// yet — this file should stay exactly this simple until Phase 2 starts.
class AALomiApp extends StatelessWidget {
  const AALomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "AA's Lomi",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Phase 0 complete — Firebase connected.\nReady for Phase 1 (data layer).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
