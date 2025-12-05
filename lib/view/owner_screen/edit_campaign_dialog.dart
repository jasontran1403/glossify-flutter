// Full updated: lib/edit_campaign_dialog.dart
// (Removed all usageLimit code; added user selection logic)

import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:intl/intl.dart';

class EditCampaignDialog extends StatefulWidget {
  final Map<String, dynamic>? campaign;

  const EditCampaignDialog({super.key, this.campaign});

  @override
  State<EditCampaignDialog> createState() => _EditCampaignDialogState();
}

class _EditCampaignDialogState extends State<EditCampaignDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _codeController;
  late TextEditingController _descriptionController;
  late TextEditingController _discountValueController;
  late TextEditingController _maxDiscountController;
  late TextEditingController _minOrderController;

  String _discountType = 'PERCENTAGE';
  bool _active = true;
  DateTime? _validFrom;
  DateTime? _validUntil;
  bool _isLoading = false;
  bool _isCreate = true;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    _isCreate = widget.campaign == null;
    _codeController = TextEditingController();
    _descriptionController = TextEditingController();
    _discountValueController = TextEditingController();
    _maxDiscountController = TextEditingController(text: '0');
    _minOrderController = TextEditingController(text: '0');

    if (!_isCreate) {
      final campaign = widget.campaign!;
      _codeController.text = campaign['code'] ?? '';
      _descriptionController.text = campaign['description'] ?? '';
      _discountValueController.text = (campaign['discountValue'] ?? 0.0).toString();
      _maxDiscountController.text = (campaign['maxDiscountAmount'] ?? 0.0).toString();
      _minOrderController.text = (campaign['minOrderAmount'] ?? 0.0).toString();
      _discountType = campaign['discountType'] ?? 'PERCENTAGE';
      _active = campaign['active'] ?? true;
      if (campaign['validFrom'] != null) {
        _validFrom = DateTime.parse(campaign['validFrom']);
      }
      if (campaign['validUntil'] != null) {
        _validUntil = DateTime.parse(campaign['validUntil']);
      }
      _fetchAllowedUsers(campaign['id']);
    }
    _fetchAllUsers();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _discountValueController.dispose();
    _maxDiscountController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllUsers() async {
    try {
      final response = await ApiService.getAllCustomerUsers();
      if (mounted) {
        setState(() {
          _allUsers = List<Map<String, dynamic>>.from(response.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _fetchAllowedUsers(int id) async {
    try {
      final response = await ApiService.getAllowedUsers(id);
      if (mounted) {
        setState(() {
          _selectedUsers = List<Map<String, dynamic>>.from(response.data ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading selected users: $e')),
        );
      }
    }
  }

  Future<void> _pickDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_validFrom ?? DateTime.now())
          : (_validUntil ?? DateTime.now().add(const Duration(days: 30))),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _validFrom = picked;
        } else {
          _validUntil = picked;
        }
      });
    }
  }

  Future<void> _showUserSelectionForCreate() async {
    final currentSelectedIds = _selectedUsers.map((u) => u['userId'] as int).toList();
    final availableUsers = _allUsers.where((u) => !currentSelectedIds.contains(u['userId'])).toList();
    if (availableUsers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users available to select')),
        );
      }
      return;
    }

    Set<int> checkedIds = {};
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Users to Assign'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: availableUsers.length,
              itemBuilder: (context, index) {
                final user = availableUsers[index];
                final userId = user['userId'] as int;
                final fullName = user['fullName'] ?? user['email'] ?? 'Unknown User';
                return CheckboxListTile(
                  title: Text(fullName),
                  subtitle: Text(user['email'] ?? ''),
                  value: checkedIds.contains(userId),
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        checkedIds.add(userId);
                      } else {
                        checkedIds.remove(userId);
                      }
                    });
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  for (int id in checkedIds) {
                    final user = _allUsers.firstWhere((u) => u['userId'] == id);
                    _selectedUsers.add(user);
                  }
                });
              },
              child: Text('Add ${checkedIds.length} Users'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageUsers(bool isAdd) async {
    if (_isCreate) return; // Only for edit

    final usersToShow = isAdd
        ? _allUsers.where((u) => !_selectedUsers.any((s) => s['userId'] == u['userId'])).toList()
        : _selectedUsers;
    if (usersToShow.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAdd ? 'No users to add' : 'No users to remove')),
        );
      }
      return;
    }

    Set<int> checkedIds = {};
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isAdd ? 'Select Users to Add' : 'Select Users to Remove'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: usersToShow.length,
              itemBuilder: (context, index) {
                final user = usersToShow[index];
                final userId = user['userId'] as int;
                final fullName = user['fullName'] ?? user['email'] ?? 'Unknown User';
                return CheckboxListTile(
                  title: Text(fullName),
                  subtitle: Text(user['email'] ?? ''),
                  value: checkedIds.contains(userId),
                  onChanged: (bool? value) {
                    setDialogState(() {
                      if (value == true) {
                        checkedIds.add(userId);
                      } else {
                        checkedIds.remove(userId);
                      }
                    });
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
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performUserAction(isAdd, checkedIds.toList());
              },
              child: Text(isAdd ? 'Add ${checkedIds.length} Users' : 'Remove ${checkedIds.length} Users'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUserAction(bool isAdd, List<int> userIds) async {
    if (userIds.isEmpty || _isCreate || widget.campaign == null) return;

    setState(() => _isLoading = true);
    try {
      if (isAdd) {
        await ApiService.addUsersToDiscount(widget.campaign!['id'], userIds);
      } else {
        await ApiService.removeUsersFromDiscount(widget.campaign!['id'], userIds);
      }
      await _fetchAllowedUsers(widget.campaign!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAdd ? 'Users added successfully' : 'Users removed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error managing users: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final code = _codeController.text.trim().toUpperCase(); // Trim and uppercase early
      if (code.length < 3 || code.length > 50) { // Double-check (redundant but safe)
        throw Exception('Code must be between 3 and 50 characters');
      }

      Map<String, dynamic> data = {
        'discountType': _discountType,
        'discountValue': double.parse(_discountValueController.text),
        'maxDiscountAmount': double.parse(_maxDiscountController.text),
        'minOrderAmount': double.parse(_minOrderController.text),
        'active': _active,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      };

      if (_validFrom != null) {
        data['validFrom'] = _validFrom!.toIso8601String();
      }
      if (_validUntil != null) {
        data['validUntil'] = _validUntil!.toIso8601String();
      }
      // No 'usageLimit' - always unlimited
      // No 'code' for updates - only for create

      if (_isCreate) {
        data['code'] = code; // Include code only for create
        if (_selectedUsers.isNotEmpty) {
          data['userIds'] = _selectedUsers.map((u) => u['userId'] as int).toList();
        }
        await ApiService.createDiscountCode(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign created successfully')),
          );
        }
      } else {
        // For update: Do NOT include 'code' or 'userIds'
        await ApiService.updateDiscountCode(widget.campaign!['id'], data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Campaign updated successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        String errorMsg = 'Error: $e';
        // Handle token error specifically
        if (e.toString().contains('904') || e.toString().contains('Token hết hạn')) {
          errorMsg = 'Session expired. Please log in again.';
          // Optional: Navigate to login
          // Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = !_isCreate;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit : Icons.add,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Campaign' : 'Create Campaign',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Code
                      TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: 'Code *',
                          hintText: 'e.g., SUMMER2025',
                          border: OutlineInputBorder(),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a code';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Discount Type
                      DropdownButtonFormField<String>(
                        value: _discountType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage')),
                          DropdownMenuItem(value: 'FIXED_AMOUNT', child: Text('Fixed Amount')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _discountType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Discount Value
                      TextFormField(
                        controller: _discountValueController,
                        decoration: InputDecoration(
                          labelText: _discountType == 'PERCENTAGE'
                              ? 'Discount Percentage *'
                              : 'Discount Amount *',
                          hintText: _discountType == 'PERCENTAGE' ? '20' : '10.00',
                          prefixText: _discountType == 'FIXED_AMOUNT' ? '\$ ' : null,
                          suffixText: _discountType == 'PERCENTAGE' ? '%' : null,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter discount value';
                          }
                          final number = double.tryParse(value);
                          if (number == null || number <= 0) {
                            return 'Please enter a valid number';
                          }
                          if (_discountType == 'PERCENTAGE' && number > 100) {
                            return 'Percentage cannot exceed 100';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Max Discount (for percentage only)
                      if (_discountType == 'PERCENTAGE') ...[
                        TextFormField(
                          controller: _maxDiscountController,
                          decoration: const InputDecoration(
                            labelText: 'Max Discount Amount',
                            hintText: '0 = No limit',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Min Order Amount
                      TextFormField(
                        controller: _minOrderController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Order Amount',
                          hintText: '0',
                          prefixText: '\$ ',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),

                      // Valid From
                      ListTile(
                        title: const Text('Valid From'),
                        subtitle: Text(
                          _validFrom != null
                              ? DateFormat('MMM dd, yyyy').format(_validFrom!)
                              : 'Not set',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _pickDate(context, true),
                              icon: const Icon(Icons.calendar_today),
                            ),
                            if (_validFrom != null)
                              IconButton(
                                onPressed: () => setState(() => _validFrom = null),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),

                      // Valid Until
                      ListTile(
                        title: const Text('Valid Until'),
                        subtitle: Text(
                          _validUntil != null
                              ? DateFormat('MMM dd, yyyy').format(_validUntil!)
                              : 'Not set',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _pickDate(context, false),
                              icon: const Icon(Icons.calendar_today),
                            ),
                            if (_validUntil != null)
                              IconButton(
                                onPressed: () => setState(() => _validUntil = null),
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe your campaign',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Active status
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Enable/disable this campaign'),
                        value: _active,
                        onChanged: (value) {
                          setState(() {
                            _active = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),

                      const SizedBox(height: 24),

                      // Assigned Users Section
                      const Text(
                        'Assigned Users (Role: USER)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      if (_isCreate)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _allUsers.isEmpty ? null : _showUserSelectionForCreate,
                              icon: const Icon(Icons.add),
                              label: Text('Select Users (${_selectedUsers.length} selected)'),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedUsers.isNotEmpty)
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  itemCount: _selectedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _selectedUsers[index];
                                    final fullName = user['fullName'] ?? user['email'] ?? 'Unknown';
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person, size: 20),
                                      title: Text(fullName, style: const TextStyle(fontSize: 14)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.red),
                                        onPressed: () => setState(() => _selectedUsers.remove(user)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_selectedUsers.length} users assigned'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _manageUsers(true),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add Users'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_selectedUsers.isNotEmpty)
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  itemCount: _selectedUsers.length,
                                  itemBuilder: (context, index) {
                                    final user = _selectedUsers[index];
                                    final fullName = user['fullName'] ?? user['email'] ?? 'Unknown';
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(Icons.person, size: 20),
                                      title: Text(fullName, style: const TextStyle(fontSize: 14)),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => _performUserAction(false, [user['userId'] as int]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isEdit ? 'Update' : 'Create'),
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
}