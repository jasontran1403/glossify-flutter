import 'package:flutter/material.dart';
import 'package:hair_sallon/api/api_service.dart';
import 'package:image_picker/image_picker.dart';

import '../../../api/store_info_detail_dto.dart';

class StoreTab extends StatefulWidget {
  const StoreTab({super.key});

  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  bool _isLoading = true;
  StoreInfoDetailDTO? _storeInfo;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchStoreInfo();
  }

  Future<void> _fetchStoreInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.getMyStoreInfo();

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        setState(() {
          _storeInfo = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== EDIT STORE INFO ==========
  void _showEditStoreDialog() {
    if (_storeInfo == null) return;

    final TextEditingController nameController = TextEditingController(text: _storeInfo!.name);
    final TextEditingController locationController = TextEditingController(text: _storeInfo!.location);
    final TextEditingController feeController = TextEditingController(text: _storeInfo!.fee.toString());
    final TextEditingController ownerRateController =
    TextEditingController(text: _storeInfo!.ownerRate.toString());
    final TextEditingController lonController =
    TextEditingController(text: _storeInfo!.lon?.toString() ?? '');
    final TextEditingController latController =
    TextEditingController(text: _storeInfo!.lat?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Store Information'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeController,
                decoration: const InputDecoration(
                  labelText: 'Fee',
                  border: OutlineInputBorder(),
                  prefixText: '\$ ',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ownerRateController,
                decoration: const InputDecoration(
                  labelText: 'Owner Rate (0-100)',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: lonController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || locationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill required fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final ownerRate = double.tryParse(ownerRateController.text);
              if (ownerRate == null || ownerRate < 0 || ownerRate > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Owner rate must be between 0 and 100'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _updateStoreInfo(
                nameController.text,
                locationController.text,
                double.tryParse(feeController.text) ?? 0,
                ownerRate,
                lonController.text.isEmpty ? null : double.tryParse(lonController.text),
                latController.text.isEmpty ? null : double.tryParse(latController.text),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStoreInfo(
      String name,
      String location,
      double fee,
      double ownerRate,
      double? lon,
      double? lat,
      ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.updateStoreInfo(
        name: name,
        location: location,
        fee: fee,
        ownerRate: ownerRate,
        lon: lon,
        lat: lat,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStoreInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store information updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ========== UPLOAD AVATAR ==========
  Future<void> _uploadAvatar() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.uploadStoreAvatar(
        imagePath: image.path,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.isSuccess) {
        await _fetchStoreInfo();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store avatar updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchStoreInfo,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _storeInfo == null
          ? const Center(child: Text('No store information available'))
          : SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Store Avatar
            GestureDetector(
              onTap: _uploadAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _storeInfo!.avt.isNotEmpty
                        ? NetworkImage(_storeInfo!.avt)
                        : null,
                    backgroundColor: Colors.grey.shade200,
                    child: _storeInfo!.avt.isEmpty
                        ? const Icon(Icons.store, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Store Name
            Text(
              _storeInfo!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Location
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _storeInfo!.location,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Store Information Cards
            _buildInfoCard(
              'Store ID',
              '#${_storeInfo!.id}',
              Icons.tag,
              Colors.blue,
            ),

            _buildInfoCard(
              'Fee',
              '\$${_storeInfo!.fee.toStringAsFixed(2)}',
              Icons.attach_money,
              Colors.green,
            ),

            _buildInfoCard(
              'Owner Rate',
              '${_storeInfo!.ownerRate.toStringAsFixed(1)}%',
              Icons.percent,
              Colors.orange,
            ),

            if (_storeInfo!.lon != null && _storeInfo!.lat != null)
              _buildInfoCard(
                'Coordinates',
                'Lat: ${_storeInfo!.lat!.toStringAsFixed(6)}\nLon: ${_storeInfo!.lon!.toStringAsFixed(6)}',
                Icons.map,
                Colors.purple,
              ),

            const SizedBox(height: 32),

            // Edit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEditStoreDialog,
                icon: const Icon(Icons.edit),
                label: const Text('Edit Store Information'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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
