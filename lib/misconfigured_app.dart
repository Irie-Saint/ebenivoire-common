import 'package:flutter/material.dart';

/// Shown when the app was built without its environment file
/// (`--dart-define-from-file=.env.production`), i.e. API_BASE_URL / API_KEY are
/// empty. Without this the app would look "broken" with silent request
/// failures; here we tell the builder exactly what went wrong.
class MisconfiguredApp extends StatelessWidget {
  const MisconfiguredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF3E5A99),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.error_outline, color: Colors.white, size: 56),
                  SizedBox(height: 16),
                  Text(
                    'Configuration manquante',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    "Cette application a ete compilee sans son fichier "
                    "d'environnement.\n\nReconstruisez avec :\n"
                    "flutter build apk --release "
                    "--dart-define-from-file=.env.production\n\n"
                    "(ou lancez build_release.bat)",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
