import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../api/api_service.dart';
import '../../../api/promotion_request_models.dart';

class PromoteUserScreen extends StatefulWidget {
  final VoidCallback onPromoteSuccess;

  const PromoteUserScreen({super.key, required this.onPromoteSuccess});

  @override
  State<PromoteUserScreen> createState() => _PromoteUserScreenState();
}

class _PromoteUserScreenState extends State<PromoteUserScreen> {
  // Data
  List<PromotionRequestResponse> _allRequests = [];
  List<PromotionRequestResponse> _filteredRequests = [];

  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  bool _hasMore = true;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Scroll
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================

  Future<void> _loadData({bool isRefresh = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (isRefresh) {
        _isLoading = true;
        _currentPage = 0;
        _hasMore = true;
        _allRequests.clear();
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      // Get pending requests from API
      final response = await ApiService.getPendingPromotionRequests();

      if (response.isSuccess && response.data != null) {
        setState(() {
          if (isRefresh) {
            _allRequests = response.data!;
          } else {
            _allRequests.addAll(response.data!);
          }
          _filterRequests();

          // Check if has more (for demo, since we get all at once)
          _hasMore = false;
        });
      } else {
        _showError(response.message);
      }
    } catch (e) {
      _showError('Error loading requests: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _filterRequests() {
    if (_searchQuery.isEmpty) {
      _filteredRequests = List.from(_allRequests);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredRequests = _allRequests.where((request) {
        final name = request.user.fullName.toLowerCase();
        final phone = request.user.phoneNumber?.toLowerCase() ?? '';
        return name.contains(query) || phone.contains(query);
      }).toList();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadData();
    }
  }

  Future<void> _onRefresh() async {
    await _loadData(isRefresh: true);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _filterRequests();
    });
  }

  // ============================================================================
  // ACTIONS
  // ============================================================================

  Future<void> _approveRequest(PromotionRequestResponse request) async {
    // Show confirmation dialog
    final confirmed = await _showConfirmDialog(
      title: 'Approve Request',
      message: 'Approve ${request.user.fullName} to become STAFF?',
      confirmText: 'Approve',
      isApprove: true,
    );

    if (!confirmed) return;

    // Show loading
    _showLoadingDialog();

    try {
      final response = await ApiService.approvePromotionRequest(
        requestId: request.id,
      );

      // Hide loading
      Navigator.of(context).pop();

      if (response.isSuccess) {
        _showSuccessSnackBar('${request.user.fullName} has been promoted to STAFF!');

        // Refresh list
        await _loadData(isRefresh: true);

        // Callback
        widget.onPromoteSuccess();
      } else {
        _showError(response.message);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error approving request: $e');
    }
  }

  Future<void> _rejectRequest(PromotionRequestResponse request) async {
    // Show confirmation dialog with reason input
    final reason = await _showRejectDialog(request.user.fullName);
    if (reason == null) return; // User cancelled

    // Show loading
    _showLoadingDialog();

    try {
      final response = await ApiService.rejectPromotionRequest(
        requestId: request.id,
        adminNotes: reason.isEmpty ? null : reason,
      );

      // Hide loading
      Navigator.of(context).pop();

      if (response.isSuccess) {
        _showSuccessSnackBar('Request from ${request.user.fullName} has been rejected');

        // Refresh list
        await _loadData(isRefresh: true);
      } else {
        _showError(response.message);
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Error rejecting request: $e');
    }
  }

  // ============================================================================
  // DIALOGS
  // ============================================================================

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isApprove,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isApprove ? Colors.green : Colors.red,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ?? false;
  }

  // ✅ FIXED: No overflow when keyboard shows
  Future<String?> _showRejectDialog(String userName) async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        // ✅ Wrap in SingleChildScrollView to prevent overflow
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reject request from $userName?'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Enter reason for rejection',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true, // Auto show keyboard
              ),
            ],
          ),
        ),
        // ✅ Add padding to prevent dialog touching edges
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================================
  // UI BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotion Requests'),
        backgroundColor: Colors.orange,
        actions: [
          // Badge showing count
          if (_filteredRequests.isNotEmpty)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredRequests.length}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // List
          Expanded(
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by name or phone number',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: _filteredRequests.isEmpty
          ? _buildEmptyStateWithScroll()
          : _buildListView(),
    );
  }

  Widget _buildEmptyStateWithScroll() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height - 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No promotion requests'
                      : 'No results found',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isEmpty
                      ? 'Pull down to refresh'
                      : 'Try a different search term',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredRequests.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _filteredRequests.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final request = _filteredRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(PromotionRequestResponse request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main Row: Avatar + Info + Actions
            Row(
              children: [
                // Left: Avatar + Name + Phone
                Expanded(
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.orange[100],
                        backgroundImage: request.user.avatar != null
                            ? NetworkImage(request.user.avatar!)
                            : null,
                        child: request.user.avatar == null
                            ? Text(
                          request.user.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        )
                            : null,
                      ),
                      const SizedBox(width: 12),

                      // Name + Phone
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            Text(
                              request.user.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Phone
                            if (request.user.phoneNumber != null)
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    request.user.phoneNumber!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right: Action Buttons
                Column(
                  children: [
                    // Approve Button
                    ElevatedButton.icon(
                      onPressed: () => _approveRequest(request),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reject Button
                    OutlinedButton.icon(
                      onPressed: () => _rejectRequest(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Notes (if any)
            if (request.notes != null && request.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Request Date
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  'Requested: ${_formatDate(request.requestDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}