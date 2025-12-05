import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import 'package:sunmi_printer_plus/column_maker.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ReceiptScreen extends StatelessWidget {
  final String shopName;
  final String shopAddress;
  final String shopTel;
  final DateTime transactionDate;
  final List<Map<String, dynamic>> serviceItems;
  final double totalAmount;
  final double cashPaid;
  final double change;
  final String? discountCode;
  final double? discountAmount;
  final double? tipAmount;
  final String paymentMethod;
  final int bookingId;
  final String customerName;
  final String staffName;
  final DateTime appointmentDateTime;
  final DateTime appointmentEndDateTime;
  final double fee;

  const ReceiptScreen({
    super.key,
    required this.shopName,
    required this.shopAddress,
    required this.shopTel,
    required this.transactionDate,
    required this.serviceItems,
    required this.totalAmount,
    required this.cashPaid,
    required this.change,
    required this.paymentMethod,
    required this.bookingId,
    this.discountCode,
    this.discountAmount,
    this.tipAmount,
    required this.customerName,
    required this.staffName,
    required this.appointmentDateTime,
    required this.appointmentEndDateTime,
    required this.fee
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt #$bookingId'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ReceiptWidget(
              shopName: shopName,
              shopAddress: shopAddress,
              shopTel: shopTel,
              transactionDate: transactionDate,
              serviceItems: serviceItems,
              totalAmount: totalAmount,
              cashPaid: cashPaid,
              change: change,
              paymentMethod: paymentMethod,
              bookingId: bookingId,
              discountCode: discountCode,
              discountAmount: discountAmount,
              tipAmount: tipAmount,
              customerName: customerName,
              staffName: staffName,
              appointmentDateTime: appointmentDateTime,
              appointmentEndDateTime: appointmentEndDateTime,
              fee: fee
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _printReceipt(),
        child: const Icon(Icons.print),
        tooltip: 'Print Receipt',
      ),
    );
  }

  Future<void> _printReceipt() async {
    await printReceipt(
      shopName: shopName,
      shopAddress: shopAddress,
      shopTel: shopTel,
      transactionDate: transactionDate,
      serviceItems: serviceItems,
      totalAmount: totalAmount,
      cashPaid: cashPaid,
      change: change,
      paymentMethod: paymentMethod,
      bookingId: bookingId,
      discountCode: discountCode,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      customerName: customerName,
      staffName: staffName,
      appointmentDateTime: appointmentDateTime,
      appointmentEndDateTime: appointmentEndDateTime,
      fee: fee, // ⭐ THÊM FEE
    );
  }
}

// ReceiptWidget với barcode được căn giữa và đầy đủ thông tin
class ReceiptWidget extends StatelessWidget {
  final String shopName;
  final String shopAddress;
  final String shopTel;
  final DateTime transactionDate;
  final List<Map<String, dynamic>> serviceItems;
  final double totalAmount; // ← Đây là số backend gửi về (đã là TOTAL PAID cuối cùng)
  final double cashPaid;
  final double change;
  final String? discountCode;
  final double? discountAmount;
  final double? tipAmount;
  final String paymentMethod;
  final int bookingId;
  final String customerName;
  final String staffName;
  final DateTime appointmentDateTime;
  final DateTime appointmentEndDateTime;
  final double fee;

  const ReceiptWidget({
    super.key,
    required this.shopName,
    required this.shopAddress,
    required this.shopTel,
    required this.transactionDate,
    required this.serviceItems,
    required this.totalAmount,
    required this.cashPaid,
    required this.change,
    required this.paymentMethod,
    required this.bookingId,
    this.discountCode,
    this.discountAmount,
    this.tipAmount,
    required this.customerName,
    required this.staffName,
    required this.appointmentDateTime,
    required this.appointmentEndDateTime,
    required this.fee,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MM/dd/yyyy HH:mm');
    final formattedDate = dateFormatter.format(transactionDate);

    String _formatCurrency(double amount) {
      return '\$${amount.toStringAsFixed(2)}';
    }

    // ⭐ TÍNH ĐÚNG THEO YÊU CẦU MỚI
    final double discountAmt = discountAmount ?? 0.0;
    final double tipAmt = tipAmount ?? 0.0;

    // Tính cash discount (chỉ khi thanh toán bằng Cash)
    final bool isCash = paymentMethod.toLowerCase().contains('cash') || paymentMethod == '1';
    final double cashDiscount = isCash ? (fee * serviceItems.length) : 0.0;

    // Tính lại Subtotal gốc (trước mọi discount)
    final double subtotal = totalAmount + cashDiscount;

    // Format appointment time
    final appointmentDateFormatter = DateFormat('MM/dd/yyyy');
    final appointmentTimeFormatter = DateFormat('HH:mm');
    final bool isSameDay = appointmentDateTime.year == appointmentEndDateTime.year &&
        appointmentDateTime.month == appointmentEndDateTime.month &&
        appointmentDateTime.day == appointmentEndDateTime.day;

    String appointmentDisplay;
    if (isSameDay) {
      appointmentDisplay =
      '${appointmentDateFormatter.format(appointmentDateTime)} • ${appointmentTimeFormatter.format(appointmentDateTime)}-${appointmentTimeFormatter.format(appointmentEndDateTime)}';
    } else {
      appointmentDisplay =
      '${appointmentDateFormatter.format(appointmentDateTime)} ${appointmentTimeFormatter.format(appointmentDateTime)} - ${appointmentDateFormatter.format(appointmentEndDateTime)} ${appointmentTimeFormatter.format(appointmentEndDateTime)}';
    }

    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Shop Info
            _buildCenteredText(shopName, fontSize: 16, fontWeight: FontWeight.bold),
            const SizedBox(height: 4),
            _buildCenteredText(shopAddress, fontSize: 12),
            const SizedBox(height: 2),
            _buildCenteredText('Tel: $shopTel', fontSize: 12),

            const SizedBox(height: 10),
            const Divider(thickness: 1),

            _buildCenteredText('RECEIPT', fontSize: 14, fontWeight: FontWeight.bold),

            const SizedBox(height: 5),
            const Divider(thickness: 1),

            _buildTwoColumnRow(leftText: 'Customer', rightText: customerName),
            const SizedBox(height: 4),
            _buildTwoColumnRow(leftText: 'Staff', rightText: staffName),
            const SizedBox(height: 4),
            _buildTwoColumnRow(leftText: 'Appt', rightText: appointmentDisplay),

            const SizedBox(height: 10),
            const Divider(thickness: 1),

            _buildTwoColumnRow(leftText: 'Date', rightText: formattedDate),

            const SizedBox(height: 10),
            const Divider(thickness: 1),

            // Service Items
            ...serviceItems.map((item) {
              final name = item['name'] as String;
              final price = (item['price'] as double).toStringAsFixed(2);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _buildRow([name, '\$$price'], alignRight: true),
              );
            }).toList(),

            const SizedBox(height: 10),
            const Divider(thickness: 2),

            // ⭐ SUBTOTAL (GIÁ GỐC)
            _buildRow(['Subtotal:', _formatCurrency(subtotal)], alignRight: true),

            // Discount Code
            if (discountCode != null && discountCode!.isNotEmpty)
              _buildRow(['Discount Code:', discountCode!], alignRight: true),

            // Discount Amount
            if (discountAmt > 0)
              _buildRow(['Discount Amount:', '-${_formatCurrency(discountAmt)}'], alignRight: true),

            // ⭐ CASH DISCOUNT
            if (cashDiscount > 0)
              _buildRow(['Cash Discount:', '-${_formatCurrency(cashDiscount)}'], alignRight: true),

            // Tips
            if (tipAmt > 0)
              _buildRow(['Tip:', '+${_formatCurrency(tipAmt)}'], alignRight: true),

            const SizedBox(height: 10),
            const Divider(thickness: 2),

            // ⭐ TOTAL AMOUNT - CHÍNH XÁC SỐ KHÁCH TRẢ
            _buildRow(
              ['TOTAL AMOUNT:', _formatCurrency(totalAmount + tipAmt - discountAmt)],
              fontSize: 16,
              fontWeight: FontWeight.bold,
              alignRight: true,
            ),

            const Divider(thickness: 1),

            _buildCenteredText('Payment: $paymentMethod', fontSize: 12),

            const SizedBox(height: 10),
            _buildCenteredText('THANK YOU', fontSize: 14, fontWeight: FontWeight.bold),

            const SizedBox(height: 10),

            // Barcode
            Center(
              child: BarcodeWidget(
                barcode: Barcode.code128(),
                data: 'Booking #$bookingId',
                width: 220,
                height: 60,
                drawText: false,
              ),
            ),

            const SizedBox(height: 8),
            _buildCenteredText('Booking #$bookingId', fontSize: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredText(String text, {double fontSize = 12, FontWeight fontWeight = FontWeight.normal}) {
    return Center(
      child: Text(text, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight), textAlign: TextAlign.center),
    );
  }

  Widget _buildRow(List<String> parts, {bool alignRight = false, double fontSize = 12, FontWeight fontWeight = FontWeight.normal}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(flex: 2, child: Text(parts[0], style: TextStyle(fontSize: fontSize, fontWeight: fontWeight))),
        Expanded(
          flex: 1,
          child: Text(
            parts[1],
            style: TextStyle(fontSize: fontSize, fontWeight: fontWeight),
            textAlign: alignRight ? TextAlign.end : TextAlign.start,
          ),
        ),
      ],
    );
  }

  Widget _buildTwoColumnRow({required String leftText, required String rightText, double fontSize = 12, FontWeight fontWeight = FontWeight.normal}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 60, child: Text(leftText, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: Colors.grey[700]))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(rightText, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight), textAlign: TextAlign.right),
        ),
      ],
    );
  }
}

// HÀM CHÍNH: printReceipt với kiểm tra device và fallback
Future<void> printReceipt({
  required String shopName,
  required String shopAddress,
  required String shopTel,
  required DateTime transactionDate,
  required List<Map<String, dynamic>> serviceItems,
  required double totalAmount,
  required double cashPaid,
  required double change,
  required String paymentMethod,
  required int bookingId,
  String? discountCode,
  double? discountAmount,
  double? tipAmount,
  required String customerName,
  required String staffName,
  required DateTime appointmentDateTime,
  required DateTime appointmentEndDateTime,
  required double fee,
}) async {
  final deviceInfo = DeviceInfoPlugin();
  bool isSunmi = false;

  try {
    final androidInfo = await deviceInfo.androidInfo;
    isSunmi = androidInfo.model.toLowerCase().contains('sunmi') ||
        androidInfo.model.toLowerCase().contains('t2') ||
        androidInfo.brand.toLowerCase().contains('sunmi');
  } catch (e) {
    isSunmi = false;
  }

  if (isSunmi) {
    await _printWithSunmi(
      shopName: shopName,
      shopAddress: shopAddress,
      shopTel: shopTel,
      transactionDate: transactionDate,
      serviceItems: serviceItems,
      totalAmount: totalAmount,
      cashPaid: cashPaid,
      change: change,
      paymentMethod: paymentMethod,
      bookingId: bookingId,
      discountCode: discountCode,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      customerName: customerName,
      staffName: staffName,
      appointmentDateTime: appointmentDateTime,
      appointmentEndDateTime: appointmentEndDateTime,
      fee: fee,
    );
  } else {
    await _printPdfReceipt(
      shopName: shopName,
      shopAddress: shopAddress,
      shopTel: shopTel,
      transactionDate: transactionDate,
      serviceItems: serviceItems,
      totalAmount: totalAmount,
      cashPaid: cashPaid,
      change: change,
      paymentMethod: paymentMethod,
      bookingId: bookingId,
      discountCode: discountCode,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      customerName: customerName,
      staffName: staffName,
      appointmentDateTime: appointmentDateTime,
      appointmentEndDateTime: appointmentEndDateTime,
      fee: fee,
    );
  }
}

// HÀM FALLBACK: In PDF
Future<void> _printPdfReceipt({
  required String shopName,
  required String shopAddress,
  required String shopTel,
  required DateTime transactionDate,
  required List<Map<String, dynamic>> serviceItems,
  required double totalAmount,
  required double cashPaid,
  required double change,
  required String paymentMethod,
  required int bookingId,
  String? discountCode,
  double? discountAmount,
  double? tipAmount,
  required String customerName,
  required String staffName,
  required DateTime appointmentDateTime,
  required DateTime appointmentEndDateTime,
  required double fee,
}) async {
  final pdf = pw.Document();
  final dateFormatter = DateFormat('MM/dd/yyyy HH:mm');
  final formattedDate = dateFormatter.format(transactionDate);

  // ⭐ TÍNH CASH DISCOUNT
  final paymentMethodStrPdf = paymentMethod.toLowerCase();
  final isCashPaymentPdf = paymentMethodStrPdf == 'cash' || paymentMethodStrPdf == '1';
  final serviceCountPdf = serviceItems.length;
  final cashDiscountPdf = isCashPaymentPdf ? (fee * serviceCountPdf) : 0.0;

  final amountAfterRegularDiscountPdf = totalAmount - (discountAmount ?? 0.0);
  final amountAfterCashDiscountPdf = amountAfterRegularDiscountPdf - cashDiscountPdf;
  final totalWithTipPdf = amountAfterCashDiscountPdf + (tipAmount ?? 0.0);

  final appointmentDateFormatterPdf = DateFormat('MM/dd/yyyy');
  final appointmentTimeFormatterPdf = DateFormat('HH:mm');

  final bool isSameDayPdf = appointmentDateTime.year == appointmentEndDateTime.year &&
      appointmentDateTime.month == appointmentEndDateTime.month &&
      appointmentDateTime.day == appointmentEndDateTime.day;

  String appointmentDisplayPdf;
  if (isSameDayPdf) {
    appointmentDisplayPdf = '${appointmentDateFormatterPdf.format(appointmentDateTime)} • ${appointmentTimeFormatterPdf.format(appointmentDateTime)}-${appointmentTimeFormatterPdf.format(appointmentEndDateTime)}';
  } else {
    appointmentDisplayPdf = '${appointmentDateFormatterPdf.format(appointmentDateTime)} ${appointmentTimeFormatterPdf.format(appointmentDateTime)} - ${appointmentDateFormatterPdf.format(appointmentEndDateTime)} ${appointmentTimeFormatterPdf.format(appointmentEndDateTime)}';
  }

  const double k80Width = 226;
  const double pageHeight = 1000;

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(k80Width, pageHeight, marginAll: 5),
      build: (pw.Context context) {
        return pw.Container(
          width: k80Width - 10,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              // Shop Info
              pw.Center(
                child: pw.Text(
                  shopName,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  shopAddress,
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Tel: $shopTel',
                  style: const pw.TextStyle(fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Header
              pw.Center(
                child: pw.Text(
                  'RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Customer Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('Customer:', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      customerName,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('Staff:', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      staffName,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 2),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('Appt:', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      appointmentDisplayPdf,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.5),

              // Date
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text('Date:', style: const pw.TextStyle(fontSize: 8)),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      formattedDate,
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              // Items
              ...serviceItems.map((item) {
                final name = item['name'] as String;
                final price = (item['price'] as double).toStringAsFixed(2);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          name,
                          style: const pw.TextStyle(fontSize: 8),
                          maxLines: 2,
                        ),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          '\$$price',
                          style: const pw.TextStyle(fontSize: 8),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.SizedBox(height: 3),
              pw.Divider(thickness: 1),

              // Subtotal
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 8)),
                  pw.Text(
                      '\$${totalAmount.toStringAsFixed(2)}',
                      style: const pw.TextStyle(fontSize: 8),
                      textAlign: pw.TextAlign.right
                  ),
                ],
              ),

              // Discount Code
              if (discountCode != null && discountCode!.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount Code:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        discountCode!,
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
              ],

              // Discount Amount
              if (discountAmount != null && discountAmount! > 0) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount Amount:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        '- \$${discountAmount!.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
              ],

              // ⭐ CASH DISCOUNT
              if (cashDiscountPdf > 0) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash Discount:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        '- \$${cashDiscountPdf.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    '(\$${fee.toStringAsFixed(2)} × $serviceCountPdf services)',
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],

              // Tips
              if (tipAmount != null && tipAmount! > 0) ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tips:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        '\$${tipAmount!.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      '\$${totalWithTipPdf.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      textAlign: pw.TextAlign.right
                  ),
                ],
              ),

              if (paymentMethod == 'Cash') ...[
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Cash Paid:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        '\$${cashPaid.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Change:', style: const pw.TextStyle(fontSize: 8)),
                    pw.Text(
                        '\$${change.toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 8),
                        textAlign: pw.TextAlign.right
                    ),
                  ],
                ),
              ],

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 0.5),

              pw.Center(
                child: pw.Text(
                  'Payment: $paymentMethod',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Center(
                child: pw.Text(
                  'THANK YOU',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 6),

              pw.Center(
                child: pw.Container(
                  width: 150,
                  height: 35,
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: 'Booking #$bookingId',
                  ),
                ),
              ),

              pw.SizedBox(height: 4),

              pw.Center(
                child: pw.Text(
                  'Booking #$bookingId',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
    name: 'Receipt_$bookingId.pdf',
  );
}

// HÀM MỚI: In trực tiếp với Sunmi Printer
Future<void> _printWithSunmi({
  required String shopName,
  required String shopAddress,
  required String shopTel,
  required DateTime transactionDate,
  required List<Map<String, dynamic>> serviceItems,
  required double totalAmount,
  required double cashPaid,
  required double change,
  required String paymentMethod,
  required int bookingId,
  String? discountCode,
  double? discountAmount,
  double? tipAmount,
  required String customerName,
  required String staffName,
  required DateTime appointmentDateTime,
  required DateTime appointmentEndDateTime,
  required double fee,
}) async {
  final dateFormatter = DateFormat('MM/dd/yyyy HH:mm');
  final formattedDate = dateFormatter.format(transactionDate);

  // ⭐ TÍNH CASH DISCOUNT
  final paymentMethodStrSunmi = paymentMethod.toLowerCase();
  final isCashPaymentSunmi = paymentMethodStrSunmi == 'cash' || paymentMethodStrSunmi == '1';
  final serviceCountSunmi = serviceItems.length;
  final cashDiscountSunmi = isCashPaymentSunmi ? (fee * serviceCountSunmi) : 0.0;

  final amountAfterRegularDiscountSunmi = totalAmount - (discountAmount ?? 0.0);
  final amountAfterCashDiscountSunmi = amountAfterRegularDiscountSunmi - cashDiscountSunmi;
  final totalWithTipSunmi = amountAfterCashDiscountSunmi + (tipAmount ?? 0.0);

  final appointmentDateFormatter = DateFormat('MM/dd/yyyy');
  final appointmentTimeFormatter = DateFormat('HH:mm');
  final bool isSameDay = appointmentDateTime.year == appointmentEndDateTime.year &&
      appointmentDateTime.month == appointmentEndDateTime.month &&
      appointmentDateTime.day == appointmentEndDateTime.day;
  String appointmentDisplay;
  if (isSameDay) {
    appointmentDisplay = '${appointmentTimeFormatter.format(appointmentDateTime)}-${appointmentTimeFormatter.format(appointmentEndDateTime)}';
  } else {
    appointmentDisplay = '${appointmentDateFormatter.format(appointmentDateTime)} ${appointmentTimeFormatter.format(appointmentDateTime)} - ${appointmentDateFormatter.format(appointmentEndDateTime)} ${appointmentTimeFormatter.format(appointmentEndDateTime)}';
  }

  try {
    await SunmiPrinter.bindingPrinter();
    await SunmiPrinter.initPrinter();
    await SunmiPrinter.startTransactionPrint(true);

    final status = await SunmiPrinter.getPrinterStatus();
    if (status != PrinterStatus.NORMAL) {
      debugPrint('Printer status: $status');
      await SunmiPrinter.exitTransactionPrint(true);
      await _printPdfReceipt(
        shopName: shopName,
        shopAddress: shopAddress,
        shopTel: shopTel,
        transactionDate: transactionDate,
        serviceItems: serviceItems,
        totalAmount: totalAmount,
        cashPaid: cashPaid,
        change: change,
        paymentMethod: paymentMethod,
        bookingId: bookingId,
        discountCode: discountCode,
        discountAmount: discountAmount,
        tipAmount: tipAmount,
        customerName: customerName,
        staffName: staffName,
        appointmentDateTime: appointmentDateTime,
        appointmentEndDateTime: appointmentEndDateTime,
        fee: fee,
      );
      return;
    }

    await SunmiPrinter.lineWrap(1);

    // Shop Info
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText(shopName,
        style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText(shopAddress);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('Tel: $shopTel');
    await SunmiPrinter.lineWrap(1);

    // Header
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('RECEIPT',
        style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);

    // Customer
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Customer:', width: 12),
      ColumnMaker(text: _truncateText(customerName, 30), width: 34, align: SunmiPrintAlign.RIGHT),
    ]);

    // Staff
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Staff:', width: 12),
      ColumnMaker(text: _truncateText(staffName, 30), width: 34, align: SunmiPrintAlign.RIGHT),
    ]);

    // Appointment
    final truncatedAppointment = _truncateText(appointmentDisplay, 30);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Appt:', width: 12),
      ColumnMaker(text: truncatedAppointment, width: 34, align: SunmiPrintAlign.RIGHT),
    ]);

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);

    // Date
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Date:', width: 12),
      ColumnMaker(text: formattedDate, width: 34, align: SunmiPrintAlign.RIGHT),
    ]);

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);

    // Service Items
    for (final item in serviceItems) {
      final name = item['name'] as String;
      final price = (item['price'] as double).toStringAsFixed(2);
      final truncatedName = _truncateText(name, 28);

      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: truncatedName, width: 28),
        ColumnMaker(text: '\$$price', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
    }

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);

    // Subtotal
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Subtotal', width: 28),
      ColumnMaker(text: '\$${totalAmount.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
    ]);

    // Discount Code
    if (discountCode != null && discountCode!.isNotEmpty) {
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Discount Code', width: 28),
        ColumnMaker(text: discountCode!, width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
    }

    // Discount Amount
    if (discountAmount != null && discountAmount! > 0) {
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Discount Amount', width: 28),
        ColumnMaker(text: '- \$${discountAmount!.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
    }

    // ⭐ CASH DISCOUNT
    if (cashDiscountSunmi > 0) {
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Cash Discount', width: 28),
        ColumnMaker(text: '- \$${cashDiscountSunmi.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printText(
        '(\$${fee.toStringAsFixed(2)} × $serviceCountSunmi services)',
        style: SunmiStyle(fontSize: SunmiFontSize.SM),
      );
    }

    // Tips
    if (tipAmount != null && tipAmount! > 0) {
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Tips', width: 28),
        ColumnMaker(text: '\$${tipAmount!.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
    }

    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);

    // Total
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printRow(cols: [
      ColumnMaker(text: 'Total', width: 28, align: SunmiPrintAlign.LEFT),
      ColumnMaker(text: '\$${totalWithTipSunmi.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
    ]);

    await SunmiPrinter.lineWrap(1);

    // Cash Payment
    if (paymentMethod == 'Cash') {
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Cash Paid', width: 28),
        ColumnMaker(text: '\$${cashPaid.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
      await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Change', width: 28),
        ColumnMaker(text: '\$${change.toStringAsFixed(2)}', width: 18, align: SunmiPrintAlign.RIGHT),
      ]);
      await SunmiPrinter.lineWrap(1);
    }

    // Payment Method
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.line(ch: '-', len: 42);
    await SunmiPrinter.lineWrap(1);
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('Payment: $paymentMethod');
    await SunmiPrinter.lineWrap(1);

    // Thank You
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('THANK YOU',
        style: SunmiStyle(bold: true, fontSize: SunmiFontSize.MD));
    await SunmiPrinter.lineWrap(1);

    // Barcode
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printBarCode(
      'Booking #$bookingId',
      barcodeType: SunmiBarcodeType.CODE128,
      height: 60,
      width: 2,
      textPosition: SunmiBarcodeTextPos.NO_TEXT,
    );

    // Footer
    await SunmiPrinter.setAlignment(SunmiPrintAlign.CENTER);
    await SunmiPrinter.printText('Booking #$bookingId');
    await SunmiPrinter.lineWrap(2);

    await SunmiPrinter.exitTransactionPrint(true);
    await SunmiPrinter.cut();

  } catch (e) {
    debugPrint('Sunmi print error: $e');
    try {
      await SunmiPrinter.exitTransactionPrint(true);
    } catch (_) {}

    await _printPdfReceipt(
      shopName: shopName,
      shopAddress: shopAddress,
      shopTel: shopTel,
      transactionDate: transactionDate,
      serviceItems: serviceItems,
      totalAmount: totalAmount,
      cashPaid: cashPaid,
      change: change,
      paymentMethod: paymentMethod,
      bookingId: bookingId,
      discountCode: discountCode,
      discountAmount: discountAmount,
      tipAmount: tipAmount,
      customerName: customerName,
      staffName: staffName,
      appointmentDateTime: appointmentDateTime,
      appointmentEndDateTime: appointmentEndDateTime,
      fee: fee,
    );
  } finally {
    try {
      await SunmiPrinter.unbindingPrinter();
    } catch (_) {}
  }
}

String _truncateText(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}