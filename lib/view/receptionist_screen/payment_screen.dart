import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/api/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final int bookingId;
  final String customerName;
  final double totalAmount;
  final String discountCode;
  final double discountAmount;
  final double amountAfterDiscount;

  const PaymentScreen({
    super.key,
    required this.bookingId,
    required this.customerName,
    required this.totalAmount,
    required this.discountCode,
    required this.discountAmount,
    required this.amountAfterDiscount,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  double _tipAmount = 0.0;
  final TextEditingController _customTipController = TextEditingController();
  String _selectedTipOption = '';

  @override
  void dispose() {
    _customTipController.dispose();
    super.dispose();
  }

  void _selectTipOption(String option, double percentage) {
    setState(() {
      _selectedTipOption = option;
      _tipAmount = widget.amountAfterDiscount * percentage;
      _customTipController.clear();
    });
  }

  void _setCustomTip(String value) {
    setState(() {
      _selectedTipOption = 'custom';
      _tipAmount = double.tryParse(value) ?? 0.0;
    });
  }

  double get _finalTotal {
    return widget.amountAfterDiscount + _tipAmount;
  }

  Future<void> _processPayment(int paymentMethod) async {
    try {
      await ApiService.completePayment(
        bookingId: widget.bookingId,
        paymentMethod: paymentMethod,
        tips: _tipAmount,
        giftCardUsages: [],
        giftCardAmount: 0.0,
        cashPaidAmount: paymentMethod == 1 ? widget.amountAfterDiscount : 0.0,
        creditAmount: paymentMethod == 2 ? widget.amountAfterDiscount : 0.0,
        discountCode: widget.discountCode,
      );

      // Payment successful - navigate back to welcome screen
      Navigator.popUntil(context, (route) => route.isFirst);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildPaymentMethodCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentConfirmation(int paymentMethod, String methodName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.payment, color: Colors.blue),
            SizedBox(width: 12),
            Text('Confirm $methodName Payment'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${widget.customerName}'),
            SizedBox(height: 8),
            Text('Amount: \$${widget.amountAfterDiscount.toStringAsFixed(2)}'),
            if (_tipAmount > 0) ...[
              SizedBox(height: 8),
              Text('Tip: \$${_tipAmount.toStringAsFixed(2)}'),
            ],
            SizedBox(height: 8),
            Text('Total: \$${_finalTotal.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayment(paymentMethod);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
            child: const Text('CONFIRM PAYMENT'),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow(String label, String value, {bool isBold = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.green : Colors.black,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isDiscount ? Colors.green : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTipButton(String label, double percentage) {
    final isSelected = _selectedTipOption == label;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTipOption(label, percentage),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer: ${widget.customerName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Booking ID: #${widget.bookingId}'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Amount Summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildAmountRow('Subtotal:', '\$${widget.totalAmount.toStringAsFixed(2)}'),
                    if (widget.discountAmount > 0) ...[
                      SizedBox(height: 8),
                      _buildAmountRow('Discount:', '-\$${widget.discountAmount.toStringAsFixed(2)}', isDiscount: true),
                    ],
                    SizedBox(height: 8),
                    _buildAmountRow(
                      'Amount Due:',
                      '\$${widget.amountAfterDiscount.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Tips Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Tip (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTipButton('10%', 0.10),
                        SizedBox(width: 8),
                        _buildTipButton('15%', 0.15),
                        SizedBox(width: 8),
                        _buildTipButton('20%', 0.20),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextField(
                      controller: _customTipController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                      decoration: InputDecoration(
                        labelText: 'Custom Tip Amount',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: _setCustomTip,
                    ),
                    if (_tipAmount > 0) ...[
                      SizedBox(height: 12),
                      _buildAmountRow(
                        'Tip Amount:',
                        '\$${_tipAmount.toStringAsFixed(2)}',
                        isBold: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Final Total
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL TO PAY:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    Text(
                      '\$${_finalTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // Payment Methods
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECT PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPaymentMethodCard(
                          icon: Icons.credit_card,
                          title: 'Credit Card',
                          subtitle: 'Pay with Visa, MasterCard, etc.',
                          color: Colors.blue,
                          onTap: () => _showPaymentConfirmation(2, 'Credit Card'),
                        ),
                        SizedBox(height: 12),
                        _buildPaymentMethodCard(
                          icon: Icons.attach_money,
                          title: 'Cash',
                          subtitle: 'Pay with cash',
                          color: Colors.green,
                          onTap: () => _showPaymentConfirmation(1, 'Cash'),
                        ),
                        SizedBox(height: 12),
                        _buildPaymentMethodCard(
                          icon: Icons.qr_code,
                          title: 'Gift Card',
                          subtitle: 'Use gift card balance',
                          color: Colors.purple,
                          onTap: () => _showPaymentConfirmation(3, 'Gift Card'),
                        ),
                      ],
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