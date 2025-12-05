import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class PaymentWebSocketService {
  static final PaymentWebSocketService _instance = PaymentWebSocketService._internal();
  factory PaymentWebSocketService() => _instance;
  PaymentWebSocketService._internal();

  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  bool _isConnecting = false;
  String? _currentUrl;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  // Stream để lắng nghe messages
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  bool get isConnected => _channel != null && !_isDisposed;

  // Kết nối WebSocket - CHỈ CHO PHÉP 1 KẾT NỐI
  Future<void> connect(String url) async {
    if (_isDisposed) {
      return;
    }

    // Nếu đang kết nối hoặc đã kết nối rồi thì không làm gì
    if (_isConnecting || (isConnected && _currentUrl == url)) {
      return;
    }

    // Đóng kết nối cũ nếu có
    await _safeDisconnect();

    _isConnecting = true;
    _currentUrl = url;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _channel!.stream.listen(
            (message) {
          if (_isDisposed) {
            return;
          }
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;

            _controller.add(data);
          } catch (e) {
            print('❌ [WebSocketService-${hashCode}] Error parsing message: $e');
          }
        },
        onError: (error) {
          print('❌ [WebSocketService-${hashCode}] Stream error: $error');
          _handleDisconnection(url);
        },
        onDone: () {
          _handleDisconnection(url);
        },
        cancelOnError: true,
      );

      _isConnecting = false;

    } catch (e) {
      print('❌ [WebSocketService-${hashCode}] Failed to connect: $e');
      _handleDisconnection(url);
    }
  }

// ===== In _handleDisconnection() =====
  void _handleDisconnection(String url) {
    if (_isDisposed) {
      return;
    }

    _isConnecting = false;
    _channel = null;
    _scheduleReconnect(url);
  }

// ===== In _scheduleReconnect() =====
  void _scheduleReconnect(String url) {
    if (_isDisposed) {
      return;
    }

    // Hủy timer cũ nếu có
    _reconnectTimer?.cancel();

    // Schedule reconnect sau 3 giây
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_isDisposed && !isConnected && !_isConnecting) {
        connect(url);
      }
    });
  }

// ===== In _safeDisconnect() =====
  Future<void> _safeDisconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        print('⚠️ [WebSocketService-${hashCode}] Error disconnecting: $e');
      } finally {
        _channel = null;
        _currentUrl = null;
        _isConnecting = false;
      }
    }
  }

// ===== In sendMessage() =====
  void sendMessage(Map<String, dynamic> message) {
    if (!isConnected || _isDisposed) {
      return;
    }

    try {
      final jsonString = jsonEncode(message);

      _channel!.sink.add(jsonString);
    } catch (e) {
      print('❌ [WebSocketService-${hashCode}] Error sending message: $e');
    }
  }

// ===== In dispose() =====
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    try {
      _channel?.sink.close();
      _channel = null;
    } catch (e) {
      print('⚠️ [WebSocketService-${hashCode}] Error during disposal: $e');
    }

    try {
      if (!_controller.isClosed) {
        _controller.close();
      }
    } catch (e) {
      print('⚠️ [WebSocketService-${hashCode}] Error closing controller: $e');
    }

    _currentUrl = null;
    _isConnecting = false;
  }


  // Gửi thông tin booking sang FrontDesk
  void sendBookingToPayment({
    required int bookingId,
    required String customerName,
    required double amountBeforeDiscount,
    required double amountAfterDiscount,
    required double discountAmount,
    String? discountCode,
    List<Map<String, dynamic>>? serviceItems,
    String? wallet,
    required double fee
  }) {
    if (!isConnected || _isDisposed) {
      print('❌ WebSocket not connected, cannot send booking');
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
        'serviceItems': serviceItems,
        'timestamp': DateTime.now().toIso8601String(),
        'wallet': wallet,
        'fee': fee
      }
    };

    sendMessage(payload);
  }

  // Hủy thanh toán
  void cancelPayment({required int bookingId}) {
    if (!isConnected || _isDisposed) {
      return;
    }

    final payload = {
      'type': 'CANCEL_PAYMENT',
      'data': {
        'bookingId': bookingId,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    sendMessage(payload);
  }

  // Hoàn tất thanh toán
  void confirmPaymentCompleted({
    required int bookingId,
    required double totalPaid,
    required double tips,
    required int paymentMethod,
    double cashDiscount = 0.0,
  }) {
    if (!isConnected || _isDisposed) {
      return;
    }

    final payload = {
      'type': 'PAYMENT_COMPLETED',
      'data': {
        'bookingId': bookingId,
        'totalPaid': totalPaid,
        'tips': tips,
        'paymentMethod': paymentMethod,
        'cashDiscount': cashDiscount,
        'customerActuallyPaid': totalPaid - cashDiscount,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    sendMessage(payload);
  }

  // Reset service (dùng cho hot reload)
  void reset() {
    if (!_isDisposed) {
      dispose();
    }
    _isDisposed = false;
  }
}

