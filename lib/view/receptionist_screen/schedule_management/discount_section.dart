import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../task_model.dart';

class DiscountSection extends StatelessWidget {
  final Task task;
  final double amountBeforeDiscount;
  final TextEditingController discountCodeController;
  final bool isApplyingDiscount;
  final Map<String, dynamic>? appliedDiscount;
  final double discountAmount;
  final double amountAfterDiscount;
  final List<Map<String, dynamic>> availableDiscounts;
  final bool isLoadingDiscounts;
  final VoidCallback onApplyDiscount;
  final VoidCallback onRemoveDiscount;

  const DiscountSection({
    super.key,
    required this.task,
    required this.amountBeforeDiscount,
    required this.discountCodeController,
    required this.isApplyingDiscount,
    required this.appliedDiscount,
    required this.discountAmount,
    required this.amountAfterDiscount,
    required this.availableDiscounts,
    required this.isLoadingDiscounts,
    required this.onApplyDiscount,
    required this.onRemoveDiscount,
  });

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildAvailableDiscountsList() {
    return Column(
      children: availableDiscounts.map((discount) {
        final code = discount['code'] as String? ?? '';
        final discountType = discount['discountType'] as String? ?? 'FIXED_AMOUNT';
        final discountValue = (discount['discountValue'] as num?)?.toDouble() ?? 0.0;
        final description = discount['description'] as String? ?? '';
        final minOrderAmount = (discount['minOrderAmount'] as num?)?.toDouble() ?? 0.0;
        final validUntil = discount['validUntil'] as String?;

        final bool meetsMinimum = amountBeforeDiscount >= minOrderAmount;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: meetsMinimum ? () {
                discountCodeController.text = code;
                onApplyDiscount();
              } : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: meetsMinimum
                        ? [Colors.orange.withOpacity(0.1), Colors.orange.withOpacity(0.05)]
                        : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: meetsMinimum
                        ? Colors.orange.withOpacity(0.4)
                        : Colors.grey.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: meetsMinimum ? Colors.orange : Colors.grey,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: (meetsMinimum ? Colors.orange : Colors.grey).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                code,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: meetsMinimum ? Colors.black87 : Colors.grey,
                                ),
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: meetsMinimum ? Colors.grey[700] : Colors.grey[500],
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: meetsMinimum ? Colors.orange : Colors.grey,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: (meetsMinimum ? Colors.orange : Colors.grey).withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            discountType == 'PERCENTAGE'
                                ? '${discountValue.toInt()}%\nOFF'
                                : '\$${discountValue.toStringAsFixed(0)}\nOFF',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (minOrderAmount > 0)
                            Row(
                              children: [
                                Icon(
                                  meetsMinimum ? Icons.check_circle : Icons.info_outline,
                                  size: 14,
                                  color: meetsMinimum ? Colors.green : Colors.orange[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Min: ${_formatCurrency(minOrderAmount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: meetsMinimum ? Colors.green : Colors.orange[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),

                          if (validUntil != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Valid until ${_formatDate(validUntil)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),

                    if (!meetsMinimum && minOrderAmount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.orange[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Add ${_formatCurrency(minOrderAmount - amountBeforeDiscount)} more to use this code',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[800],
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
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDiscountInputField() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: discountCodeController,
            decoration: InputDecoration(
              hintText: 'Enter code (e.g., SUMMER2025)',
              hintStyle: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
              prefixIcon: const Icon(Icons.discount, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.orange, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            textCapitalization: TextCapitalization.characters,
            enabled: !isApplyingDiscount,
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isApplyingDiscount ? null : onApplyDiscount,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 2,
          ),
          child: isApplyingDiscount
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text(
            'Apply',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppliedDiscountCard() {
    final discountType = appliedDiscount!['discountType'] as String? ?? 'FIXED';
    final code = appliedDiscount!['code'] as String? ?? '';

    dynamic discountValueRaw = appliedDiscount!['discountValue'];
    String discountDisplay = '';

    if (discountValueRaw is num) {
      discountDisplay = discountType == 'PERCENTAGE'
          ? '${discountValueRaw}% off'
          : '${_formatCurrency(discountValueRaw.toDouble())} off';
    } else if (discountValueRaw is String) {
      discountDisplay = '$discountValueRaw off';
    } else {
      discountDisplay = 'Discount applied';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discount Applied: $code',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      discountDisplay,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemoveDiscount,
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Remove discount',
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discount Amount:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                '- ${_formatCurrency(discountAmount)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'New Total:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formatCurrency(amountAfterDiscount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_offer,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Discount Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (appliedDiscount == null) ...[
            if (isLoadingDiscounts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (availableDiscounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No discount codes available for you at this time',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
                const Text(
                  'Available Discounts - Tap to apply',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAvailableDiscountsList(),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Enter code manually',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDiscountInputField(),
              ],
          ] else
            _buildAppliedDiscountCard(),
        ],
      ),
    );
  }
}