import 'package:flutter/material.dart';

import 'giftcard_model.dart';

class GiftcardDetailSheet extends StatefulWidget {
  final Giftcard giftcard;
  final Function(Giftcard) onSave;

  const GiftcardDetailSheet({
    super.key,
    required this.giftcard,
    required this.onSave,
  });

  @override
  State<GiftcardDetailSheet> createState() => _GiftcardDetailSheetState();
}

class _GiftcardDetailSheetState extends State<GiftcardDetailSheet> {
  late Giftcard _editedGiftcard;
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _editedGiftcard = widget.giftcard.copyWith();
    _ownerController.text = _editedGiftcard.owner;
    _valueController.text = _editedGiftcard.remainingValue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  String _formatCurrency(double value) {
    final parts = value.toStringAsFixed(4).split('.');
    return '${parts[0]}.${parts[1].substring(0, 2)}';
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      // Cập nhật remaining value từ input
      final newValue = double.tryParse(_valueController.text) ?? 0.0;
      _editedGiftcard = _editedGiftcard.copyWith(
        owner: _ownerController.text,
        remainingValue: newValue,
      );

      widget.onSave(_editedGiftcard);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gift Card Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            // Code (readonly)
            TextFormField(
              initialValue: '#${_editedGiftcard.code}',
              decoration: InputDecoration(
                labelText: 'Gift Card Code',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[300], // xám nhạt
                enabledBorder: OutlineInputBorder( // viền khi không focus
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder( // viền khi focus
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            // Owner
            TextFormField(
              initialValue: '#${_editedGiftcard.code}',
              decoration: InputDecoration(
                labelText: 'Gift Card Code',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[300], // xám nhạt hơn
              ),
              readOnly: true,   // chặn nhập liệu
              enabled: false,   // disabled luôn (text sẽ nhạt hơn, giống field khóa)
            ),
            const SizedBox(height: 16),
            // Remaining Value
            TextFormField(
              controller: _valueController,
              decoration: const InputDecoration(
                labelText: 'Remaining Value (\$)',
                border: OutlineInputBorder(),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter value';
                }
                final numericValue = double.tryParse(value);
                if (numericValue == null) {
                  return 'Please enter a valid number';
                }
                if (numericValue < 0) {
                  return 'Value must be greater than or equal to 0';
                }
                if (numericValue > 1000000) {
                  return 'Value cannot exceed 1,000,000';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Status
            const Text(
              'Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: GiftcardStatus.values.map((status) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(status.name),
                      selected: _editedGiftcard.status == status,
                      selectedColor: status.color.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: _editedGiftcard.status == status
                            ? status.color
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _editedGiftcard = _editedGiftcard.copyWith(status: status);
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text(
                      'Save',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}