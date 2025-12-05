import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/navigation/navigation_file.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:intl/intl.dart';

class ServicePriceEdit {
  final int bookingServiceId;
  double currentPrice;
  final double originalPrice;
  String note;

  ServicePriceEdit({
    required this.bookingServiceId,
    required this.currentPrice,
    required this.originalPrice,
    this.note = '',
  });
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String userphoto;
  final int bookingId;

  const ChatScreen({
    super.key,
    required this.username,
    required this.userphoto,
    required this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _showPaymentForm = false;
  double _tipAmount = 0.0;
  final TextEditingController _tipController = TextEditingController();
  Map<String, dynamic>? _bookingDetail;
  List<dynamic> _availableServices = [];
  bool _isLoading = true;
  bool _isStarting = false;
  bool _isAddingService = false;
  bool _isLoadingServices = false;
  bool _isRequestingMoreStaff = false; // ⭐ THÊM

  // Staff status tracking
  bool _canStartBooking = true; // ⭐ THÊM
  String? _currentStaffStatus; // ⭐ THÊM

  // Thêm các biến cho việc chỉnh sửa giá
  Map<int, ServicePriceEdit> _priceEdits = {};
  bool _showPriceEditDialog = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tipController.addListener(_validateTipInput);
    _loadBookingDetail();
  }

  @override
  void dispose() {
    _tipController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showQuickAddForm() {
    final TextEditingController noteController = TextEditingController();
    final TextEditingController priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Add'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: priceController,
                    decoration: const InputDecoration(
                      labelText: 'Price (\$)',
                      prefixText: '\$',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final priceText = priceController.text.trim();
              final price = double.tryParse(priceText);
              final note = noteController.text.trim();

              if (price == null || price <= 0 || price > 1000) {
                _showErrorSnackBar("Price must be greater than 0 and less than 1000");
                return;
              }

              Navigator.pop(context);

              setState(() => _isAddingService = true);

              try {
                await ApiService.quickAddServiceToBooking(widget.bookingId, price, note);
                await _loadBookingDetail();
                _showSuccessSnackBar("Quick service added successfully");
              } catch (e) {
                _showErrorSnackBar("Failed to add quick service: $e");
              } finally {
                setState(() => _isAddingService = false);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBookingDetail() async {
    try {
      final booking = await ApiService.getBookingDetail(widget.bookingId);
      setState(() {
        _bookingDetail = booking['data'];
        _canStartBooking = booking['data']['canStart'] ?? true; // ⭐ THÊM
        _currentStaffStatus = booking['data']['currentStaffStatus']; // ⭐ THÊM
        _isLoading = false;
        _initializePriceEdits();
      });

      if (_isInProgress) {
        await _loadAvailableServices();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load booking details: $e');
    }
  }

  void _initializePriceEdits() {
    _priceEdits.clear();
    final bookingServices = _bookingDetail?['bookingServices'] as List? ?? [];

    for (var bookingService in bookingServices) {
      final bookingServiceId = bookingService['id'] as int;
      final service = bookingService['service'];
      final originalPrice = (service['price'] as num).toDouble();
      final finalPrice =
          bookingService['finalPrice'] as double? ?? originalPrice;

      _priceEdits[bookingServiceId] = ServicePriceEdit(
        bookingServiceId: bookingServiceId,
        currentPrice: finalPrice,
        originalPrice: originalPrice,
        note: bookingService['priceNote'] ?? '',
      );
    }
  }

  Future<void> _loadAvailableServices() async {
    try {
      setState(() {
        _isLoadingServices = true;
      });

      final services = await ApiService.getAvailableServices();
      final bookingServices = _bookingDetail?['bookingServices'] as List? ?? [];
      final existingServiceIds =
          bookingServices
              .map<int>((bs) => (bs['service']['id'] as num).toInt())
              .toSet();

      final availableServices =
          services.where((service) {
            final serviceId = (service['id'] as num).toInt();
            return !existingServiceIds.contains(serviceId);
          }).toList();

      setState(() {
        _availableServices = availableServices;
        _isLoadingServices = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingServices = false;
      });
      _showErrorSnackBar('Failed to load available services: $e');
    }
  }

  void _validateTipInput() {
    String input = _tipController.text;

    if (input.isEmpty) {
      setState(() {
        _tipAmount = 0;
        _tipController.text = "";
      });
      return;
    }

    if (input.startsWith('0') && input.length > 1 && input != "0.") {
      input = input.replaceFirst(RegExp(r'^0+(?=.)'), '');
      _tipController.text = input;
      _tipController.selection = TextSelection.fromPosition(
        TextPosition(offset: _tipController.text.length),
      );
    }

    double? value = double.tryParse(input);
    if (value == null || value < 0) {
      setState(() {
        _tipController.text = _tipAmount > 0 ? _tipAmount.toString() : "";
      });
    } else {
      setState(() {
        _tipAmount = value;
      });
    }
  }

  Future<void> _startBooking() async {
    if (_isStarting) return;

    setState(() {
      _isStarting = true;
    });

    try {
      await ApiService.startBooking(widget.bookingId);
      await _loadBookingDetail();
      _showSuccessSnackBar('Booking started successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to start booking: $e');
    } finally {
      setState(() {
        _isStarting = false;
      });
    }
  }

  // ⭐ THÊM METHOD REQUEST MORE STAFF
  Future<void> _requestMoreStaff() async {
    if (_isRequestingMoreStaff) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Request More Staff'),
            content: const Text(
              'Are you sure you want to request more staff? '
              'This will mark your current services as completed and notify the receptionist.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('Confirm'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRequestingMoreStaff = true;
    });

    try {
      await ApiService.requestMoreStaff(widget.bookingId);
      await _loadBookingDetail();
      _showSuccessSnackBar('Request for more staff submitted successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to request more staff: $e');
    } finally {
      setState(() {
        _isRequestingMoreStaff = false;
      });
    }
  }

  Future<void> _addServiceToBooking(int serviceId) async {
    if (_isAddingService) return;

    setState(() {
      _isAddingService = true;
    });

    try {
      await ApiService.addServiceToBooking(widget.bookingId, serviceId);
      await _loadBookingDetail();
      _showSuccessSnackBar('Service added successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to add service: $e');
    } finally {
      setState(() {
        _isAddingService = false;
      });
    }
  }

  Future<void> _removeServiceFromBooking(int bookingServiceId) async {
    try {
      await ApiService.removeServiceFromBooking(
        widget.bookingId,
        bookingServiceId,
      );
      await _loadBookingDetail();
      _showSuccessSnackBar("Service removed successfully");
    } catch (e) {
      // ⭐ XỬ LÝ ERROR MESSAGE TỪ BACKEND
      String errorMessage = "Failed to remove service";

      if (e.toString().contains('918')) {
        errorMessage = "You don't have permission to remove this service";
      } else if (e.toString().contains('913')) {
        errorMessage = "Only IN_PROGRESS bookings can remove services";
      } else {
        // Extract message từ JSON response nếu có
        try {
          final errorJson = json.decode(e.toString());
          if (errorJson['message'] != null) {
            errorMessage = errorJson['message'];
          }
        } catch (_) {
          // Nếu không parse được JSON, dùng message gốc
          errorMessage = e.toString();
        }
      }

      _showErrorSnackBar(errorMessage);
    }
  }

  void _showPriceEditDialogForService(ServicePriceEdit priceEdit) {
    final TextEditingController priceController = TextEditingController(
      text: priceEdit.currentPrice.toString(),
    );
    final TextEditingController noteController = TextEditingController(
      text: priceEdit.note,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Service Price'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original Price: \$${priceEdit.originalPrice.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Max Price: \$${(priceEdit.originalPrice * 10).toStringAsFixed(2)}',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'New Price',
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText:
                        'Reason for price change (required if price changes)',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final newPrice = double.tryParse(priceController.text);
                  if (newPrice == null) {
                    _showErrorSnackBar('Please enter a valid price');
                    return;
                  }

                  if (newPrice < priceEdit.originalPrice) {
                    _showErrorSnackBar(
                      'Price cannot be lower than original price',
                    );
                    return;
                  }

                  if (newPrice > priceEdit.originalPrice * 10) {
                    _showErrorSnackBar(
                      'Price cannot exceed 10 times the original price',
                    );
                    return;
                  }

                  if (newPrice != priceEdit.originalPrice &&
                      noteController.text.trim().isEmpty) {
                    _showErrorSnackBar('Note is required when changing price');
                    return;
                  }

                  setState(() {
                    priceEdit.currentPrice = newPrice;
                    priceEdit.note = noteController.text.trim();
                  });

                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _completeBooking() async {
    try {
      List<ServicePriceUpdate> priceUpdates = [];

      for (var priceEdit in _priceEdits.values) {
        priceUpdates.add(
          ServicePriceUpdate(
            bookingServiceId: priceEdit.bookingServiceId,
            newPrice: priceEdit.currentPrice,
            priceNote: priceEdit.note,
          ),
        );
      }

      await ApiService.completeBooking(
        widget.bookingId,
        _tipAmount,
        priceUpdates,
      );
      await _loadBookingDetail();

      setState(() {
        _showPaymentForm = false;
      });
      _showSuccessSnackBar('Booking completed successfully', popAfter: true);
    } catch (e) {
      _showErrorSnackBar('Failed to complete booking: $e');
    }
  }

  void _showServiceSelectionDialog() {
    if (_availableServices.isEmpty && !_isLoadingServices) {
      _loadAvailableServices();
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Select Service to Add'),
                content:
                    _isLoadingServices
                        ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Loading available services...'),
                              ],
                            ),
                          ),
                        )
                        : _availableServices.isEmpty
                        ? const Center(
                          child: Text('No available services to add'),
                        )
                        : SizedBox(
                          width: double.maxFinite,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _availableServices.length,
                            itemBuilder: (context, index) {
                              final service = _availableServices[index];
                              return ListTile(
                                leading:
                                    service['imageUrl'] != null
                                        ? CircleAvatar(
                                          backgroundImage: NetworkImage(
                                            service['imageUrl'],
                                          ),
                                        )
                                        : const CircleAvatar(
                                          child: Icon(Icons.spa),
                                        ),
                                title: Text(
                                  service['name'] ?? 'Unknown Service',
                                ),
                                subtitle: Text(
                                  '\$${service['price']?.toStringAsFixed(2) ?? '0.00'}',
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _addServiceToBooking(service['id']);
                                },
                              );
                            },
                          ),
                        ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          ),
    );
  }

  bool get _isInProgress => _bookingDetail?['status'] == 'IN_PROGRESS';
  bool get _canAddServices => _isInProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.porcelainColor,
      bottomNavigationBar: _buildBottomSection(context),
      body: Stack(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 50),
              _buildHeader(),
              const SizedBox(height: 10),
              if (!_isLoading) ...[
                _buildStatusCard(),
                const SizedBox(height: 30),
              ],
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            children: [..._buildServiceList()],
                          ),
                ),
              ),
            ],
          ),
          if (_showPaymentForm)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Center(child: _buildPaymentForm()),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _bookingDetail?['status'] ?? 'UNKNOWN';
    final startTime =
        _bookingDetail?['startTime'] != null
            ? DateTime.parse(_bookingDetail!['startTime'])
            : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.whiteColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Status: ${status.replaceAll('_', ' ')}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (startTime != null) ...[
            const SizedBox(height: 8),
            Text(
              'Start Time: ${DateFormat('HH:mm dd/MM/yyyy').format(startTime)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
          // ⭐ HIỂN THỊ WARNING NẾU KHÔNG THỂ START
          if (!_canStartBooking && status == 'CHECKED_IN') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Another staff member is now responsible for this booking',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.transparent,
              child: GestureDetector(
                onTap: () {
                  Navigation.pop(context);
                },
                child: Transform.scale(
                  scale: 0.8,
                  child: SvgPicture.asset(
                    'assets/icon/back-button.svg',
                    colorFilter: ColorFilter.mode(
                      AppColors.blackColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.transparent,
              child: ClipOval(
                child: Image.asset(
                  widget.userphoto,
                  fit: BoxFit.cover,
                  width: 60,
                  height: 60,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bookingDetail?['customerName'] ?? widget.username,
                    style: const TextStyle(
                      color: AppColors.whiteColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    softWrap: false,
                  ),
                  if (_bookingDetail?['customerPhone'] != null)
                    Text(
                      _bookingDetail!['customerPhone'],
                      style: const TextStyle(
                        color: AppColors.whiteColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildServiceList() {
    final bookingServices = _bookingDetail?['bookingServices'] as List? ?? [];

    if (bookingServices.isEmpty) {
      return [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('No services added yet'),
          ),
        ),
      ];
    }

    return bookingServices.map((bookingService) {
      final service = bookingService['service'];
      final bookingServiceId = bookingService['id'];
      final priceEdit = _priceEdits[bookingServiceId];
      final originalPrice = (service['price'] as num).toDouble();
      final currentPrice = priceEdit?.currentPrice ?? originalPrice;
      final hasNoteOrPriceChange =
          priceEdit != null &&
          (priceEdit.note.isNotEmpty ||
              priceEdit.currentPrice != priceEdit.originalPrice);

      // ⭐ THÊM STAFF STATUS
      final staffStatus = bookingService['staffStatus'] as String?;

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: ListTile(
          leading:
              service['imageUrl'] != null
                  ? CircleAvatar(
                    backgroundImage: NetworkImage(service['imageUrl']),
                  )
                  : const CircleAvatar(child: Icon(Icons.spa)),
          title: Row(
            children: [
              Expanded(child: Text(service['name'] ?? 'Unknown Service')),
              // ⭐ HIỂN THỊ STAFF STATUS BADGE
              if (staffStatus != null && staffStatus == 'COMPLETED')
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStaffStatusColor(staffStatus),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    staffStatus.replaceAll('_', ' '),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentPrice > 0 && currentPrice > originalPrice) ...[
                Text(
                  "Original: \$${originalPrice.toStringAsFixed(2)}",
                  style: const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  "Current: \$${currentPrice.toStringAsFixed(2)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ] else
                Text(
                  "\$${originalPrice.toStringAsFixed(2)}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (bookingService['staff'] != null)
                Text("Staff: ${bookingService['staff']['fullName']}"),
              if (hasNoteOrPriceChange && priceEdit!.note.isNotEmpty)
                Text(
                  "Note: ${priceEdit.note}",
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.blue,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_canAddServices &&
                  priceEdit != null &&
                  staffStatus == 'IN_PROGRESS')
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showPriceEditDialogForService(priceEdit),
                ),
              if (_canAddServices && staffStatus == 'ASSIGNED')
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeServiceFromBooking(bookingServiceId),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPaymentForm() {
    double totalPrice = 0.0;

    for (var priceEdit in _priceEdits.values) {
      double effectivePrice =
      priceEdit.currentPrice > priceEdit.originalPrice
          ? priceEdit.currentPrice
          : priceEdit.originalPrice;
      totalPrice += effectivePrice;
    }

    double grandTotal = totalPrice + _tipAmount;

    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.70, // 👈 chỉ chiếm 80% màn hình
        ),
        child: SingleChildScrollView(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Payment Confirmation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // 🟦 List dịch vụ — không còn height cứng 400
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: screenHeight * 0.25, // auto-fit
                    ),
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        controller: _scrollController,
                        itemCount: _priceEdits.length,
                        itemBuilder: (context, index) {
                          final priceEdit = _priceEdits.values.elementAt(index);
                          final bookingService =
                          (_bookingDetail?['bookingServices'] as List)[index];
                          final service = bookingService['service'];

                          final double current = priceEdit.currentPrice;
                          final double original = priceEdit.originalPrice;
                          final double displayPrice =
                          current > original ? current : original;

                          return ListTile(
                            title: Text(service['name'] ?? 'Unknown Service'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (current > original) ...[
                                  Text(
                                    "Original: \$${original.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  if (priceEdit.note.isNotEmpty)
                                    Text(
                                      "Note: ${priceEdit.note}",
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 10,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ] else ...[
                                  Text(
                                    "\$${original.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  if (priceEdit.note.isNotEmpty)
                                    Text(
                                      "Note: ${priceEdit.note}",
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 10,
                                        color: Colors.blue,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                            trailing: Text(
                              "\$${displayPrice.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: current > original
                                    ? Colors.green
                                    : Colors.black,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const Divider(),
                  ListTile(
                    title: const Text("Subtotal"),
                    trailing: Text("\$${totalPrice.toStringAsFixed(2)}"),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text("Total"),
                    trailing: Text("\$${grandTotal.toStringAsFixed(2)}"),
                    titleTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() => _showPaymentForm = false);
                        },
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: _completeBooking,
                        child: const Text("Confirm Payment"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSection(BuildContext context) {
    final status = _bookingDetail?['status'] ?? 'UNKNOWN';
    final isCompleted =
        status == 'PAID' || status == 'WAITING_PAYMENT' || status == 'CANCELED';

    if (isCompleted) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.whiteColor,
          boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black12)],
        ),
        child: _buildBottomButtons(status),
      ),
    );
  }

  Widget _buildBottomButtons(String status) {
    final hasPermissionToModify =
        _bookingDetail?['hasPermissionToModify'] ?? false;

    // ⭐ CHỈ HIỂN THỊ NÚT KHI CÓ QUYỀN
    if (!hasPermissionToModify) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bạn chỉ có quyền xem thông tin. Thợ khác đang xử lý booking này.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'REQUEST_MORE_STAFF') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.purple),
        ),
        child: Row(
          children: const [
            Icon(Icons.hourglass_empty, color: Colors.purple),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Waiting for receptionist to assign new staff...',
                style: TextStyle(
                  color: Colors.purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ⭐ CHECKED_IN STATUS
    if (status == 'CHECKED_IN') {
      if (!_canStartBooking) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Another staff is now responsible for this booking',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return ElevatedButton(
        onPressed: _isStarting ? null : _startBooking,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
        ),
        child:
            _isStarting
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Text('Start Booking', style: TextStyle(fontSize: 14)),
      );
    }

    // ⭐ IN_PROGRESS STATUS
    if (status == 'IN_PROGRESS') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_isAddingService || _isLoadingServices)
                          ? null
                          : _showServiceSelectionDialog,
                  child:
                      _isAddingService || _isLoadingServices
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 1),
                          )
                          : Text(
                            _availableServices.isEmpty
                                ? "No Services"
                                : "Add Service",
                          ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      (_isAddingService || _isLoadingServices)
                          ? null
                          : _showQuickAddForm,
                  child: const Text("Quick Add"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isRequestingMoreStaff ? null : _requestMoreStaff,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child:
                      _isRequestingMoreStaff
                          ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 1,
                              color: Colors.white,
                            ),
                          )
                          : const Text("Request More Staff"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _showPaymentForm
                          ? null
                          : () {
                            setState(() {
                              _showPaymentForm = true;
                            });
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text("Complete"),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'BOOKED':
        return Colors.orange;
      case 'CHECKED_IN':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'REQUEST_MORE_STAFF':
        return Colors.purple;
      case 'WAITING_PAYMENT':
        return Colors.purple;
      case 'PAID':
        return Colors.teal;
      case 'CANCELED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ⭐ THÊM METHOD ĐỂ LẤY MÀU CHO STAFF STATUS
  Color _getStaffStatusColor(String status) {
    switch (status) {
      case 'ASSIGNED':
        return Colors.blue;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.teal;
      case 'WAITING_NEXT_STAFF':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _showSuccessSnackBar(String message, {bool popAfter = false}) {
    _showCustomSnackBar(success: true, message: message, popAfter: popAfter);
  }

  void _showErrorSnackBar(String message) {
    _showCustomSnackBar(success: false, message: message, popAfter: false);
  }

  void _showCustomSnackBar({
    required bool success,
    required String message,
    required bool popAfter,
  }) {
    final overlay = OverlayEntry(
      builder:
          (context) => Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.4)),
              ),
              Positioned(
                top: 80,
                left: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.porcelainColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          success ? Icons.check_circle : Icons.error,
                          color: success ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );

    Overlay.of(context).insert(overlay);

    Future.delayed(const Duration(seconds: 2), () {
      overlay.remove();
      if (success && popAfter && mounted) {
        Navigator.pop(context);
      }
    });
  }
}
