import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Global WebSocket Service - Singleton Pattern
/// ⚠️ CHỈ KẾT NỐI 1 LẦN DUY NHẤT CHO TOÀN BỘ APP
class PaymentWebSocketService {
  static final PaymentWebSocketService _instance = PaymentWebSocketService._internal();
  factory PaymentWebSocketService() => _instance;
  PaymentWebSocketService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  // Track connection state
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _currentUrl;

  Stream<Map<String, dynamic>> get messages => _controller.stream;
  bool get isConnected => _isConnected;

  /// Connect to WebSocket server
  /// ⚠️ Chỉ connect nếu chưa có connection
  Future<void> connect(String url) async {
    // ✅ NẾU ĐÃ KẾT NỐI VỚI URL NÀY → KHÔNG LÀM GÌ CẢ
    if (_isConnected && _currentUrl == url) {
      print('✅ Already connected to $url');
      return;
    }

    // ✅ NẾU ĐANG CONNECTING → KHÔNG CONNECT LẠI
    if (_isConnecting) {
      print('⏳ Connection in progress, waiting...');
      // Đợi connection hiện tại hoàn thành
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // ✅ NẾU ĐÃ KẾT NỐI VỚI URL KHÁC → DISCONNECT RỒI CONNECT MỚI
    if (_isConnected && _currentUrl != url) {
      print('🔄 Switching connection from $_currentUrl to $url');
      await disconnect();
    }

    _isConnecting = true;

    try {
      print('🔌 Connecting to WebSocket: $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
            (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _controller.add(data);
            print('📨 Received: ${data['type']}');
          } catch (e) {
            print('❌ Error parsing message: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          _handleConnectionError(url);
        },
        onDone: () {
          print('❌ WebSocket connection closed');
          _handleConnectionError(url);
        },
      );

      _isConnected = true;
      _currentUrl = url;
      print('✅ WebSocket connected successfully');
    } catch (e) {
      print('❌ Failed to connect: $e');
      _handleConnectionError(url);
    } finally {
      _isConnecting = false;
    }
  }

  /// Handle connection errors and attempt reconnect
  void _handleConnectionError(String url) {
    _isConnected = false;
    _currentUrl = null;
    _isConnecting = false;

    // Auto-reconnect after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (!_isConnected) {
        print('🔄 Auto-reconnecting...');
        connect(url);
      }
    });
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    if (_channel != null) {
      print('🔌 Disconnecting WebSocket...');
      await _channel!.sink.close();
      _channel = null;
    }
    _isConnected = false;
    _currentUrl = null;
    _isConnecting = false;
  }

  /// Send booking to payment (Front Desk)
  void sendBookingToPayment({
    required int bookingId,
    required String customerName,
    required double amountBeforeDiscount,
    required double amountAfterDiscount,
    required double discountAmount,
    String? discountCode,
    List<String>? serviceNames,
  }) {
    if (!_isConnected) {
      print('⚠️ Cannot send: WebSocket not connected');
      return;
    }

    final payload = {
      'type': 'BOOKING_TO_PAYMENT',
      'data': {
        'bookingId': bookingId,
        'customerName': customerName,
        'amountBeforeDiscount': amountBeforeDiscount,
        'amountAfterDiscount': amountAfterDiscount,
        'discountAmount': discountAmount,
        'discountCode': discountCode,
        'serviceNames': serviceNames,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    _channel!.sink.add(jsonEncode(payload));
    print('📤 Sent BOOKING_TO_PAYMENT: #$bookingId');
  }

  /// Cancel payment
  void cancelPayment({required int bookingId}) {
    if (!_isConnected) {
      print('⚠️ Cannot cancel: WebSocket not connected');
      return;
    }

    final payload = {
      'type': 'CANCEL_PAYMENT',
      'data': {
        'bookingId': bookingId,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    _channel!.sink.add(jsonEncode(payload));
    print('🚫 Sent CANCEL_PAYMENT: #$bookingId');
  }

  /// Confirm payment completed (from Front Desk)
  void confirmPaymentCompleted({
    required int bookingId,
    required double totalPaid,
    required double tips,
    required int paymentMethod,
  }) {
    if (!_isConnected) {
      print('⚠️ Cannot confirm: WebSocket not connected');
      return;
    }

    final payload = {
      'type': 'PAYMENT_COMPLETED',
      'data': {
        'bookingId': bookingId,
        'totalPaid': totalPaid,
        'tips': tips,
        'paymentMethod': paymentMethod,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    _channel!.sink.add(jsonEncode(payload));
    print('✅ Sent PAYMENT_COMPLETED: #$bookingId');
  }

  /// Dispose - chỉ gọi khi app shutdown
  void dispose() {
    disconnect();
    _controller.close();
    print('🔌 WebSocket service disposed');
  }
}