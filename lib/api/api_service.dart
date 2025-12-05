import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hair_sallon/api/booking_model.dart';
import 'package:hair_sallon/api/giftcard_transaction_history.dart';
import 'package:hair_sallon/api/payment_model.dart';
import 'package:hair_sallon/api/promotion_request_models.dart';
import 'package:hair_sallon/api/sales_data_models.dart';
import 'package:hair_sallon/api/staff_schedule_model.dart';
import 'package:hair_sallon/api/staff_service_models.dart';
import 'package:hair_sallon/api/store_info_detail_dto.dart';
import 'package:hair_sallon/api/store_info_model.dart';
import 'package:hair_sallon/api/user_list_dto.dart';
import 'package:hair_sallon/utils/constant/booking.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; // ✅ Import MediaType

import '../utils/constant/booking_model.dart';
import '../utils/constant/nail_store_model.dart';
import '../utils/constant/nail_store_simple.dart';
import '../utils/constant/quick_booking_model.dart';
import '../utils/constant/service.dart';
import '../utils/constant/staff_detail.dart';
import '../utils/constant/staff_simple.dart';
import '../utils/constant/staff_slot.dart';
import '../view/bokking_screen/booking_schedule_screen.dart';
import '../view/bokking_screen/user_booking_models.dart';
import '../view/profile_screen/profile_view.dart';
import 'api_response_model.dart';
import 'available_service.dart';
import 'checkin_booking_model.dart';
import 'gift_card_model.dart';
import 'giftcard_model.dart';
import 'heatmap_api_response.dart';
import 'management_category_model.dart';
import 'management_service_model.dart';
import 'management_staff_model.dart';
import 'management_store_model.dart';

enum BookingStatus {
  BOOKED,
  CHECKED_IN,
  IN_PROGRESS,
  WAITING_PAYMENT,
  PAID,
  CANCELED,
}

class ApiService {
  static const String baseUrl =
      "https://api.glossify.salon/api/v1"; // đổi IP/server của bạn

  static Future<ApiResponse<AvailableServicesDTO>> getAvailableServiceListForStaff(int staffId) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/$staffId/available-services';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final availableServices = AvailableServicesDTO.fromJson(data['data']);
          return ApiResponse.success('Available services retrieved successfully',
              data: availableServices);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to get available services');
      }
      return ApiResponse.error('Failed to get available services');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Add multiple services to staff
  static Future<ApiResponse<StaffServiceOperationResult>> addServicesToStaff({required int staffId, required List<int> serviceIds,}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/$staffId/services';

      final body = AddServicesToStaffRequest(serviceIds: serviceIds).toJson();

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final result = StaffServiceOperationResult.fromJson(data['data']);
          return ApiResponse.success(data['message'] ?? 'Services added successfully',
              data: result);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to add services');
      }
      return ApiResponse.error('Failed to add services');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Remove a service from staff
  static Future<ApiResponse<StaffServiceOperationResult>> removeServiceFromStaff({required int staffId, required int serviceId,}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/$staffId/services/$serviceId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final result = StaffServiceOperationResult.fromJson(data['data']);
          return ApiResponse.success(data['message'] ?? 'Service removed successfully',
              data: result);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to remove service');
      }
      return ApiResponse.error('Failed to remove service');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  // api_service.dart
  static Future<ApiResponse<PromotionRequestResponse>> createPromotionRequest({String? notes,}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/user/promotion-requests';

      final body = CreatePromotionRequest(notes: notes).toJson();

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final request = PromotionRequestResponse.fromJson(data['data']);
          return ApiResponse.success('Promotion request created successfully', data: request);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to create request');
      }
      return ApiResponse.error('Failed to create promotion request');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Get my promotion requests
  static Future<ApiResponse<List<PromotionRequestResponse>>> getMyPromotionRequests() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/user/promotion-requests/my';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final List<dynamic> requestsJson = data['data'] ?? [];
          final requests = requestsJson
              .map((json) => PromotionRequestResponse.fromJson(json))
              .toList();
          return ApiResponse.success('Promotion requests retrieved successfully', data: requests);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to get requests');
      }
      return ApiResponse.error('Failed to get promotion requests');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Check if user has pending request
  static Future<ApiResponse<bool>> hasPendingPromotionRequest() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/user/promotion-requests/my/status';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final hasPending = data['data'] ?? false;
          return ApiResponse.success(
            hasPending ? 'You have a pending request' : 'No pending request',
            data: hasPending,
          );
        }
        return ApiResponse.error(data['message'] ?? 'Failed to check status');
      }
      return ApiResponse.error('Failed to check request status');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Cancel promotion request
  static Future<ApiResponse<PromotionRequestSummary>> cancelPromotionRequest(int requestId) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/user/promotion-requests/$requestId';

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final summary = PromotionRequestSummary.fromJson(data['data']);
          return ApiResponse.success('Promotion request cancelled successfully', data: summary);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to cancel request');
      }
      return ApiResponse.error('Failed to cancel promotion request');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

// ============================================================================
// ADMIN METHODS
// ============================================================================

  /// Get all promotion requests (admin)
  static Future<ApiResponse<List<PromotionRequestResponse>>> getAllPromotionRequests() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/promotion-requests';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final List<dynamic> requestsJson = data['data'] ?? [];
          final requests = requestsJson
              .map((json) => PromotionRequestResponse.fromJson(json))
              .toList();
          return ApiResponse.success('Promotion requests retrieved successfully', data: requests);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to get requests');
      }
      return ApiResponse.error('Failed to get promotion requests');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Get pending promotion requests (admin)
  static Future<ApiResponse<List<PromotionRequestResponse>>> getPendingPromotionRequests() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/promotion-requests/pending';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final List<dynamic> requestsJson = data['data'] ?? [];
          final requests = requestsJson
              .map((json) => PromotionRequestResponse.fromJson(json))
              .toList();
          return ApiResponse.success('Pending requests retrieved successfully', data: requests);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to get requests');
      }
      return ApiResponse.error('Failed to get pending requests');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Approve promotion request (admin)
  static Future<ApiResponse<PromotionRequestSummary>> approvePromotionRequest({required int requestId, String? adminNotes,}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/promotion-requests/$requestId/approve';

      final body = ApprovePromotionRequest(adminNotes: adminNotes).toJson();

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final summary = PromotionRequestSummary.fromJson(data['data']);
          return ApiResponse.success('User promoted to STAFF successfully', data: summary);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to approve request');
      }
      return ApiResponse.error('Failed to approve promotion request');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Reject promotion request (admin)
  static Future<ApiResponse<PromotionRequestSummary>> rejectPromotionRequest({required int requestId, String? adminNotes,}) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/promotion-requests/$requestId/reject';

      final body = RejectPromotionRequest(adminNotes: adminNotes).toJson();

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final summary = PromotionRequestSummary.fromJson(data['data']);
          return ApiResponse.success('Promotion request rejected', data: summary);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to reject request');
      }
      return ApiResponse.error('Failed to reject promotion request');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  /// Count pending requests (admin)
  static Future<ApiResponse<int>> countPendingPromotionRequests() async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      final url = '$baseUrl/admin/promotion-requests/count/pending';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['status'] == 'success') {
          final count = data['data'] ?? 0;
          return ApiResponse.success('Pending requests count retrieved', data: count);
        }
        return ApiResponse.error(data['message'] ?? 'Failed to count requests');
      }
      return ApiResponse.error('Failed to count pending requests');
    } catch (e) {
      print('❌ Error: $e');
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }

  static Future<ApiResponse<bool>> forgotPassword(String phoneNumber) async {
    try {
      // Clean phone number - remove any non-digit characters
      final cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

      // If cleaned phone number is empty, return error
      if (cleanPhoneNumber.isEmpty) {
        return ApiResponse<bool>.error(
          'Invalid phone number format',
          code: 400,
        );
      }

      // Format URL with query parameter
      final url = Uri.parse('$baseUrl/auth/forgot-password/$cleanPhoneNumber');


      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(utf8.decode(response.bodyBytes));

        // Parse API response
        final apiResponse = ApiResponse<bool>.fromJson(responseBody);

        return apiResponse;

      } else {
        return ApiResponse<bool>.error(
          'Server error: ${response.statusCode}',
          code: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse<bool>.error(
        'Network error: ${e.toString()}',
        code: 500,
      );
    }
  }

  static Future<int?> getWorkingStoreId() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/receptionist/working-store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check API response structure
        if (data['status'] == 'success' && data['data'] != null) {
          final storeId = data['data'] as int;
          return storeId;
        } else {
          return null;
        }
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getClientsStatistics({
    required DateTime startDate,
    required DateTime endDate,
    required String role,
  }) async {
    try {
      // Get token
      final token = await getAccessToken();
      if (token == null) {
        return ApiResponse.error('Access token is null');
      }

      // Format dates as ISO 8601 (yyyy-MM-ddTHH:mm:ss)
      final startDateStr = startDate.toUtc().toIso8601String();
      final endDateStr = endDate.toUtc().toIso8601String();

      final url = '$baseUrl/admin/statistics?startDate=$startDateStr&endDate=$endDateStr';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(utf8.decode(response.bodyBytes));

        // Check if response follows ApiResponse structure
        if (responseBody.containsKey('code') &&
            responseBody.containsKey('status') &&
            responseBody.containsKey('data')) {

          final apiResponse = ApiResponse<Map<String, dynamic>>.fromJson(responseBody);

          if (apiResponse.isSuccess && apiResponse.data != null) {
            return apiResponse;
          } else {
            return ApiResponse.error(apiResponse.message, code: apiResponse.code);
          }
        } else {
          // If response doesn't follow ApiResponse structure
          return ApiResponse.error('Unexpected response format from server');
        }
      } else if (response.statusCode == 401) {
        return ApiResponse.error('Session expired. Please login again.', code: 401);
      } else if (response.statusCode == 403) {
        return ApiResponse.error('You do not have permission to view this data.', code: 403);
      } else if (response.statusCode == 400) {
        return ApiResponse.error('Invalid request parameters', code: 400);
      } else {
        return ApiResponse.error('Failed to load clients statistics', code: response.statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Network error: ${e.toString()}');
    }
  }


  static Future<SalesDataResponse?> getSalesData({
    required DateTime startDate,
    required DateTime endDate,
    required String role,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);

      final response = await http.get(
        Uri.parse('$baseUrl/admin/sales-data?startDate=$startDateStr&endDate=$endDateStr&role=$role'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check API response structure
        if (data['status'] == 'success' && data['data'] != null) {
          return SalesDataResponse.fromJson(data['data']);
        } else {
          print('⚠️ ${data['message']}');
          return null;
        }
      } else {
        print('❌ Failed to get sales data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching sales data: $e');
      return null;
    }
  }

  static Future<ApiResponse<ManagementStaffDTO>> updateStaffInfo({
    required int staffId,
    required String fullName,
    String? description,
    required List<int> serviceIds,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/staff/$staffId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'fullName': fullName,
          'description': description,
          'serviceIds': serviceIds,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc
        ManagementStaffDTO? staff;
        if (jsonResponse['data'] != null) {
          staff = ManagementStaffDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<ManagementStaffDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: staff,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to update staff info');
      }
    } catch (e) {
      throw Exception('Update staff info error: $e');
    }
  }

  /// Remove staff (convert to USER)
  static Future<ApiResponse<void>> removeStaff(int staffId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.delete(
        Uri.parse('$baseUrl/admin/staff/$staffId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<void>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to remove staff');
      }
    } catch (e) {
      throw Exception('Remove staff error: $e');
    }
  }

  /// Get promotable users (non-staff)
  static Future<ApiResponse<List<UserListDTO>>> getPromotableUsers({
    int page = 0,
    int size = 12,
    String searchQuery = '',
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/users/promotable?page=$page&size=$size&search=${Uri.encodeQueryComponent(searchQuery)}',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        final userList = PageResponseParser.parsePageContent(
          jsonResponse,
              (item) => UserListDTO.fromJson(item),
        );

        return ApiResponse<List<UserListDTO>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: userList,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get promotable users: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get promotable users error: $e');
    }
  }

  /// Promote user to staff
  static Future<ApiResponse<ManagementStaffDTO>> promoteUserToStaff({
    required int userId,
    required int storeId,
    required List<int> serviceIds,
    required double shareRate,
    required double tipShareRate,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/admin/staff/promote'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'userId': userId,
          'storeId': storeId,
          'serviceIds': serviceIds,
          'shareRate': shareRate,
          'tipShareRate': tipShareRate,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementStaffDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to promote user');
      }
    } catch (e) {
      throw Exception('Promote user error: $e');
    }
  }

  /// Upload staff avatar
  static Future<ApiResponse<String>> uploadStaffAvatar({
    required int staffId,
    required String imagePath,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/admin/staff/$staffId/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      // Detect MIME type
      String? mimeType = lookupMimeType(imagePath);
      if (mimeType == null) {
        String extension = imagePath.split('.').last.toLowerCase();
        if (['jpg', 'jpeg'].contains(extension)) {
          mimeType = 'image/jpeg';
        } else if (extension == 'png') {
          mimeType = 'image/png';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final jsonResponse = json.decode(respStr);

      return ApiResponse<String>.fromJson(jsonResponse);
    } catch (e) {
      throw Exception('Upload staff avatar error: $e');
    }
  }

// ========== CATEGORY MANAGEMENT ==========

  /// Update category information
  static Future<ApiResponse<ManagementCategoryDTO>> updateCategoryInfo({
    required int categoryId,
    required String name,
    String? description,
    required List<int> serviceIds,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/categories/$categoryId/info'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'name': name,
          'description': description,
          'serviceIds': serviceIds,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc ApiResponse
        ManagementCategoryDTO? category;
        if (jsonResponse['data'] != null) {
          category = ManagementCategoryDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<ManagementCategoryDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: category,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to update category');
      }
    } catch (e) {
      throw Exception('Update category error: $e');
    }
  }


  /// Upload category avatar
  static Future<ApiResponse<String>> uploadCategoryAvatar({
    required int categoryId,
    required String imagePath,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/admin/categories/$categoryId/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      String? mimeType = lookupMimeType(imagePath);
      if (mimeType == null) {
        String extension = imagePath.split('.').last.toLowerCase();
        if (['jpg', 'jpeg'].contains(extension)) {
          mimeType = 'image/jpeg';
        } else if (extension == 'png') {
          mimeType = 'image/png';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final jsonResponse = json.decode(respStr);

      return ApiResponse<String>.fromJson(jsonResponse);
    } catch (e) {
      throw Exception('Upload category avatar error: $e');
    }
  }

// ========== SERVICE MANAGEMENT ==========

  /// Create new service
  static Future<ApiResponse<ManagementServiceDTO>> createService({
    required String name,
    required double price,
    String? description,
    double? cashPrice,
    required bool plus,
    required int categoryId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/admin/services'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'name': name,
          'price': price,
          'description': description,
          'cashPrice': cashPrice,
          'plus': plus,
          'categoryId': categoryId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc
        ManagementServiceDTO? service;
        if (jsonResponse['data'] != null) {
          service = ManagementServiceDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<ManagementServiceDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: service,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to create service');
      }
    } catch (e) {
      throw Exception('Create service error: $e');
    }
  }


  /// Update service information
  static Future<ApiResponse<ManagementServiceDTO>> updateServiceInfo({
    required int serviceId,
    required String name,
    required double price,
    String? description,
    double? cashPrice,
    required bool plus,
    required int categoryId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/services/$serviceId/info'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'name': name,
          'price': price,
          'description': description,
          'cashPrice': cashPrice,
          'plus': plus,
          'categoryId': categoryId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc
        ManagementServiceDTO? service;
        if (jsonResponse['data'] != null) {
          service = ManagementServiceDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<ManagementServiceDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: service,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to update service');
      }
    } catch (e) {
      throw Exception('Update service error: $e');
    }
  }


  /// Upload service avatar
  static Future<ApiResponse<String>> uploadServiceAvatar({
    required int serviceId,
    required String imagePath,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/admin/services/$serviceId/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      String? mimeType = lookupMimeType(imagePath);
      if (mimeType == null) {
        String extension = imagePath.split('.').last.toLowerCase();
        if (['jpg', 'jpeg'].contains(extension)) {
          mimeType = 'image/jpeg';
        } else if (extension == 'png') {
          mimeType = 'image/png';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final jsonResponse = json.decode(respStr);

      return ApiResponse<String>.fromJson(jsonResponse);
    } catch (e) {
      throw Exception('Upload service avatar error: $e');
    }
  }

// ========== STORE INFO MANAGEMENT ==========

  /// Get current store information
  static Future<ApiResponse<StoreInfoDetailDTO>> getMyStoreInfo() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/store/info'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc
        StoreInfoDetailDTO? storeInfo;
        if (jsonResponse['data'] != null) {
          storeInfo = StoreInfoDetailDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<StoreInfoDetailDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: storeInfo,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get store info');
      }
    } catch (e) {
      throw Exception('Get store info error: $e');
    }
  }

  /// Update store information
  static Future<ApiResponse<StoreInfoDetailDTO>> updateStoreInfo({
    required String name,
    required String location,
    required double fee,
    required double ownerRate,
    double? lon,
    double? lat,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/store/info'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'name': name,
          'location': location,
          'fee': fee,
          'ownerRate': ownerRate,
          'lon': lon,
          'lat': lat,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // ✅ SỬA: Parse đúng cấu trúc
        StoreInfoDetailDTO? storeInfo;
        if (jsonResponse['data'] != null) {
          storeInfo = StoreInfoDetailDTO.fromJson(
              jsonResponse['data'] as Map<String, dynamic>
          );
        }

        return ApiResponse<StoreInfoDetailDTO>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: storeInfo,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to update store info');
      }
    } catch (e) {
      throw Exception('Update store info error: $e');
    }
  }


  /// Upload store avatar
  static Future<ApiResponse<String>> uploadStoreAvatar({
    required String imagePath,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/admin/store/avatar'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      String? mimeType = lookupMimeType(imagePath);
      if (mimeType == null) {
        String extension = imagePath.split('.').last.toLowerCase();
        if (['jpg', 'jpeg'].contains(extension)) {
          mimeType = 'image/jpeg';
        } else if (extension == 'png') {
          mimeType = 'image/png';
        } else {
          mimeType = 'image/jpeg';
        }
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imagePath,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send();
      final respStr = await response.stream.bytesToString();
      final jsonResponse = json.decode(respStr);

      return ApiResponse<String>.fromJson(jsonResponse);
    } catch (e) {
      throw Exception('Upload store avatar error: $e');
    }
  }

  static Future<Map<String, dynamic>> closeShift() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/receptionist/shift/close");
      final response = await http.get(  // ✅ Đổi từ POST thành GET
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        // ✅ Bỏ body vì GET không hỗ trợ và backend không cần
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);  // { "success": true, "message": "..." }
      } else {
        throw Exception("Server error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      throw Exception("Failed to close shift: $e");
    }
  }

  static Future<ApiResponse<StoreInfo>> getStoreInfo() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/receptionist/store-info');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      final apiResponse = ApiResponse.fromJson(data);

      if (apiResponse.isSuccess && apiResponse.data != null) {
        final storeInfo = StoreInfo.fromJson(apiResponse.data as Map<String, dynamic>);
        return ApiResponse<StoreInfo>(
          code: apiResponse.code,
          status: apiResponse.status,
          message: apiResponse.message,
          time: apiResponse.time,
          data: storeInfo,
        );
      }

      return ApiResponse<StoreInfo>(
        code: apiResponse.code,
        status: apiResponse.status,
        message: apiResponse.message,
        time: apiResponse.time,
      );
    } catch (e) {
      return ApiResponse<StoreInfo>(
        code: 500,
        status: 'error',
        message: 'Error: $e',
        time: DateTime.now().toIso8601String(),
      );
    }
  }

  static Future<List<AvailableService>> getAvailableServicesForStaff({
    required int bookingId,
    required int staffId,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/receptionist/$bookingId/available-services/$staffId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody['code'] == 900) {
          final List<dynamic> servicesJson = resBody['data'];
          return servicesJson
              .map((json) => AvailableService.fromJson(json))
              .toList();
        } else {
          throw Exception(resBody['message'] ?? 'Error fetching services');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch available services: $e');
    }
  }

  static Future<ApiResponse> addStaffToBooking({
    required int bookingId,
    required int staffId,
    List<int>? existingServiceIds,
    List<NewServiceRequest>? newServices,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/receptionist/$bookingId/add-staff');

      final body = {
        'staffId': staffId,
        if (existingServiceIds != null && existingServiceIds.isNotEmpty)
          'existingServiceIds': existingServiceIds,
        if (newServices != null && newServices.isNotEmpty)
          'newServices': newServices.map((s) => s.toJson()).toList(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return ApiResponse.fromJson(data);
    } catch (e) {
      return ApiResponse(
        code: 500,
        status: 'error',
        message: 'Network error: $e',
        time: DateTime.now().toIso8601String(),
      );
    }
  }

  static Future<HeatmapApiResponse> getClientsHeatmap({
    required DateTime start,
    required DateTime end,
    required String role
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) {
        return HeatmapApiResponse(code: 401, status: 'error', message: 'No token', time: '');
      }

      final url = Uri.parse('$baseUrl/admin/clients-heatmap')
          .replace(queryParameters: {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'role': role
      });

      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      final jsonMap = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return HeatmapApiResponse.fromJson(jsonMap);
    } catch (e) {
      return HeatmapApiResponse(code: 500, status: 'error', message: e.toString(), time: '');
    }
  }

  static Future<AvatarUploadResponse> uploadAvatar(
    int userId,
    String imagePath,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/$userId/avatar'),
    );

    // ✅ DETECT MIME TYPE TỪ PATH VÀ HEADER BYTES (MAGIC BYTES)
    String? mimeType = lookupMimeType(imagePath);
    if (mimeType == null) {
      // Fallback: Dựa trên extension (an toàn cho .jpeg)
      String extension = imagePath.split('.').last.toLowerCase();
      if (['jpg', 'jpeg'].contains(extension)) {
        mimeType = 'image/jpeg';
      } else if (extension == 'png') {
        mimeType = 'image/png';
      } else {
        mimeType = 'image/jpeg'; // Default cho image
      }
    }

    // ✅ UPLOAD VỚI CONTENT-TYPE RÕ RÀNG
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imagePath,
        contentType: MediaType.parse(mimeType!), // ← SET MIME ĐÂY
      ),
    );

    final response = await request.send();
    final respStr = await response.stream.bytesToString();
    final jsonResponse = json.decode(respStr);

    return AvatarUploadResponse.fromJson(jsonResponse);
  }

  /// Get user's gift cards
  static Future<List<UserGiftCard>> getUserGiftCards() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/gift-cards");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final List<dynamic> data = resBody["data"];
          return data.map((e) => UserGiftCard.fromJson(e)).toList();
        } else {
          throw Exception(resBody["message"] ?? "Error fetching gift cards");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch gift cards: $e");
    }
  }

  /// Get user's gift card transactions (paginated)
  static Future<Map<String, dynamic>> getUserGiftCardTransactions({
    int page = 0,
    int size = 10,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse(
        "$baseUrl/user/gift-card-transactions?page=$page&size=$size",
      );
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> content = data["content"];
          final bool hasNextPage = data["hasNext"] ?? false;

          return {
            'content':
                content.map((e) => GiftCardTransaction.fromJson(e)).toList(),
            'hasNextPage': hasNextPage,
          };
        } else {
          throw Exception(resBody["message"] ?? "Error fetching transactions");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch transactions: $e");
    }
  }

  static Future<bool> checkGiftCardExists(String code) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/receptionist/giftcard/check/$code");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        return resBody["data"] == true; // true if exists, false if not
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to check gift card: $e");
    }
  }

  /// Activate a new gift card (card chưa tồn tại trong DB)
  static Future<Map<String, dynamic>> activateGiftCard({
    required String code,
    required String phoneNumber,
    required double amount,
    required int paymentMethod,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/receptionist/giftcard/activate");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "code": code,
          "phoneNumber": phoneNumber,
          "amount": amount,
          "paymentMethod": paymentMethod,
        }),
      );

      final Map<String, dynamic> resBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (resBody["code"] == 900) {
          return {
            'success': true,
            'message': resBody["message"] ?? "Gift card activated successfully",
            'data': resBody["data"],
          };
        } else {
          return {
            'success': false,
            'message': resBody["message"] ?? "Failed to activate gift card",
          };
        }
      } else {
        return {
          'success': false,
          'message':
              resBody["message"] ?? "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      throw Exception("Failed to activate gift card: $e");
    }
  }

  /// Top-up an existing gift card (card đã tồn tại trong DB)
  static Future<Map<String, dynamic>> topupGiftCard({
    required String code,
    required double amount,
    required int paymentMethod,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/receptionist/giftcard/topup");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "code": code,
          "amount": amount,
          "paymentMethod": paymentMethod,
        }),
      );

      final Map<String, dynamic> resBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (resBody["code"] == 900) {
          return {
            'success': true,
            'message': resBody["message"] ?? "Gift card topped up successfully",
            'data': resBody["data"],
          };
        } else {
          return {
            'success': false,
            'message': resBody["message"] ?? "Failed to top-up gift card",
          };
        }
      } else {
        return {
          'success': false,
          'message':
              resBody["message"] ?? "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      throw Exception("Failed to top-up gift card: $e");
    }
  }

  /// Get gift card transaction history with pagination and search
  static Future<Map<String, dynamic>> getGiftcardHistory({
    int page = 0,
    int size = 10,
    String? search,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      String urlString =
          "$baseUrl/receptionist/giftcard/history?page=$page&size=$size";
      if (search != null && search.isNotEmpty) {
        urlString += "&search=${Uri.encodeQueryComponent(search)}";
      }

      final url = Uri.parse(urlString);
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> historyJson = data["content"];
          final bool hasNextPage = data["hasNextPage"] ?? false;

          return {
            'content':
                historyJson
                    .map((e) => GiftCardTransactionHistory.fromJson(e))
                    .toList(),
            'hasNextPage': hasNextPage,
          };
        } else {
          throw Exception(
            resBody["message"] ?? "Error fetching giftcard history",
          );
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch giftcard history: $e");
    }
  }

  static Future<Map<String, dynamic>> createOrTopupGiftCard({
    required double amount,
    required int paymentMethod,
    String? code,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final body = {
        'amount': amount,
        'paymentMethod': paymentMethod,
        if (code != null && code.isNotEmpty) 'code': code,
      };

      final url = Uri.parse("$baseUrl/receptionist/giftcard/topup");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return {
            'success': true,
            'message': resBody["message"],
            'data': resBody["data"],
          };
        } else {
          return {
            'success': false,
            'message': resBody["message"] ?? "Error processing giftcard",
          };
        }
      } else {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              resBody["message"] ?? "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {'success': false, 'message': "Failed to process giftcard: $e"};
    }
  }

  static Future<Map<String, dynamic>> checkUserByPhone(String phone) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/check-by-phone?phone=$phone'),
        headers: {'Content-Type': 'application/json'}, // ✅ THÊM HEADER
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'exists': data['exists'] ?? false,
          'userId': data['userId'], // Backend sẽ trả về userId sau khi sửa
        };
      }
      throw Exception('Failed to check user');
    } catch (e) {
      throw Exception('Failed to check user by phone: $e');
    }
  }

  static Future<Map<String, dynamic>> registerUser({
    required String phoneNumber,
    required String fullName,
    required String email,
    required String dob,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'}, // ✅ THÊM HEADER
        body: json.encode({
          'phoneNumber': phoneNumber,
          'fullName': fullName,
          'email': email,
          'dateOfBirth': dob
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 900) {
          return {
            'success': true,
            'userId': data['data'], // ✅ SỬA: Lấy trực tiếp data (là Long/int)
            'message': data['message'],
          };
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Registration failed',
          };
        }
      }
      throw Exception('Registration failed: ${response.body}');
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  /// Get available discount codes for current user
  static Future<ApiResponse> getAvailableDiscounts(int bookingId) async {
    try {
      final token = await getAccessToken();

      final response = await http.get(
        Uri.parse('$baseUrl/receptionist/available/$bookingId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized');
      } else {
        throw Exception('Failed to load available discounts');
      }
    } catch (e) {
      print('Error getting available discounts: $e');
      throw Exception('Error: $e');
    }
  }

  /// Get allowed users for discount code
  static Future<ApiResponse> getDiscountAllowedUsers(int discountCodeId) async {
    try {
      final token = await getAccessToken();

      final response = await http.get(
        Uri.parse('$baseUrl/admin/$discountCodeId/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load allowed users');
      }
    } catch (e) {
      print('Error getting allowed users: $e');
      throw Exception('Error: $e');
    }
  }

  /// Update allowed users for discount code
  static Future<ApiResponse> updateDiscountAllowedUsers({
    required int discountCodeId,
    List<int>? userIds,
    bool? availableForAll,
  }) async {
    try {
      final token = await getAccessToken();

      final body = <String, dynamic>{};
      if (userIds != null) body['userIds'] = userIds;
      if (availableForAll != null) body['availableForAll'] = availableForAll;

      final response = await http.put(
        Uri.parse('$baseUrl/admin/$discountCodeId/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to update allowed users');
      }
    } catch (e) {
      print('Error updating allowed users: $e');
      throw Exception('Error: $e');
    }
  }

  static Future<ApiResponse> getStaffPerformance({
    required DateTime startDate,
    required DateTime endDate,
    required String role
  }) async {
    try {
      final token = await getAccessToken();

      // Format dates to ISO 8601 format (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final uri = Uri.parse('$baseUrl/admin/performance').replace(
        queryParameters: {'startDate': startDateStr, 'endDate': endDateStr, 'role': role},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to load staff performance: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching staff performance: $e');
      throw Exception('Error fetching staff performance: $e');
    }
  }

  static Future<ApiResponse> updateStaffShareRate({
    required int staffId,
    required double shareRate,
  }) async {
    try {
      final token = await getAccessToken();

      final response = await http.patch(
        Uri.parse('$baseUrl/admin/$staffId/share-rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'shareRate': shareRate}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to update share rate');
      }
    } catch (e) {
      print('Error updating share rate: $e');
      throw Exception('Error updating share rate: $e');
    }
  }

  /// Update staff tip share rate
  static Future<ApiResponse> updateStaffTipShareRate({
    required int staffId,
    required double tipShareRate,
  }) async {
    try {
      final token = await getAccessToken();

      final response = await http.patch(
        Uri.parse('$baseUrl/admin/$staffId/tip-share-rate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'tipShareRate': tipShareRate}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['message'] ?? 'Failed to update tip share rate',
        );
      }
    } catch (e) {
      print('Error updating tip share rate: $e');
      throw Exception('Error updating tip share rate: $e');
    }
  }

  static Future<ApiResponse> getPaymentBreakdown({
    required DateTime startDate,
    required DateTime endDate,
    required String role
  }) async {
    try {
      final token = await getAccessToken();

      // Format dates to ISO 8601 format (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final uri = Uri.parse('$baseUrl/admin/breakdown').replace(
        queryParameters: {'startDate': startDateStr, 'endDate': endDateStr, 'role': role},
      );


      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else {
        throw Exception(
          'Failed to load payment breakdown: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching payment breakdown: $e');
      throw Exception('Error fetching payment breakdown: $e');
    }
  }

  /// Get staff income list
  /// Returns list of staff with their total income
  static Future<ApiResponse> getStaffIncomeList({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final token = await getAccessToken();

      // Format dates to ISO 8601 format (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final uri = Uri.parse('$baseUrl/admin/income-list').replace(
        queryParameters: {'startDate': startDateStr, 'endDate': endDateStr},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Parse data as List
        if (jsonData['data'] != null) {
          final List<dynamic> dataList = jsonData['data'] as List;
          jsonData['data'] =
              dataList.map((item) => Map<String, dynamic>.from(item)).toList();
        }

        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Staff not found');
      } else {
        throw Exception(
          'Failed to load staff income list: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching staff income list: $e');
      throw Exception('Error fetching staff income list: $e');
    }
  }

  /// Get staff income detail
  /// Returns detailed income information for a specific staff
  static Future<ApiResponse> getStaffIncomeDetail({
    required String staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String role
  }) async {
    try {
      final token = await getAccessToken();

      // Format dates to ISO 8601 format (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final uri = Uri.parse('$baseUrl/admin/$staffId/income-detail').replace(
        queryParameters: {'startDate': startDateStr, 'endDate': endDateStr, 'role': role},
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        // Parse data as Map
        if (jsonData['data'] != null) {
          jsonData['data'] = Map<String, dynamic>.from(jsonData['data']);
        }

        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Staff not found');
      } else {
        throw Exception(
          'Failed to load staff income detail: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching staff income detail: $e');
      throw Exception('Error fetching staff income detail: $e');
    }
  }

  static Future<ApiResponse> getDashboardStats({
    required DateTime startDate,
    required DateTime endDate,
    required String userRole,
  }) async {
    try {
      final token = await getAccessToken();

      // Format dates to ISO 8601 format (YYYY-MM-DD)
      final startDateStr = startDate.toIso8601String().split('T')[0];
      final endDateStr = endDate.toIso8601String().split('T')[0];

      final uri = Uri.parse('$baseUrl/admin/dashboard/stats').replace(
        queryParameters: {
          'startDate': startDateStr,
          'endDate': endDateStr,
          'userRole': userRole,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 404) {
        throw Exception('Store not found');
      } else {
        throw Exception(
          'Failed to load dashboard statistics: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching dashboard statistics: $e');
      throw Exception('Error fetching dashboard statistics: $e');
    }
  }

  static Future<ApiResponse> getStaffStatistics({
    required DateTime startDate,
    required DateTime endDate,
    required String userRole,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final startDateStr = startDate.toIso8601String();
      final endDateStr = endDate.toIso8601String();

      final uri = Uri.parse('$baseUrl/admin/staff-statistics').replace(
        queryParameters: {
          'startDate': startDateStr,
          'endDate': endDateStr,
          'userRole': userRole,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to load staff statistics: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching staff statistics: $e');
    }
  }

  /**
   * Lấy chi tiết income của 1 staff
   * GET /api/staff-statistics/{staffId}
   */
  static Future<ApiResponse> getStaffDetailIncome({
    required int staffId,
    required DateTime startDate,
    required DateTime endDate,
    required String userRole,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final startDateStr = startDate.toIso8601String();
      final endDateStr = endDate.toIso8601String();

      final uri = Uri.parse('$baseUrl/api/staff-statistics/$staffId').replace(
        queryParameters: {
          'startDate': startDateStr,
          'endDate': endDateStr,
          'userRole': userRole,
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load staff income: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching staff income: $e');
    }
  }

  static Future<ApiResponse<String>> receptionistCheckinBooking(
    int bookingId,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/receptionist/checkin/$bookingId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<String>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to checkin booking');
      }
    } catch (e) {
      throw Exception('Checkin error: $e');
    }
  }

  static Future<ApiResponse> reassignBookingStaff({
    required int bookingId,
    required int newStaffId,
    int? oldStaffId,  // ⭐ THÊM parameter
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/receptionist/reassign-staff');

      final body = {
        'bookingId': bookingId,
        'newStaffId': newStaffId,
        if (oldStaffId != null) 'oldStaffId': oldStaffId,  // ⭐ THÊM
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return ApiResponse.fromJson(data);
    } catch (e) {
      return ApiResponse.error('Error: $e');

    }
  }



  static Future<Map<String, dynamic>> quickAddServiceToBooking(
    int bookingId,
    double price,
    String note,
  ) async {
    final token = await getAccessToken(); // Hoặc cách lấy token của bạn

    final response = await http.post(
      Uri.parse('$baseUrl/staff/$bookingId/services/quick-add'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Thêm token vào header
      },
      body: json.encode({'price': price, 'note': note}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add service to booking');
    }
  }

  static Future<CheckinBookingResponse> receptionistSearchCheckinBookings({
    required String searchQuery,
    required int page,
    required int size,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token not available");

      final Uri url = Uri.parse(
        "$baseUrl/receptionist/search-checkin?nameOrPhone=${Uri.encodeQueryComponent(searchQuery)}&page=$page&size=$size",
      );

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return CheckinBookingResponse.fromJson(resBody["data"]);
        } else if (resBody["code"] == 904) {
          // Return empty response for no booking found
          return CheckinBookingResponse(
            bookings: [],
            currentPage: 0,
            totalPages: 0,
            totalItems: 0,
          );
        } else {
          throw Exception(resBody["message"] ?? "Error searching bookings");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to search bookings: $e");
    }
  }

  // Add this method to your ApiService class

  /// Validate discount code and get discount amount
  static Future<ApiResponse<Map<String, dynamic>>> validateDiscountCode({
    required String code,
    required int bookingId,
    required double totalAmount,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/admin/discount/validate'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({
          'discountCode': code,
          'orderAmount': totalAmount,
          'bookingId': bookingId,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // Handle null values for numeric fields
        final data = jsonResponse['data'] as Map<String, dynamic>?;
        if (data != null) {
          data['discountAmount'] = data['discountAmount'] ?? 0.0;
          data['amountAfterDiscount'] =
              data['amountAfterDiscount'] ?? totalAmount;
          data['discountValue'] = data['discountValue'] ?? 0.0;
        }

        return ApiResponse<Map<String, dynamic>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: data,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception(
          'Failed to validate discount code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Discount validation error: $e');
    }
  }

  /// Update completePayment method to include discount code
  static Future<ApiResponse<Map<String, dynamic>>> completePayment({
    required int bookingId,
    required int paymentMethod,
    required double tips,
    List<Map<String, dynamic>>? giftCardUsages,
    double? giftCardAmount,
    double? cashPaidAmount,
    double? creditAmount,
    double? chequeAmount,
    double? othersAmount,
    String? discountCode, // ✅ NEW: Add discount code parameter
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final Map<String, dynamic> requestBody = {
        'bookingId': bookingId,
        'paymentMethod': paymentMethod,
        'tips': tips,
      };

      // Add optional fields only if they are not null
      if (giftCardUsages != null && giftCardUsages.isNotEmpty) {
        requestBody['giftCardUsages'] = giftCardUsages;
      }
      if (giftCardAmount != null)
        requestBody['giftCardAmount'] = giftCardAmount;
      if (cashPaidAmount != null)
        requestBody['cashPaidAmount'] = cashPaidAmount;
      if (creditAmount != null) requestBody['creditAmount'] = creditAmount;
      if (chequeAmount != null) requestBody['chequeAmount'] = chequeAmount;
      if (othersAmount != null) requestBody['othersAmount'] = othersAmount;

      // ✅ Add discount code if provided
      if (discountCode != null && discountCode.isNotEmpty) {
        requestBody['discountCode'] = discountCode;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/admin/payment/complete'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: jsonResponse['data'] as Map<String, dynamic>?,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Payment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Payment error: $e');
    }
  }

  static Future<void> resetBooking() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/receptionist/reset-booking'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      throw Exception('Error fetching discount codes: $e');
    }
  }

  static Future<ApiResponse> getAllDiscountCodes() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/discount-codes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to load discount codes: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching discount codes: $e');
    }
  }

  static Future<ApiResponse> getDiscountCodeById(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/discount-codes/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load discount code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching discount code: $e');
    }
  }

  static Future<ApiResponse> createDiscountCode(Map<String, dynamic> data) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/admin/discount-codes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        // Parse error response for better handling
        try {
          final errorJson = json.decode(response.body);
          if (errorJson['code'] == 904) {
            throw Exception('Token expired or invalid. Please log in again.');
          }
          throw Exception('${errorJson['message'] ?? 'Failed to create discount code: ${response.statusCode}'}');
        } catch (_) {
          throw Exception('Failed to create discount code: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Error creating discount code: $e');
    }
  }

  static Future<ApiResponse> updateDiscountCode(int id, Map<String, dynamic> data) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/discount-codes/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        // Parse error response for better handling
        try {
          final errorJson = json.decode(response.body);
          if (errorJson['code'] == 904) {
            throw Exception('Token expired or invalid. Please log in again.');
          }
          throw Exception('${errorJson['message'] ?? 'Failed to update discount code: ${response.statusCode}'}');
        } catch (_) {
          throw Exception('Failed to update discount code: ${response.statusCode}');
        }
      }
    } catch (e) {
      throw Exception('Error updating discount code: $e');
    }
  }

  static Future<ApiResponse> deleteDiscountCode(int id) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.delete(
        Uri.parse('$baseUrl/admin/discount-codes/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to delete discount code: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error deleting discount code: $e');
    }
  }

  static Future<ApiResponse> toggleDiscountCodeStatus(int id, bool active,) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/discount-codes/$id/toggle-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'active': active}),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to toggle status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error toggling status: $e');
    }
  }

  static Future<ApiResponse> getAllCustomerUsers() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/users/role/USER'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to load customer users: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching customer users: $e');
    }
  }

  static Future<ApiResponse> getAllowedUsers(int discountId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/discount-codes/$discountId/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to load allowed users: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching allowed users: $e');
    }
  }

  static Future<ApiResponse> addUsersToDiscount(int discountId, List<int> userIds) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/admin/discount-codes/$discountId/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(userIds),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to add users to discount: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error adding users to discount: $e');
    }
  }

  static Future<ApiResponse> removeUsersFromDiscount(int discountId, List<int> userIds) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.delete(
        Uri.parse('$baseUrl/admin/discount-codes/$discountId/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(userIds),
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return ApiResponse.fromJson(jsonData);
      } else {
        throw Exception(
          'Failed to remove users from discount: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error removing users from discount: $e');
    }
  }

  static Future<ApiResponse<Map<String, dynamic>>> getMyStoreStats({
    required DateTime startDate,
    required DateTime endDate,
    required String userRole,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/stores/my-stats?'
          'startDate=${DateFormat('yyyy-MM-dd').format(startDate)}&'
          'endDate=${DateFormat('yyyy-MM-dd').format(endDate)}&'
          'userRole=$userRole',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<Map<String, dynamic>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: jsonResponse['data'] as Map<String, dynamic>,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get store stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Store stats error: $e');
    }
  }

  static Future<ApiResponse<List<ManagementStaffDTO>>> getStaffList({
    int page = 0,
    int size = 12,
    String searchQuery = '',
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/staff?page=$page&size=$size&search=${Uri.encodeQueryComponent(searchQuery)}',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // SỬA: Parse data theo cách mới
        final staffList = PageResponseParser.parsePageContent(
          jsonResponse,
          (item) => ManagementStaffDTO.fromJson(item),
        );

        return ApiResponse<List<ManagementStaffDTO>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: staffList,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get staff list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Staff list error: $e');
    }
  }

  static Future<ApiResponse<ManagementStaffDTO>> updateStaffStore(
    int staffId,
    int storeId,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/staff/$staffId/store'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({'storeId': storeId}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementStaffDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update staff store');
      }
    } catch (e) {
      throw Exception('Update staff store error: $e');
    }
  }

  static Future<ApiResponse<ManagementStaffDTO>> updateStaffServices(
    int staffId,
    List<int> serviceIds,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/staff/$staffId/services'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({'serviceIds': serviceIds}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementStaffDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update staff services');
      }
    } catch (e) {
      throw Exception('Update staff services error: $e');
    }
  }

  // ========== STORE API ==========
  static Future<ApiResponse<List<ManagementStoreDTO>>> getStoreList({
    int page = 0,
    int size = 12,
    String searchQuery = '',
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/stores?page=$page&size=$size&search=${Uri.encodeQueryComponent(searchQuery)}',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        // SỬA: Dùng PageResponseParser để parse data
        final storeList = PageResponseParser.parsePageContent(
          jsonResponse,
          (item) => ManagementStoreDTO.fromJson(item),
        );

        return ApiResponse<List<ManagementStoreDTO>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: storeList,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get store list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Store list error: $e');
    }
  }

  static Future<ApiResponse<ManagementStoreDTO>> updateStore(
    int storeId,
    ManagementStoreUpdateRequest request,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/stores/$storeId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementStoreDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update store');
      }
    } catch (e) {
      throw Exception('Update store error: $e');
    }
  }

  static Future<ApiResponse<ManagementStoreDTO>> updateStoreCategories(
    int storeId,
    List<int> categoryIds,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/stores/$storeId/categories'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({'categoryIds': categoryIds}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementStoreDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update store categories');
      }
    } catch (e) {
      throw Exception('Update store categories error: $e');
    }
  }

  // ========== CATEGORY API ==========
  static Future<ApiResponse<List<ManagementCategoryDTO>>> getCategoryList({
    int page = 0,
    int size = 12,
    String searchQuery = '',
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/categories?page=$page&size=$size&search=${Uri.encodeQueryComponent(searchQuery)}',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        final categoryList = PageResponseParser.parsePageContent(
          jsonResponse,
          (item) => ManagementCategoryDTO.fromJson(item),
        );

        return ApiResponse<List<ManagementCategoryDTO>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: categoryList,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get category list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Category list error: $e');
    }
  }

  static Future<ApiResponse<List<ManagementServiceDTO>>> getServiceList({
    int page = 0,
    int size = 12,
    String searchQuery = '',
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse(
          '$baseUrl/admin/services?page=$page&size=$size&search=${Uri.encodeQueryComponent(searchQuery)}',
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        final serviceList = PageResponseParser.parsePageContent(
          jsonResponse,
          (item) => ManagementServiceDTO.fromJson(item),
        );

        return ApiResponse<List<ManagementServiceDTO>>(
          code: jsonResponse['code'] as int,
          status: jsonResponse['status'] as String,
          message: jsonResponse['message'] as String,
          data: serviceList,
          time: jsonResponse['time'] as String,
        );
      } else {
        throw Exception('Failed to get service list: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Service list error: $e');
    }
  }

  static Future<ApiResponse<ManagementCategoryDTO>> updateCategory(
    int categoryId,
    ManagementCategoryUpdateRequest request,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/categories/$categoryId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementCategoryDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update category');
      }
    } catch (e) {
      throw Exception('Update category error: $e');
    }
  }

  static Future<ApiResponse<ManagementCategoryDTO>> updateCategoryServices(
    int categoryId,
    List<int> serviceIds,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/categories/$categoryId/services'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({'serviceIds': serviceIds}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementCategoryDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update category services');
      }
    } catch (e) {
      throw Exception('Update category services error: $e');
    }
  }

  static Future<ApiResponse<ManagementServiceDTO>> updateService(
    int serviceId,
    ManagementServiceUpdateRequest request,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/admin/services/$serviceId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<ManagementServiceDTO>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to update service');
      }
    } catch (e) {
      throw Exception('Update service error: $e');
    }
  }

  // Trong class ApiService, thêm các phương thức sau:
  static Future<ApiResponse<String>> checkinBooking(int bookingId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/admin/checkin/$bookingId'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return ApiResponse<String>.fromJson(jsonResponse);
      } else {
        throw Exception('Failed to checkin booking');
      }
    } catch (e) {
      throw Exception('Checkin error: $e');
    }
  }

  static Future<PaymentHistoryResponse> getPaymentHistory({
    required String searchQuery,
    required int page,
    required int size,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final Uri url;
      if (searchQuery.isEmpty) {
        url = Uri.parse("$baseUrl/admin/payment/history?page=$page&size=$size");
      } else {
        url = Uri.parse(
          "$baseUrl/admin/payment/history?searchQuery=${Uri.encodeQueryComponent(searchQuery)}&page=$page&size=$size",
        );
      }

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return PaymentHistoryResponse.fromJson(resBody["data"]);
        } else {
          throw Exception(
            resBody["message"] ?? "Error fetching payment history",
          );
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      print('❌ API error: $e'); // Debug error
      throw Exception("Failed to fetch payment history: $e");
    }
  }

  static Future<Map<String, dynamic>> useGiftCard(
    String code,
    double amount,
    int bookingId,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/admin/giftcard/use/$code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'amount': amount, 'bookingId': bookingId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to use gift card: ${response.body}');
    }
  }

  static Future<void> revertGiftCardUsage(String usageId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/admin/giftcard/usage/$usageId/revert'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to revert gift card usage: ${response.body}');
    }
  }

  static Future<ApiResponse<GiftCardDTO>> getGiftCard(String code) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/admin/giftcard/$code");

      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        if (resBody["code"] == 900) {
          final giftCardJson = resBody["data"];
          return ApiResponse<GiftCardDTO>(
            code: resBody["code"],
            status: resBody["status"],
            message: resBody["message"],
            data: GiftCardDTO.fromJson(giftCardJson),
            time: resBody["time"],
          );
        } else {
          throw Exception(resBody["message"] ?? "Error fetching giftcard");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch giftcard: $e");
    }
  }

  static Future<CheckinBookingResponse> searchCheckinBookings({
    required String searchQuery,
    required int page,
    required int size,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      // Build URL với hoặc không có search query
      final Uri url;
      if (searchQuery.isEmpty) {
        url = Uri.parse("$baseUrl/admin/search-checkin?page=$page&size=$size");
      } else {
        url = Uri.parse(
          "$baseUrl/admin/search-checkin?nameOrPhone=${Uri.encodeQueryComponent(searchQuery)}&page=$page&size=$size",
        );
      }

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return CheckinBookingResponse.fromJson(resBody["data"]);
        } else {
          throw Exception(
            resBody["message"] ?? "Error searching checkin bookings",
          );
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to search checkin bookings: $e");
    }
  }

  // services/api_service.dart
  static Future<BookingHistoryResponse> getBookingHistory({
    required int page,
    required int size,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/booking/history?page=$page&size=$size");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return BookingHistoryResponse.fromJson(resBody["data"]);
        } else {
          throw Exception(
            resBody["message"] ?? "Error fetching booking history",
          );
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch booking history: $e");
    }
  }

  static Future<Map<String, dynamic>> getBookingDetail(int bookingId) async {
    final token = await getAccessToken(); // Hoặc cách lấy token của bạn

    final response = await http.get(
      Uri.parse('$baseUrl/staff/booking-detail/$bookingId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Thêm token vào header
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load booking details');
    }
  }

  // API chuyển trạng thái sang IN_PROGRESS
  static Future<Map<String, dynamic>> startBooking(int bookingId) async {
    final token = await getAccessToken(); // Hoặc cách lấy token của bạn

    final response = await http.put(
      Uri.parse('$baseUrl/staff/$bookingId/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Thêm token vào header
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to start booking');
    }
  }

  static Future<void> requestMoreStaff(int bookingId) async {
    final token = await getAccessToken();

    final response = await http.put(
      Uri.parse('$baseUrl/staff/$bookingId/request-more-staff'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to request more staff');
    }
  }


  // API lấy danh sách services mà staff có thể thêm
  static Future<List<dynamic>> getAvailableServices() async {
    final token = await getAccessToken();

    final response = await http.get(
      Uri.parse('$baseUrl/staff/services/available'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);

      // Kiểm tra cấu trúc response và trả về List<dynamic>
      if (responseData.containsKey('data') && responseData['data'] is List) {
        return responseData['data'] as List<dynamic>;
      } else {
        throw Exception(
          'Invalid response format: data field is missing or not a list',
        );
      }
    } else {
      throw Exception(
        'Failed to load available services: ${response.statusCode}',
      );
    }
  }

  // API thêm service vào booking
  static Future<Map<String, dynamic>> addServiceToBooking(
    int bookingId,
    int serviceId,
  ) async {
    final token = await getAccessToken(); // Hoặc cách lấy token của bạn

    final response = await http.post(
      Uri.parse('$baseUrl/staff/$bookingId/services'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Thêm token vào header
      },
      body: json.encode({'serviceId': serviceId}),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add service to booking');
    }
  }

  // API xóa service khỏi booking
  static Future<void> removeServiceFromBooking(
      int bookingId,
      int bookingServiceId,
      ) async {
    final token = await getAccessToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/staff/$bookingId/services/$bookingServiceId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    // ⭐ PARSE RESPONSE BODY ĐỂ KIỂM TRA ERROR CODE
    final responseData = json.decode(response.body);

    if (responseData['code'] == 900) {
      // Success
      return;
    } else {
      // Có lỗi từ backend với custom code
      throw Exception(responseData['message'] ?? 'Failed to remove service from booking');
    }
  }

  // API chốt bill (chuyển sang WAITING_PAYMENT)
  static Future<Map<String, dynamic>> completeBooking(
    int bookingId,
    double tipAmount,
    List<ServicePriceUpdate>? servicePriceUpdates,
  ) async {
    final token = await getAccessToken();

    final Map<String, dynamic> requestBody = {'tip': tipAmount};

    if (servicePriceUpdates != null && servicePriceUpdates.isNotEmpty) {
      requestBody['servicePriceUpdates'] =
          servicePriceUpdates
              .map(
                (update) => {
                  'bookingServiceId': update.bookingServiceId,
                  'newPrice': update.newPrice,
                  'priceNote': update.priceNote,
                },
              )
              .toList();
    }

    final response = await http.put(
      Uri.parse('$baseUrl/staff/$bookingId/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(requestBody),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to complete booking');
    }
  }

  static Future<List<QuickServiceModel>> getAllServiceByStore(
    int storeId,
  ) async {
    // Lấy token từ storage
    final token = await getAccessToken(); // Hoặc cách lấy token của bạn

    final response = await http.get(
      Uri.parse('$baseUrl/user/service/$storeId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', // Thêm token vào header
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> servicesJson = data['data'] ?? [];
      return servicesJson
          .map((json) => QuickServiceModel.fromJson(json))
          .toList();
    } else if (response.statusCode == 401) {
      // Token hết hạn hoặc không hợp lệ
      throw Exception('Unauthorized - Please login again');
    } else {
      throw Exception('Failed to load services: ${response.statusCode}');
    }
  }

  static Future<List<ServiceModel>> getServicesByCategory(
    String cateName,
    int storeId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/category/$cateName/$storeId'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> servicesJson = data['data'] ?? [];
      return servicesJson.map((json) => ServiceModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load services');
    }
  }

  static Future<List<PhoneNumber>> getUserPhoneNumbers() async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.get(
        Uri.parse('$baseUrl/user/get-numbers'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> phoneNumbersJson = (data['data'] ?? []) as List;

        return phoneNumbersJson
            .map((json) => PhoneNumber.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load phone numbers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch phone numbers: $e');
    }
  }

  static Future<void> savePhoneNumber(String phoneNumber) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.post(
        Uri.parse('$baseUrl/user/add-number'),
        headers: {
          'Content-Type': 'application/json',
          "Authorization": "Bearer $token",
          "ngrok-skip-browser-warning": "true",
        },
        body: json.encode({'phone_number': phoneNumber}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to save phone number');
      }
    } catch (e) {
      print('Error saving phone number: $e');
      throw Exception('Failed to save phone number: $e');
    }
  }

  static Future<void> setPrimaryPhoneNumber(int phoneId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.put(
        Uri.parse('$baseUrl/user/number/$phoneId/set-primary'),
        headers: {
          "Authorization": "Bearer $token",
          "ngrok-skip-browser-warning": "true",
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to set primary phone number');
      }
    } catch (e) {
      print('Error setting primary phone: $e');
      throw Exception('Failed to set primary phone number: $e');
    }
  }

  static Future<void> deletePhoneNumber(int phoneId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final response = await http.delete(
        Uri.parse('$baseUrl/user/number/$phoneId'),
        headers: {
          "Authorization": "Bearer $token",
          "ngrok-skip-browser-warning": "true",
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete phone number');
      }
    } catch (e) {
      print('Error deleting phone number: $e');
      throw Exception('Failed to delete phone number: $e');
    }
  }

  static Future<StaffDetail> getStaffDetailForReceptionist(int staffId) async {
    try {
      final token = await getAccessToken(); // nếu có token
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/receptionist/staff-detail/$staffId");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer $token", // nếu API ko cần auth thì bỏ dòng này
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return StaffDetail.fromJson(resBody["data"]);
        } else {
          throw Exception(resBody["message"] ?? "Error fetching staff detail");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch staff detail: $e");
    }
  }

  static Future<StaffDetail> getStaffDetail(int staffId) async {
    try {
      final token = await getAccessToken(); // nếu có token
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/staff-detail/$staffId");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer $token", // nếu API ko cần auth thì bỏ dòng này
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          return StaffDetail.fromJson(resBody["data"]);
        } else {
          throw Exception(resBody["message"] ?? "Error fetching staff detail");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch staff detail: $e");
    }
  }

  static Future<List<StaffSimple>> getAllStaff(int storeId) async {
    try {
      final token = await getAccessToken(); // nếu có token
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/get-all-staff/$storeId");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer $token", // nếu API không cần auth thì bỏ dòng này
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final List<dynamic> data = resBody["data"];
          return data.map((e) => StaffSimple.fromJson(e)).toList();
        } else {
          throw Exception(resBody["message"] ?? "Error fetching staff");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch staff: $e");
    }
  }

  static Future<List<NailStoreSimple>> getStores() async {
    try {
      final token = await getAccessToken(); // nếu có token
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/get-stores");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "Bearer $token", // nếu API không cần auth thì bỏ dòng này
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final List<dynamic> data = resBody["data"];
          return data.map((e) => NailStoreSimple.fromJson(e)).toList();
        } else {
          throw Exception(resBody["message"] ?? "Error fetching stores");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch stores: $e");
    }
  }

  static Future<Map<String, dynamic>> getUserBookings({
    int page = 0,
    int size = 10,
    required BookingStatus status,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse(
        "$baseUrl/user/booking?page=$page&size=$size&status=${status.name}",
      );
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> bookingsJson = data["content"];
          final bool hasNextPage = !data['last'];
          final bool hasPreviousPage = page > 0;

          return {
            'content': bookingsJson.map((e) => Booking.fromJson(e)).toList(),
            'hasNextPage': hasNextPage,
            'hasPreviousPage': hasPreviousPage,
          };
        } else {
          throw Exception(resBody["message"] ?? "Error fetching bookings");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch bookings: $e");
    }
  }

  static Future<Map<String, dynamic>> getBookings({
    int page = 0,
    int size = 99999,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse(
        "$baseUrl/staff/booking/future?page=$page&size=$size",
      ); // Add pagination parameters

      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> bookingsJson = data["content"];
          final bool hasNextPage =
              !data['last']; // Use 'last' from pagination metadata
          final bool hasPreviousPage =
              page > 0; // Simplified assumption based on page number

          return {
            'content': bookingsJson.map((e) => BookingDTO.fromJson(e)).toList(),
            'hasNextPage': hasNextPage,
            'hasPreviousPage': hasPreviousPage,
          };
        } else {
          throw Exception(resBody["message"] ?? "Error fetching bookings");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch bookings: $e");
    }
  }

  static Future<Map<String, dynamic>> getPastBookings({
    int page = 0,
    int size = 99999,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse(
        "$baseUrl/staff/booking/history?page=$page&size=$size",
      );
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> bookingsJson = data["bookings"]["content"];

          final bool hasNextPage = !data["bookings"]["last"];
          final bool hasPreviousPage = page > 0;

          return {
            'content': bookingsJson.map((e) => BookingDTO.fromJson(e)).toList(),
            'hasNextPage': hasNextPage,
            'hasPreviousPage': hasPreviousPage,
            'accumulateTip': data["accumulateTip"] ?? 0.0,
            'accumulateShare': data["accumulateShare"] ?? 0.0,
          };
        } else {
          throw Exception(resBody["message"] ?? "Error fetching past bookings");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch past bookings: $e");
    }
  }

  static Future<Map<String, dynamic>> createBooking({
    required int staffId,
    required int customerId,
    required String customerPhone,
    required String startTime,
    required int storeId,
    required List<int> serviceIds,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/user/booking');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'staffId': staffId,
          'customerId': customerId,
          'customerPhone': customerPhone,
          'startTime': startTime,
          'storeId': storeId,
          'serviceIds': serviceIds,
        }),
      );

      final Map<String, dynamic> resBody = jsonDecode(response.body);
      if (response.statusCode == 200 && resBody['code'] == 900) {
        return {'success': true, 'message': resBody['message']};
      } else {
        return {
          'success': false,
          'message': resBody['message'] ?? 'Error creating booking',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to create booking: $e'};
    }
  }

  static Future<Map<String, dynamic>> receptionistCreateBooking({
    required int staffId,
    required int customerId,
    required String customerPhone,
    required String startTime,
    required int storeId,
    required List<int> serviceIds,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      final url = Uri.parse('$baseUrl/receptionist/booking');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'staffId': staffId,
          'customerId': customerId,
          'customerPhone': customerPhone,
          'startTime': startTime,
          'storeId': storeId,
          'serviceIds': serviceIds,
        }),
      );

      final Map<String, dynamic> resBody = jsonDecode(response.body);
      if (response.statusCode == 200 && resBody['code'] == 900) {
        return {'success': true, 'message': resBody['message']};
      } else {
        return {
          'success': false,
          'message': resBody['message'] ?? 'Error creating booking',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Failed to create booking: $e'};
    }
  }

  /// Hàm login
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String? fullName,
    String? email,
    String? phoneNumber,
  }) async {
    final url = Uri.parse("$baseUrl/auth/authenticate");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "fullName": fullName ?? "",
          "email": email ?? "",
          "phoneNumber": phoneNumber ?? "",
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final data = resBody["data"];
          final String accessToken = data["accessToken"];
          final String role = data["role"];
          final int id = data["id"];
          final String fullName = data["fullName"];
          final String wallet = data["wallet"];

          // Lưu session
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("accessToken", accessToken);
          await prefs.setString("role", role);
          await prefs.setString("username", username);
          await prefs.setString("fullName", fullName);
          await prefs.setInt("id", id);
          await prefs.setString("wallet", wallet);

          // Lấy FCM token từ storage
          String? fcmToken = prefs.getString("fcmToken");

          // Nếu chưa có, tạo token mới
          if (fcmToken == null) {
            fcmToken = await FirebaseMessaging.instance.getToken();
            if (fcmToken != null) {
              await prefs.setString("fcmToken", fcmToken);
            }
          }

          // Gửi token lên server
          if (fcmToken != null) {
            await sendFcmTokenToServer(fcmToken, username);
          }

          return {"success": true, "message": resBody["message"], "data": data};
        } else {
          return {"success": false, "message": resBody["message"]};
        }
      } else {
        return {
          "success": false,
          "message": "Server error: ${response.statusCode}",
        };
      }
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// Lấy accessToken đã lưu
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt("id");
  }

  /// Lấy role đã lưu
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("role");
  }

  /// Xóa token (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy accessToken và fcmToken từ local storage trước khi xóa
    String? accessToken = prefs.getString("accessToken");
    String? fcmToken = prefs.getString("fcmToken");

    // Nếu có accessToken và fcmToken, gọi API logout để xóa server-side
    if (accessToken != null &&
        fcmToken != null &&
        accessToken.isNotEmpty &&
        fcmToken.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode({'fcmToken': fcmToken}),
        );

        if (response.statusCode == 200) {

        } else {
          final responseBody = jsonDecode(response.body);
          final message = responseBody['message'] ?? '';
          // Bỏ qua lỗi này
          if (message !=
              "Failed to logout: Only ADMIN or STAFF can logout with FCM token") {
          }
        }
      } catch (e) {
        print('Error calling logout API: $e');
      }
    }

    // Clear tất cả local storage
    await prefs.remove("accessToken");
    await prefs.remove("role");
    await prefs.remove("username");
    await prefs.remove("fullName");
    await prefs.remove("id");
    await prefs.remove("fcmToken"); // Xóa fcmToken sau khi gọi API
    await prefs.remove("wallet"); // Xóa fcmToken sau khi gọi API
  }


  static Future<NailStoreModel> getStoreByName(String storeName) async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/store/$storeName'),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);

      final storeJson = data['data'];
      return NailStoreModel.fromJson(storeJson);
    } else {
      throw Exception('Failed to load store');
    }
  }

  static Future<List<StaffSchedule>> getAllStaffSchedule({
    required int storeId,
    required int type,
    required DateTime date,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      // format date thành yyyy-MM-dd
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final url = Uri.parse(
        '$baseUrl/receptionist/schedule/$storeId/$type?date=$dateStr',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody['code'] == 900) {
          final List<dynamic> schedulesJson = resBody['data'];

          return schedulesJson.map((e) => StaffSchedule.fromJson(e)).toList();
        } else {
          throw Exception(resBody['message'] ?? 'Error fetching schedule');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch schedule: $e');
    }
  }

  static Future<List<StaffSlot>> getStaffSchedule({
    required int staffId,
    required int type,
    required DateTime date,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception('Access token null');

      // format date thành yyyy-MM-dd
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      final url = Uri.parse(
        '$baseUrl/auth/schedule/$staffId/$type?date=$dateStr',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody['code'] == 900) {
          final List<dynamic> slotsJson = resBody['data'];
          return slotsJson.map((e) => StaffSlot.fromJson(e)).toList();
        } else {
          throw Exception(resBody['message'] ?? 'Error fetching schedule');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch schedule: $e');
    }
  }

  static Future<void> sendFcmTokenToServer(
    String token,
    String username,
  ) async {
    final url = Uri.parse("$baseUrl/auth/register-fcm-token");
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': token, 'username': username}),
      );
    } catch (e) {
      print('Error sending FCM token: $e');
    }
  }

  static Future<Map<String, dynamic>> getUserListBookings({
    int page = 0,
    int size = 10,
    required BookingStatus status,
  }) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse(
        "$baseUrl/user/bookings?page=$page&size=$size&status=${status.name}",
      );
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          final List<dynamic> bookingsJson = data["content"];
          final bool hasNextPage = !data['last'];
          final bool hasPreviousPage = page > 0;

          return {
            'content':
                bookingsJson.map((e) => UserBookingList.fromJson(e)).toList(),
            'hasNextPage': hasNextPage,
            'hasPreviousPage': hasPreviousPage,
          };
        } else {
          throw Exception(resBody["message"] ?? "Error fetching bookings");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch bookings: $e");
    }
  }

  static Future<UserBookingDetail> getUserBookingDetail(int bookingId) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/bookings/$bookingId");
      final response = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);

        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          return UserBookingDetail.fromJson(data);
        } else {
          throw Exception(
            resBody["message"] ?? "Error fetching booking detail",
          );
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to fetch booking detail: $e");
    }
  }

  static Future<UserCancelBookingResponse> cancelBooking(
    int bookingId,
    String cancelReason,
  ) async {
    try {
      final token = await getAccessToken();
      if (token == null) throw Exception("Access token null");

      final url = Uri.parse("$baseUrl/user/bookings/$bookingId/cancel");
      final requestBody = jsonEncode({'cancelReason': cancelReason});

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resBody = jsonDecode(response.body);
        if (resBody["code"] == 900) {
          final Map<String, dynamic> data = resBody["data"];
          return UserCancelBookingResponse.fromJson(data);
        } else {
          throw Exception(resBody["message"] ?? "Error cancelling booking");
        }
      } else {
        throw Exception("Server error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Failed to cancel booking: $e");
    }
  }
}

class ServicePriceUpdate {
  final int bookingServiceId;
  final double newPrice;
  final String priceNote;

  ServicePriceUpdate({
    required this.bookingServiceId,
    required this.newPrice,
    required this.priceNote,
  });
}
