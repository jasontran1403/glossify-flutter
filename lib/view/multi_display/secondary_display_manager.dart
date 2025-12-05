import 'dart:async';
import 'package:flutter/services.dart';

class SecondaryDisplayService {
  static const _methodChannel = MethodChannel('com.hair_sallon/secondary_display');
  static const _eventChannel = EventChannel('com.hair_sallon/secondary_display_events');
  static const _secondaryModeChannel = MethodChannel('com.hair_sallon/secondary_mode');
  static const _secondaryDataChannel = MethodChannel('com.hair_sallon/secondary_data');

  static SecondaryDisplayService? _instance;
  static SecondaryDisplayService get instance {
    _instance ??= SecondaryDisplayService._();
    return _instance!;
  }

  SecondaryDisplayService._();

  StreamSubscription? _eventSubscription;
  final _dataStreamController = StreamController<Map<String, dynamic>>.broadcast();

  bool _isSecondaryMode = false;
  bool get isSecondaryMode => _isSecondaryMode;

  Stream<Map<String, dynamic>> get dataStream => _dataStreamController.stream;

  // Khởi tạo service
  Future<void> initialize() async {
    // Setup handler cho secondary mode channel
    _secondaryModeChannel.setMethodCallHandler((call) async {
      if (call.method == 'setSecondaryMode') {
        _isSecondaryMode = call.arguments as bool;
        print('🖥️ Secondary mode: $_isSecondaryMode');
      }
    });

    // Setup handler cho secondary data channel
    _secondaryDataChannel.setMethodCallHandler((call) async {
      if (call.method == 'updateData') {
        final data = Map<String, dynamic>.from(call.arguments as Map);
        _dataStreamController.add(data);
        print('📨 Received data on secondary display: ${data['type']}');
      }
    });

    // Listen to events
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
        print('📡 Event from native: $event');
      },
      onError: (error) {
        print('❌ Event channel error: $error');
      },
    );
  }

  // Kiểm tra có màn hình phụ không
  Future<bool> checkSecondaryDisplay() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('checkSecondaryDisplay');
      return result ?? false;
    } on PlatformException catch (e) {
      print("❌ Failed to check secondary display: ${e.message}");
      return false;
    }
  }

  // Hiển thị màn hình phụ
  Future<bool> showSecondaryDisplay() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('showSecondaryDisplay');
      print('✅ Secondary display shown: $result');
      return result ?? false;
    } on PlatformException catch (e) {
      print("❌ Failed to show secondary display: ${e.message}");
      return false;
    }
  }

  // Ẩn màn hình phụ
  Future<void> hideSecondaryDisplay() async {
    try {
      await _methodChannel.invokeMethod('hideSecondaryDisplay');
      print('✅ Secondary display hidden');
    } on PlatformException catch (e) {
      print("❌ Failed to hide secondary display: ${e.message}");
    }
  }

  // Gửi data tới màn hình phụ
  Future<void> sendToSecondaryDisplay(Map<String, dynamic> data) async {
    try {
      await _methodChannel.invokeMethod('sendToSecondaryDisplay', data);
      print('📤 Sent to secondary display: ${data['type']}');
    } on PlatformException catch (e) {
      print("❌ Failed to send to secondary display: ${e.message}");
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _dataStreamController.close();
  }
}