// Full: lib/campaign_list_tab.dart
// (Unchanged, as per instructions - no updates needed here since user management is in dialog)

import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:intl/intl.dart';
import 'edit_campaign_dialog.dart';

class CampaignListTab extends StatefulWidget {
  const CampaignListTab({super.key});

  @override
  State<CampaignListTab> createState() => _CampaignListTabState();
}

class _CampaignListTabState extends State<CampaignListTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _campaigns = [];
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, inactive, expired

  @override
  void initState() {
    super.initState();
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getAllDiscountCodes();

      if (mounted) {
        setState(() {
          _campaigns = List<Map<String, dynamic>>.from(response.data ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading campaigns: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredCampaigns {
    return _campaigns.where((campaign) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final code = campaign['code']?.toString().toLowerCase() ?? '';
        final description = campaign['description']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();

        if (!code.contains(query) && !description.contains(query)) {
          return false;
        }
      }

      // Status filter
      if (_filterStatus != 'all') {
        final now = DateTime.now();
        final validFrom = campaign['validFrom'] != null
            ? DateTime.parse(campaign['validFrom'])
            : null;
        final validUntil = campaign['validUntil'] != null
            ? DateTime.parse(campaign['validUntil'])
            : null;
        final active = campaign['active'] ?? false;
        final usageLimit = campaign['usageLimit'];
        final usedCount = campaign['usedCount'] ?? 0;

        bool isExpired = false;
        if (validUntil != null && now.isAfter(validUntil)) {
          isExpired = true;
        }
        if (usageLimit != null && usedCount >= usageLimit) {
          isExpired = true;
        }

        if (_filterStatus == 'active' && (!active || isExpired)) {
          return false;
        }
        if (_filterStatus == 'inactive' && (active || isExpired)) {
          return false;
        }
        if (_filterStatus == 'expired' && !isExpired) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _deleteCampaign(int id, String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Are you sure you want to delete code "$code"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteDiscountCode(id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign deleted successfully')),
          );
          _fetchCampaigns();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting campaign: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActiveStatus(int id, bool currentStatus) async {
    try {
      await ApiService.toggleDiscountCodeStatus(id, !currentStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign ${!currentStatus ? 'activated' : 'deactivated'} successfully')),
        );
        _fetchCampaigns();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const EditCampaignDialog(),
    );

    if (result == true) {
      _fetchCampaigns();
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> campaign) async {
    final result = await showDialog(
      context: context,
      builder: (context) => EditCampaignDialog(campaign: campaign),
    );

    if (result == true) {
      _fetchCampaigns();
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _filterStatus == 'all',
            onSelected: (selected) {
              setState(() {
                _filterStatus = 'all';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Active'),
            selected: _filterStatus == 'active',
            onSelected: (selected) {
              setState(() {
                _filterStatus = 'active';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Inactive'),
            selected: _filterStatus == 'inactive',
            onSelected: (selected) {
              setState(() {
                _filterStatus = 'inactive';
              });
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Expired'),
            selected: _filterStatus == 'expired',
            onSelected: (selected) {
              setState(() {
                _filterStatus = 'expired';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignCard(Map<String, dynamic> campaign) {
    final code = campaign['code'] ?? '';
    final discountType = campaign['discountType'] ?? 'PERCENTAGE';
    final discountValue = campaign['discountValue'] ?? 0.0;
    final description = campaign['description'] ?? '';
    final active = campaign['active'] ?? false;
    final usedCount = campaign['usedCount'] ?? 0;
    final usageLimit = campaign['usageLimit'];
    final validUntil = campaign['validUntil'] != null
        ? DateTime.parse(campaign['validUntil'])
        : null;

    final now = DateTime.now();
    final isExpired = validUntil != null && now.isAfter(validUntil);
    final usageLimitReached = usageLimit != null && usedCount >= usageLimit;

    Color statusColor = Colors.green;
    String statusText = 'Active';
    if (!active) {
      statusColor = Colors.grey;
      statusText = 'Inactive';
    } else if (isExpired || usageLimitReached) {
      statusColor = Colors.red;
      statusText = 'Expired';
    }

    String discountText = discountType == 'PERCENTAGE'
        ? '$discountValue%'
        : '\$${discountValue.toStringAsFixed(2)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showEditDialog(campaign),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Discount badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      discountText,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),

              if (description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        usageLimit != null
                            ? '$usedCount / $usageLimit'
                            : '$usedCount / ∞',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (validUntil != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Valid Until',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(validUntil),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleActiveStatus(campaign['id'], active),
                      icon: Icon(
                        active ? Icons.visibility_off : Icons.visibility,
                        size: 18,
                      ),
                      label: Text(active ? 'Deactivate' : 'Activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: active ? Colors.orange : Colors.green,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _deleteCampaign(campaign['id'], code),
                    icon: const Icon(Icons.delete),
                    color: Colors.red,
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search campaigns...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Filter chips
          _buildFilterChips(),

          // Campaign list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCampaigns.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.discount, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No campaigns found',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchCampaigns,
              child: ListView.builder(
                itemCount: _filteredCampaigns.length,
                itemBuilder: (context, index) {
                  return _buildCampaignCard(_filteredCampaigns[index]);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('New Campaign'),
      ),
    );
  }
}