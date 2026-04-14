import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/view/bottombar_screen/bottomscreen_view_user.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hair_sallon/view/splash/app_splash_loader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:hair_sallon/utils/snowfall_widget.dart'; // ✅ SNOWFALL IMPORT
import 'package:timezone/data/latest.dart' as tz;

// 🔑 Global Navigator Key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Khai báo global plugin cho local notification
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

/// Khai báo AudioPlayer
final AudioPlayer _audioPlayer = AudioPlayer();

Future<void> showTopNotification(String title, String message) async {
  final overlayState = navigatorKey.currentState?.overlay;
  if (overlayState == null) {
    return;
  }

  showTopSnackBar(
    overlayState,
    Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95), // Glass effect background
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // App icon with border and glass effect
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7), // Glass effect
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  "assets/images/logo.png",
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with bold styling
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Message text
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    displayDuration: const Duration(seconds: 3),
  );
}

/// Xử lý background message
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  await Firebase.initializeApp();

  // Đăng ký background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Khởi tạo local notification plugin cho iOS
  const DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    requestCriticalPermission: false,
  );

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

// Khởi tạo settings cho cả iOS và Android
  const InitializationSettings initializationSettings = InitializationSettings(
    iOS: initializationSettingsIOS,
    android: initializationSettingsAndroid, // ← Thêm dòng này
  );

// Khởi tạo và cấu hình local notifications
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification clicked: ${response.payload}');
    },
  );

  // Khởi tạo và cấu hình local notifications
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification clicked: ${response.payload}');
    },
  );

  // Cấu hình system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.transparent,
    ),
  );

  tz.initializeTimeZones();
  runApp(const MyApp());
}

Future<String> getAttachmentFromAsset(String assetPath, String filename) async {
  try {
    final ByteData data = await rootBundle.load('assets$assetPath');
    final Uint8List bytes = data.buffer.asUint8List();

    final Directory directory = await getTemporaryDirectory();
    final String filePath = '${directory.path}/$filename';

    final File file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  } catch (e) {
    print('Error getting attachment from asset: $e');
    return '';
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? fcmToken;
  Widget? _home;

  // ✅ GLOBAL SNOWFALL CONTROL
  bool _showSnowfall = false;

  // ✅ Static instance for global access
  static _MyAppState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this; // ✅ Set singleton instance
    initFirebaseMessaging();
    _loadHome();
  }

  /// Phát âm thanh và hiển thị snackbar dựa trên nội dung thông báo
  Future<void> playNotificationSound(String? body) async {
    try {
      if (body == null) return;

      if (body.contains('You have a new appointment at')) {
        await _audioPlayer.play(AssetSource('audio/newbooking.mp3'));
      } else if (body.contains('The customer for the booking at')) {
        await _audioPlayer.play(AssetSource('audio/checkedin.mp3'));
      } else if (body.contains('There is a new bill from')) {
        await _audioPlayer.play(AssetSource('audio/newbill.mp3'));
      } else if (body.contains('There is a new bill from')) {
        await _audioPlayer.play(AssetSource('audio/newbill.mp3'));
      }

      // Hiển thị push notification dạng snackbar
      await showTopNotification("CP Nails & Spa", body);
    } catch (e) {
      print('Audio file not found: $e');
    }
  }

  // ✅ GLOBAL SNOWFALL TOGGLE - Call from anywhere
  static void toggleSnowfall() {
    _instance?._toggleSnowfallInternal();
  }

  void _toggleSnowfallInternal() {
    setState(() {
      _showSnowfall = !_showSnowfall;
    });
  }

  /// Khởi tạo Firebase Messaging
  Future<void> initFirebaseMessaging() async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy token hiện tại từ Firebase
    String? currentToken = await FirebaseMessaging.instance.getToken();

    if (currentToken != null) {
      print("FCM Token (init): $currentToken");
      await prefs.setString("fcmToken", currentToken);
    } else {
      print("Failed to get FCM Token");
    }

    // Lắng nghe khi token rotate
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      fcmToken = newToken;
      await prefs.setString("fcmToken", newToken);
    });

    // Foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      print("Notification clicked! Data: ${message.data}");
      if (notification != null) {
        await playNotificationSound(notification.body);
      }
    });

    // Notification clicked (foreground/background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification clicked! Data: ${message.data}");
    });

    // App launched from terminated state
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print("App opened from terminated state! Data: ${initialMessage.data}");
    }
  }

  Future<void> _loadHome() async {
    // ✅ Always load BottomNavBarView - no login required for browsing
    if (mounted) {
      setState(() {
        _home = const BottomNavBarView();
      });
    }
  }

  @override
  void dispose() {
    _instance = null; // ✅ Clear singleton
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return Stack(
          children: [
            // ✅ Original MediaQuery wrapper with app content
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.0),
              ),
              child: child!,
            ),

            // ❄️ GLOBAL SNOWFALL OVERLAY - Shows on ALL screens
            if (_showSnowfall)
              Positioned.fill(
                child: AdvancedSnowfallWidget(
                  numberOfSnowflakes: 30,
                  isEnabled: true,
                  // colorScheme already defaults to christmasCustom (your colors)
                ),
              ),
          ],
        );
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),

      // ⬇⬇⬇ SplashScreen cũ của bạn sẽ chạy ở đây
      home: const AppSplashLoader(),

      debugShowCheckedModeBanner: false,
    );
  }
}