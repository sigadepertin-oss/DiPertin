import 'dart:async';
import 'dart:convert';

import 'package:depertin_cliente/screens/cliente/chat_suporte_screen.dart';
import 'package:depertin_cliente/screens/lojista/lojista_pedidos_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:depertin_cliente/screens/entregador/entregador_dashboard_screen.dart';
import 'firebase_options.dart';
import 'providers/cart_provider.dart';
import 'services/connectivity_service.dart';
import 'services/location_service.dart';
import 'screens/guards/app_guard.dart';
import 'screens/cliente/vitrine_screen.dart';
import 'screens/cliente/search_screen.dart';
import 'screens/comum/profile_screen.dart';

const Color diPertinRoxo = Color(0xFF6A1B9A);
const Color diPertinLaranja = Color(0xFFFF8F00);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// App Check antes de qualquer uso de Auth, Firestore, Storage, Functions, FCM, etc.
/// Debug: providers de debug (emulador/CI). Release: Play Integrity (Android) e
/// App Attest com fallback Device Check (iOS).
Future<void> _ativarFirebaseAppCheck() async {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _ativarFirebaseAppCheck();
}

/// Android: esconde a barra de navegação (voltar/home/recentes). O usuário pode
/// deslizar de baixo para cima para exibi-la por um instante.
Future<void> configurarBarraNavegacaoAndroidOculta() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configurarBarraNavegacaoAndroidOculta();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _ativarFirebaseAppCheck();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final p = response.payload;
      if (p == null || p.isEmpty) return;
      try {
        final map = jsonDecode(p) as Map<String, dynamic>;
        final tipo = map['tipoNotificacao']?.toString() ?? '';
        if (tipo == 'suporte_inicio' ||
            tipo == 'suporte_mensagem' ||
            tipo == 'suporte_encerrado' ||
            tipo == 'atendimento_iniciado') {
          navigatorKey.currentState?.pushNamed('/suporte');
        } else if (tipo == 'nova_entrega') {
          navigatorKey.currentState?.pushNamed('/entregador');
        }
      } catch (_) {}
    },
  );

  final androidNotifPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidNotifPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      'high_importance_channel',
      'Alertas DiPertin',
      description: 'Pedidos, entregas e central de ajuda',
      importance: Importance.high,
      playSound: true,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
      ],
      child: const DiPertinApp(),
    ),
  );
}

class DiPertinApp extends StatefulWidget {
  const DiPertinApp({super.key});

  @override
  State<DiPertinApp> createState() => _DiPertinAppState();
}

class _DiPertinAppState extends State<DiPertinApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      configurarBarraNavegacaoAndroidOculta();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DiPertin - O que você precisa, bem aqui!',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: diPertinRoxo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: diPertinRoxo,
          secondary: diPertinLaranja,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => AppGuard(child: child!),
      home: const SplashScreen(),
      routes: {
        '/pedidos': (context) => const LojistaPedidosScreen(),
        '/home': (context) => const MainNavigator(),
        '/entregador': (context) => const EntregadorDashboardScreen(),
        '/suporte': (context) => const ChatSuporteScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _erroCidadeNaoIdentificada = false;

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  Future<void> _aguardarCondicao(bool Function() condicao) async {
    while (!condicao()) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
    }
  }

  /// Abre a vitrine só com cidade+UF já resolvidos pelo GPS nesta sessão.
  Future<bool> _resolverCidadeParaVitrine() async {
    const maxTentativas = 5;
    for (var t = 0; t < maxTentativas; t++) {
      if (!mounted) return false;
      await context.read<LocationService>().detectarCidade();
      if (!mounted) return false;
      if (context.read<LocationService>().cidadePronta) return true;
      await Future.delayed(Duration(milliseconds: 500 + t * 350));
    }
    return false;
  }

  Future<void> _aplicarDelayMinimoSplash(DateTime splashInicio) async {
    final decorrido =
        DateTime.now().difference(splashInicio).inMilliseconds;
    if (decorrido < 1500) {
      await Future.delayed(Duration(milliseconds: 1500 - decorrido));
    }
  }

  Future<void> _inicializarApp() async {
    setState(() => _erroCidadeNaoIdentificada = false);

    final splashInicio = DateTime.now();
    final connectivity = context.read<ConnectivityService>();
    final location = context.read<LocationService>();

    await _aguardarCondicao(() => connectivity.initialized);
    if (!mounted) return;
    await _aguardarCondicao(() => connectivity.isOnline);
    if (!mounted) return;

    await _aguardarCondicao(() => location.initialized);
    if (!mounted) return;

    if (location.status == LocationStatus.permissaoNegada) {
      await location.solicitarPermissao();
    }

    await _aguardarCondicao(() => location.status == LocationStatus.pronto);
    if (!mounted) return;

    await _configurarFCM()
        .timeout(const Duration(seconds: 8))
        .catchError((_) {});

    if (!mounted) return;

    RemoteMessage? initialMessage;
    try {
      initialMessage = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('getInitialMessage falhou: $e');
    }

    if (initialMessage != null) {
      unawaited(_resolverCidadeParaVitrine());
      await _aplicarDelayMinimoSplash(splashInicio);
      if (!mounted) return;

      final tipoDaNotificacao = initialMessage.data['tipoNotificacao'] ??
          initialMessage.data['tipo'];

      if (tipoDaNotificacao == 'nova_entrega') {
        Navigator.pushReplacementNamed(context, '/entregador');
      } else if (tipoDaNotificacao == 'suporte_inicio' ||
          tipoDaNotificacao == 'suporte_mensagem' ||
          tipoDaNotificacao == 'suporte_encerrado' ||
          tipoDaNotificacao == 'atendimento_iniciado') {
        Navigator.pushReplacementNamed(context, '/suporte');
      } else {
        Navigator.pushReplacementNamed(context, '/pedidos');
      }
      return;
    }

    final ok = await _resolverCidadeParaVitrine();
    if (!mounted) return;

    if (!ok) {
      setState(() => _erroCidadeNaoIdentificada = true);
      return;
    }

    await _aplicarDelayMinimoSplash(splashInicio);
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _tentarNovamenteIdentificarCidade() async {
    setState(() => _erroCidadeNaoIdentificada = false);
    final splashInicio = DateTime.now();
    final ok = await _resolverCidadeParaVitrine();
    if (!mounted) return;
    if (!ok) {
      setState(() => _erroCidadeNaoIdentificada = true);
      return;
    }
    await _aplicarDelayMinimoSplash(splashInicio);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _configurarFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    String? token = await messaging.getToken();
    User? user = FirebaseAuth.instance.currentUser;

    Future<void> persistirTokenFirestore(String? novoToken) async {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null || novoToken == null) return;
      final prefs = await SharedPreferences.getInstance();
      final tokenSalvo = prefs.getString('fcm_token');
      final usuarioSalvo = prefs.getString('fcm_uid');
      if (tokenSalvo == novoToken && usuarioSalvo == u.uid) return;
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'fcm_token': novoToken,
        'ultimo_acesso': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await prefs.setString('fcm_token', novoToken);
      await prefs.setString('fcm_uid', u.uid);
    }

    if (user != null && token != null) {
      await persistirTokenFirestore(token);
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(persistirTokenFirestore);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'Alertas DiPertin',
              channelDescription: 'Pedidos, entregas e central de ajuda',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      String? tipoDaNotificacao =
          message.data['tipoNotificacao'] ?? message.data['tipo'];

      if (tipoDaNotificacao == 'nova_entrega') {
        navigatorKey.currentState?.pushNamed('/entregador');
      } else if (tipoDaNotificacao == 'suporte_inicio' ||
          tipoDaNotificacao == 'suporte_mensagem' ||
          tipoDaNotificacao == 'suporte_encerrado' ||
          tipoDaNotificacao == 'atendimento_iniciado') {
        navigatorKey.currentState?.pushNamed('/suporte');
      } else {
        navigatorKey.currentState?.pushNamed('/pedidos');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: child,
                    ),
                  );
                },
                child: Image.asset(
                  'assets/logo.png',
                  height: 180,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.storefront,
                    size: 100,
                    color: diPertinLaranja,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (_erroCidadeNaoIdentificada) ...[
                const Text(
                  'Não foi possível identificar sua cidade',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ative o GPS, conceda permissão de localização e '
                  'certifique-se de ter sinal. Depois tente novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _tentarNovamenteIdentificarCidade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: diPertinLaranja,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Tentar novamente',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else
                const CircularProgressIndicator(color: diPertinLaranja),
            ],
          ),
        ),
      ),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});
  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 1;
  final List<Widget> _telas = [
    const SearchScreen(),
    const VitrineScreen(),
    const ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _telas[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        selectedItemColor: diPertinLaranja,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: "Buscar/Serviços",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront),
            label: "Vitrine",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Perfil"),
        ],
      ),
    );
  }
}
