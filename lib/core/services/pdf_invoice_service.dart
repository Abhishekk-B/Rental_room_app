import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/currency_helper.dart';
import '../utils/date_helper.dart';
import '../database/daos/billing_dao.dart';
import '../database/daos/payment_dao.dart';
import '../../features/billing/domain/billing_engine.dart';

class PdfInvoiceService {
  /// Loads Roboto font from assets for reliable, offline Indian Rupee (₹) symbol support
  static Future<pw.ThemeData> _getPdfTheme() async {
    try {
      final fontData = await rootBundle.load('assets/Roboto-Regular.ttf');
      final boldFontData = await rootBundle.load('assets/Roboto-Bold.ttf');
      final ttf = pw.Font.ttf(fontData);
      final ttfBold = pw.Font.ttf(boldFontData);
      return pw.ThemeData.withFont(base: ttf, bold: ttfBold);
    } catch (_) {
      return pw.ThemeData.base();
    }
  }

  /// Generates a professional PDF monthly invoice (Rent + Electricity + Utilities)
  static Future<Uint8List> generateMonthlyBillPdf({
    required MonthlyBillRecord bill,
    String ownerName = 'Property Owner',
    String ownerPhone = '',
    String ownerUpiId = '',
  }) async {
    final pdf = pw.Document();
    final theme = await _getPdfTheme();

    final primaryColor = PdfColor.fromHex('#0D5C3A');
    final darkGrey = PdfColor.fromHex('#333333');
    final lightGrey = PdfColor.fromHex('#F5F5F5');

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RENT & UTILITY INVOICE',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Invoice #: ${bill.billNumber}',
                        style: pw.TextStyle(color: darkGrey, fontSize: 12),
                      ),
                      pw.Text(
                        'Billing Period: ${DateHelper.formatBillingPeriod(bill.billingMonth, bill.billingYear)}',
                        style: pw.TextStyle(color: darkGrey, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        ownerName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      if (ownerPhone.isNotEmpty)
                        pw.Text('Phone: $ownerPhone', style: const pw.TextStyle(fontSize: 11)),
                      if (ownerUpiId.isNotEmpty)
                        pw.Text('UPI ID: $ownerUpiId', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: primaryColor, thickness: 1.5, height: 24),

              // Tenant & Room Details
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To:', style: pw.TextStyle(color: darkGrey, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          bill.tenantName,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        if (bill.tenantPhone.isNotEmpty)
                          pw.Text('Phone: ${bill.tenantPhone}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Room Details:', style: pw.TextStyle(color: darkGrey, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          bill.roomNumber,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          'Due Date: ${DateHelper.formatEpoch(bill.dueDateEpoch)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Itemized Table
              pw.Text(
                'CHARGES BREAKDOWN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(4),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                  ...bill.lineItems.map(
                    (LineItemInput item) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 11)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(item.category, style: const pw.TextStyle(fontSize: 11)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            CurrencyHelper.formatPaise(item.amountPaise, showSymbol: true, showDecimals: true),
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Totals & Balance Calculation Block
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 270,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow(
                        'Total Current Charges:',
                        CurrencyHelper.formatPaise(
                          bill.rentAmountPaise + bill.electricityAmountPaise + bill.additionalChargesPaise,
                          showDecimals: true,
                        ),
                      ),
                      if (bill.rentAdvanceAppliedPaise > 0)
                        _buildSummaryRow(
                          'Rent Advance Applied:',
                          '- ${CurrencyHelper.formatPaise(bill.rentAdvanceAppliedPaise, showDecimals: true)}',
                          textColor: primaryColor,
                        ),
                      if (bill.electricityAdvanceAppliedPaise > 0)
                        _buildSummaryRow(
                          'Elec. Advance Applied:',
                          '- ${CurrencyHelper.formatPaise(bill.electricityAdvanceAppliedPaise, showDecimals: true)}',
                          textColor: PdfColors.orange900,
                        ),
                      if (bill.previousBalancePaise > 0)
                        _buildSummaryRow(
                          'Previous Outstanding:',
                          CurrencyHelper.formatPaise(bill.previousBalancePaise, showDecimals: true),
                          textColor: PdfColors.red800,
                        ),
                      pw.Divider(color: PdfColors.grey400),
                      _buildSummaryRow(
                        'Net Amount Due to Pay:',
                        CurrencyHelper.formatPaise(bill.netAmountDuePaise, showDecimals: true),
                        isBold: true,
                        fontSize: 13,
                      ),
                      if (bill.amountPaidPaise > 0)
                        _buildSummaryRow(
                          'Amount Paid:',
                          CurrencyHelper.formatPaise(bill.amountPaidPaise, showDecimals: true),
                          textColor: PdfColors.green800,
                        ),
                      _buildSummaryRow(
                        'Remaining Balance:',
                        CurrencyHelper.formatPaise(bill.remainingBalancePaise, showDecimals: true),
                        isBold: true,
                        fontSize: 14,
                        textColor: bill.remainingBalancePaise > 0 ? PdfColors.red900 : PdfColors.green900,
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Payment Instructions Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Payment Instructions:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor),
                          ),
                          pw.Text(
                            'Please transfer the due amount via UPI or Cash on or before the due date.',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          if (ownerUpiId.isNotEmpty)
                            pw.Text('UPI ID: $ownerUpiId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Text(
                      'STATUS: ${bill.status}',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: bill.status == 'PAID' ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a professional Electricity-Only PDF invoice & meter reading receipt
  static Future<Uint8List> generateElectricityBillPdf({
    required MonthlyBillRecord bill,
    required int previousReadingCentiunits,
    required int currentReadingCentiunits,
    required int unitsConsumedCentiunits,
    required int ratePerUnitPaise,
    String subMeterNumber = 'Sub-Meter',
    String ownerName = 'Property Owner',
    String ownerPhone = '',
    String ownerUpiId = '',
  }) async {
    final pdf = pw.Document();
    final theme = await _getPdfTheme();

    final primaryColor = PdfColor.fromHex('#D35400'); // Amber/Orange electricity theme
    final darkGrey = PdfColor.fromHex('#333333');
    final lightGrey = PdfColor.fromHex('#FDF2E9');

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final double units = unitsConsumedCentiunits / 100.0;
          final double prevUnits = previousReadingCentiunits / 100.0;
          final double currUnits = currentReadingCentiunits / 100.0;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ELECTRICITY INVOICE & METER RECEIPT',
                        style: pw.TextStyle(
                          color: primaryColor,
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Invoice #: ELEC-${bill.billNumber}',
                        style: pw.TextStyle(color: darkGrey, fontSize: 12),
                      ),
                      pw.Text(
                        'Billing Period: ${DateHelper.formatBillingPeriod(bill.billingMonth, bill.billingYear)}',
                        style: pw.TextStyle(color: darkGrey, fontSize: 12),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        ownerName,
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      if (ownerPhone.isNotEmpty)
                        pw.Text('Phone: $ownerPhone', style: const pw.TextStyle(fontSize: 11)),
                      if (ownerUpiId.isNotEmpty)
                        pw.Text('UPI ID: $ownerUpiId', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.Divider(color: primaryColor, thickness: 1.5, height: 24),

              // Tenant & Sub-Meter Details Card
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To Tenant:', style: pw.TextStyle(color: darkGrey, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          bill.tenantName,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        if (bill.tenantPhone.isNotEmpty)
                          pw.Text('Phone: ${bill.tenantPhone}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Room & Sub-Meter Details:', style: pw.TextStyle(color: darkGrey, fontSize: 10)),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Room: ${bill.roomNumber}',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text('Meter: $subMeterNumber', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(
                          'Due Date: ${DateHelper.formatEpoch(bill.dueDateEpoch)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Sub-Meter Reading Breakdown Table
              pw.Text(
                'METER READING & CONSUMPTION BREAKDOWN',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 8),

              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: lightGrey),
                    children: [
                      _tableHeaderCell('Last / Previous Reading'),
                      _tableHeaderCell('Current Reading'),
                      _tableHeaderCell('Units Consumed'),
                      _tableHeaderCell('Rate / Unit'),
                      _tableHeaderCell('Total Charge', align: pw.TextAlign.right),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _tableDataCell('${prevUnits.toStringAsFixed(2)} units'),
                      _tableDataCell('${currUnits.toStringAsFixed(2)} units'),
                      _tableDataCell('${units.toStringAsFixed(2)} units', isBold: true),
                      _tableDataCell('${CurrencyHelper.formatPaise(ratePerUnitPaise)} / unit'),
                      _tableDataCell(
                        CurrencyHelper.formatPaise(bill.electricityAmountPaise, showDecimals: true),
                        isBold: true,
                        align: pw.TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Advance / Deficit / Settlement Summary Block
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  width: 280,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow(
                        'Total Electricity Bill:',
                        CurrencyHelper.formatPaise(bill.electricityAmountPaise, showDecimals: true),
                        isBold: true,
                      ),
                      if (bill.electricityAdvanceAppliedPaise > 0)
                        _buildSummaryRow(
                          'Electricity Advance Applied:',
                          '- ${CurrencyHelper.formatPaise(bill.electricityAdvanceAppliedPaise, showDecimals: true)}',
                          textColor: primaryColor,
                        ),
                      pw.Divider(color: PdfColors.grey400),
                      _buildSummaryRow(
                        'Net Electricity Bill Due:',
                        CurrencyHelper.formatPaise(bill.outstandingElectricityPaise, showDecimals: true),
                        isBold: true,
                        fontSize: 13,
                        textColor: primaryColor,
                      ),
                      if (bill.amountPaidPaise > 0)
                        _buildSummaryRow(
                          'Electricity Paid:',
                          CurrencyHelper.formatPaise(
                            (bill.electricityAmountPaise - bill.outstandingElectricityPaise).clamp(0, bill.electricityAmountPaise),
                            showDecimals: true,
                          ),
                          textColor: PdfColors.green800,
                        ),
                      _buildSummaryRow(
                        'Remaining Balance Due:',
                        CurrencyHelper.formatPaise(bill.outstandingElectricityPaise, showDecimals: true),
                        isBold: true,
                        fontSize: 14,
                        textColor: bill.outstandingElectricityPaise > 0 ? PdfColors.red900 : PdfColors.green900,
                      ),
                    ],
                  ),
                ),
              ),

              pw.Spacer(),

              // Payment Instructions Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Electricity Payment Notice:',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: primaryColor),
                          ),
                          pw.Text(
                            'Please settle electricity charges on or before the due date via UPI or Cash.',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                          if (ownerUpiId.isNotEmpty)
                            pw.Text('UPI ID: $ownerUpiId', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    pw.Text(
                      bill.outstandingElectricityPaise <= 0 ? 'STATUS: PAID' : 'STATUS: DUE',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: bill.outstandingElectricityPaise <= 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generates a payment receipt PDF
  static Future<Uint8List> generatePaymentReceiptPdf({
    required PaymentRecord payment,
    String ownerName = 'Property Owner',
  }) async {
    final pdf = pw.Document();
    final theme = await _getPdfTheme();
    final primaryColor = PdfColor.fromHex('#0D5C3A');

    pdf.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'PAYMENT ACKNOWLEDGEMENT RECEIPT',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: primaryColor),
              pw.SizedBox(height: 8),

              _buildSummaryRow('Receipt Number:', payment.receiptNumber, isBold: true),
              _buildSummaryRow('Payment Date:', DateHelper.formatEpoch(payment.paymentDateEpoch)),
              _buildSummaryRow('Received From:', payment.tenantName),
              _buildSummaryRow('Room Number:', payment.roomNumber),
              _buildSummaryRow('Payment Method:', payment.paymentMethod),
              if (payment.transactionRef != null && payment.transactionRef!.isNotEmpty)
                _buildSummaryRow('Transaction Ref:', payment.transactionRef!),
              pw.Divider(color: PdfColors.grey400),
              _buildSummaryRow(
                'Amount Received:',
                CurrencyHelper.formatPaise(payment.amountPaise, showDecimals: true),
                isBold: true,
                fontSize: 14,
                textColor: PdfColors.green800,
              ),
              pw.SizedBox(height: 24),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Authorized Signature', style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 20),
                    pw.Text(ownerName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tableHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5),
      ),
    );
  }

  static pw.Widget _tableDataCell(String text, {bool isBold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 11,
    PdfColor? textColor,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey700)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: textColor ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Prints or shares PDF via Android system share sheet
  static Future<void> sharePdf(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
