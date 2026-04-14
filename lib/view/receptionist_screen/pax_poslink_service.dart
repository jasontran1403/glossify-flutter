import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// PAX POSLink Service - Pure Dart TCP Implementation with Full Debugging
class PaxPosLinkService {
  Socket? _socket;
  String? _deviceIp;
  int _port = 10009;
  bool _isConnected = false;

  Completer<Map<String, dynamic>>? _responseCompleter;

  // Control characters for PAX protocol
  static const int STX = 0x02;
  static const int ETX = 0x03;
  static const int FS = 0x1C;

  /// Initialize connection to PAX device
  Future<bool> initialize(String deviceIp, {int port = 10009}) async {
    _deviceIp = deviceIp;
    _port = port;

    print('\n╔════════════════════════════════════════╗');
    print('║   INITIALIZING PAX CONNECTION         ║');
    print('╚════════════════════════════════════════╝');
    print('Target IP: $_deviceIp');
    print('Target Port: $_port');

    try {
      print('\n🔌 Attempting to connect...');
      _socket = await Socket.connect(
        _deviceIp!,
        _port,
        timeout: const Duration(seconds: 5),
      );

      print('✅ Socket connection established!');
      print('   Local: ${_socket!.address.address}:${_socket!.port}');
      print('   Remote: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');

      // Listen for responses
      _socket!.listen(
        _handleResponse,
        onError: (error) {
          print('\n❌ Socket error: $error');
          _isConnected = false;
        },
        onDone: () {
          print('\n🔌 Socket closed by remote');
          _isConnected = false;
        },
      );

      _isConnected = true;
      print('✅ Successfully connected to PAX device\n');
      return true;
    } catch (e) {
      print('\n❌ CONNECTION FAILED');
      print('   Error: $e');
      print('   Type: ${e.runtimeType}');

      if (e is SocketException) {
        print('   OS Error: ${e.osError?.message}');
        print('   Error Code: ${e.osError?.errorCode}');
      }

      _isConnected = false;
      print('');
      return false;
    }
  }

  /// Process credit card sale
  Future<Map<String, dynamic>> processSale({
    required double amount,
    required String invoiceNumber,
    int timeout = 180,
  }) async {
    print('\n╔════════════════════════════════════════╗');
    print('║        PROCESSING PAYMENT              ║');
    print('╚════════════════════════════════════════╝');

    // Check connection
    if (!_isConnected || _socket == null) {
      print('❌ ERROR: Not connected to PAX device');
      return {
        'success': false,
        'error': 'Not connected to PAX device',
        'statusText': 'ERROR',
      };
    }

    print('✅ Connection status: CONNECTED');
    print('   Device IP: $_deviceIp');
    print('   Socket: ${_socket!.remoteAddress.address}:${_socket!.remotePort}');

    try {
      // Build message
      print('\n📝 Building payment request...');
      final message = _buildSaleRequest(amount, invoiceNumber);

      // Setup completer
      _responseCompleter = Completer<Map<String, dynamic>>();

      // Send message
      print('\n📤 Sending message to PAX...');
      _socket!.add(message);
      await _socket!.flush();
      print('✅ Message sent successfully');

      print('\n⏳ Waiting for response (timeout: ${timeout}s)...');
      print('   Time started: ${DateTime.now()}');

      // Wait for response
      final response = await _responseCompleter!.future.timeout(
        Duration(seconds: timeout),
        onTimeout: () {
          print('\n⏰ TIMEOUT after ${timeout}s');
          print('   No response received from PAX device');
          return {
            'success': false,
            'error': 'Payment timeout - no response from PAX device',
            'statusText': 'TIMEOUT',
          };
        },
      );

      print('\n═══════════════════════════════════════');
      print('📨 RESPONSE RECEIVED');
      print('═══════════════════════════════════════');
      print('Success: ${response['success']}');
      print('Status: ${response['statusText']}');
      if (response['error'] != null) {
        print('Error: ${response['error']}');
      }
      print('═══════════════════════════════════════\n');

      return response;
    } catch (e, stackTrace) {
      print('\n❌ EXCEPTION in processSale');
      print('   Error: $e');
      print('   Type: ${e.runtimeType}');
      print('   Stack trace:');
      print('   ${stackTrace.toString().split('\n').take(5).join('\n   ')}');

      return {
        'success': false,
        'error': 'Payment error: $e',
        'statusText': 'ERROR',
      };
    }
  }

  /// Build PAX POSLink SALE request message
  Uint8List _buildSaleRequest(double amount, String invoiceNumber) {
    print('\n┌────────────────────────────────────────┐');
    print('│  Building POSLink SALE Request         │');
    print('└────────────────────────────────────────┘');

    // Convert amount to cents
    final amountCents = (amount * 100).toInt().toString().padLeft(9, '0');
    print('Amount: \$$amount → $amountCents cents');
    print('Invoice: $invoiceNumber');

    // Build fields
    final fields = [
      'T00',           // 0: Command
      '1.28',          // 1: Version
      '1',             // 2: TenderType (1=Credit)
      '2',             // 3: TransType (2=SALE)
      amountCents,     // 4: Amount
      invoiceNumber,   // 5: Invoice Number
      invoiceNumber,   // 6: ECR Ref Number
      '',              // 7: CashBack
      '',              // 8: Trace Number
      '',              // 9: Auth Code
    ];

    print('\nMessage fields:');
    for (int i = 0; i < fields.length; i++) {
      print('  [$i] "${fields[i]}"');
    }

    // Join with FS
    final messageBody = fields.join(String.fromCharCode(FS));
    print('\nMessage body: $messageBody');
    print('Body length: ${messageBody.length} chars');

    // Build complete message
    final bodyBytes = utf8.encode(messageBody);
    final length = bodyBytes.length + 1; // +1 for ETX
    print('Total length: $length bytes (including ETX)');

    final buffer = BytesBuilder();

    // STX
    buffer.addByte(STX);

    // Length (4 digits)
    final lengthStr = length.toString().padLeft(4, '0');
    buffer.add(utf8.encode(lengthStr));

    // Body
    buffer.add(bodyBytes);

    // ETX
    buffer.addByte(ETX);

    // LRC (XOR of all bytes except STX and LRC itself)
    final messageWithoutLrc = buffer.toBytes();
    int lrc = 0;
    for (int i = 1; i < messageWithoutLrc.length; i++) {
      lrc ^= messageWithoutLrc[i];
    }
    buffer.addByte(lrc);

    final finalMessage = buffer.toBytes();

    print('\nComplete message:');
    print('  STX: 0x${STX.toRadixString(16).padLeft(2, '0')}');
    print('  Length: $lengthStr');
    print('  Body: $messageBody');
    print('  ETX: 0x${ETX.toRadixString(16).padLeft(2, '0')}');
    print('  LRC: 0x${lrc.toRadixString(16).padLeft(2, '0')}');
    print('\nHex dump (${finalMessage.length} bytes):');
    print('  ${_bytesToHex(finalMessage)}');

    return finalMessage;
  }

  /// Handle response from PAX device
  void _handleResponse(Uint8List data) {
    print('\n┌────────────────────────────────────────┐');
    print('│  Response Received from PAX            │');
    print('└────────────────────────────────────────┘');
    print('Time: ${DateTime.now()}');
    print('Size: ${data.length} bytes');
    print('Hex: ${_bytesToHex(data)}');

    try {
      final response = _parseResponse(data);

      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        print('✅ Completing response completer');
        _responseCompleter!.complete(response);
      } else {
        print('⚠️  Response completer already completed or null');
      }
    } catch (e, stackTrace) {
      print('❌ Error handling response: $e');
      print('Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');

      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.complete({
          'success': false,
          'error': 'Failed to parse response: $e',
          'statusText': 'ERROR',
        });
      }
    }
  }

  /// Parse PAX response message
  Map<String, dynamic> _parseResponse(Uint8List data) {
    print('\n┌────────────────────────────────────────┐');
    print('│  Parsing Response                      │');
    print('└────────────────────────────────────────┘');

    if (data.isEmpty) {
      print('❌ Empty response data');
      return {
        'success': false,
        'error': 'Empty response',
        'statusText': 'ERROR',
      };
    }

    if (data[0] != STX) {
      print('❌ Invalid response: Missing STX');
      print('   First byte: 0x${data[0].toRadixString(16)}');
      return {
        'success': false,
        'error': 'Invalid response format - missing STX',
        'statusText': 'ERROR',
      };
    }

    print('✅ STX found');

    try {
      if (data.length < 6) {
        print('❌ Response too short: ${data.length} bytes');
        return {
          'success': false,
          'error': 'Response too short (need at least 6 bytes)',
          'statusText': 'ERROR',
        };
      }

      // Extract length
      final lengthBytes = data.sublist(1, 5);
      final lengthStr = String.fromCharCodes(lengthBytes);
      final length = int.parse(lengthStr);
      print('Length field: "$lengthStr" = $length bytes');

      // Extract body
      final bodyStart = 5;
      final bodyEnd = bodyStart + length - 1; // -1 because length includes ETX

      print('Body range: [$bodyStart, $bodyEnd)');
      print('Data length: ${data.length}');

      if (bodyEnd > data.length) {
        print('❌ Invalid length: body end ($bodyEnd) > data length (${data.length})');
        return {
          'success': false,
          'error': 'Invalid message length',
          'statusText': 'ERROR',
        };
      }

      final bodyBytes = data.sublist(bodyStart, bodyEnd);
      final messageBody = utf8.decode(bodyBytes, allowMalformed: true);
      print('Message body: "$messageBody"');

      // Check ETX
      if (data.length > bodyEnd && data[bodyEnd] == ETX) {
        print('✅ ETX found at position $bodyEnd');
      } else {
        print('⚠️  ETX not found or at wrong position');
      }

      // Split fields
      final fields = messageBody.split(String.fromCharCode(FS));
      print('\nParsed ${fields.length} fields:');
      for (int i = 0; i < fields.length && i < 15; i++) {
        print('  [$i] "${fields[i]}"');
      }

      if (fields.isEmpty) {
        print('❌ No fields parsed');
        return {
          'success': false,
          'error': 'Empty response fields',
          'statusText': 'ERROR',
        };
      }

      // Parse status
      final status = fields.length > 0 ? fields[0] : '';
      print('\nStatus code: "$status"');

      // Check success
      final isSuccess = status == '000000' ||
          status == '00' ||
          status.isEmpty ||
          status == 'OK';

      print('Is success: $isSuccess');

      final result = {
        'success': isSuccess,
        'status': status,
        'statusText': isSuccess ? 'SUCCESS' : 'FAILED',
        'hostInformation': fields.length > 1 ? fields[1] : '',
        'cardType': fields.length > 2 ? fields[2] : '',
        'cardNumber': fields.length > 3 ? _maskCardNumber(fields[3]) : '',
        'cardHolder': fields.length > 4 ? fields[4] : '',
        'authCode': fields.length > 5 ? fields[5] : '',
        'amount': fields.length > 6 ? _parseAmount(fields[6]) : 0.0,
        'tip': fields.length > 7 ? _parseAmount(fields[7]) : 0.0,
        'transactionId': fields.length > 8 ? fields[8] : '',
        'timestamp': DateTime.now().toIso8601String(),
        'rawResponse': fields,
      };

      if (!isSuccess) {
        result['error'] = 'Transaction failed. Status: $status';
        print('Transaction failed with status: $status');
      }

      print('✅ Response parsed successfully');
      return result;

    } catch (e, stackTrace) {
      print('❌ Parse exception: $e');
      print('Stack: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      return {
        'success': false,
        'error': 'Parse error: $e',
        'statusText': 'ERROR',
      };
    }
  }

  String _maskCardNumber(String cardNumber) {
    if (cardNumber.isEmpty) return '';
    if (cardNumber.length <= 4) return cardNumber;
    return '****${cardNumber.substring(cardNumber.length - 4)}';
  }

  double _parseAmount(String amountStr) {
    try {
      final cents = int.parse(amountStr);
      return cents / 100.0;
    } catch (e) {
      return 0.0;
    }
  }

  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  bool get isConnected => _isConnected;
  String? get deviceIp => _deviceIp;

  void dispose() {
    print('\n🔌 Disposing PAX connection');
    _socket?.close();
    _socket = null;
    _isConnected = false;
  }
}