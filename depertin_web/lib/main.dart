import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'navigation/painel_routes.dart';
import 'theme/painel_admin_theme.dart';
import 'screens/login_admin_screen.dart';
import 'widgets/painel_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DiPertinAdminApp());
}

/// Rota sem animação (troca instantânea) — usada ao abrir URLs diretas do painel no web.
Route<void> _rotaPainelInstantanea(RouteSettings settings, Widget child) {
  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

class DiPertinAdminApp extends StatelessWidget {
  const DiPertinAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DiPertin',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      theme: PainelAdminTheme.theme(),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginAdminScreen(),
        '/painel': (context) => const PainelShellScreen(),
      },
      onGenerateRoute: (RouteSettings settings) {
        final name = settings.name;
        if (name != null && PainelRoutes.isShellRoute(name)) {
          return _rotaPainelInstantanea(
            settings,
            PainelShellScreen(initialRoute: name),
          );
        }
        return null;
      },
    );
  }
}
