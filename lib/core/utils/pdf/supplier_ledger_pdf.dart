import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:bangla_pdf/bangla_pdf.dart';
import '../../database/database.dart';
import '../formatters.dart';
import 'pdf_helper.dart';

class SupplierLedgerPdfGenerator {
  static Future<pw.Document> buildLedgerPdfDocument({
    required Supplier supplier,
    required List<SupplierOrder> orders,
    required List<SupplierPayment> payments,
    required Map<String, String> productNames,
    DateTime? startDate,
  }) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();

    final regularStyle = pw.TextStyle(font: englishFont, fontSize: 8);
    final regularBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8);
    final boldStyle = pw.TextStyle(font: englishFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final boldBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);

    // Merge transactions: Orders increase outstanding balance, Payments decrease it.
    final List<_LedgerItem> allItems = [];
    for (final o in orders) {
      allItems.add(_LedgerItem(
        date: o.date,
        type: 'Order',
        description: 'অর্ডার: ${productNames[o.productId] ?? 'পণ্য'} (${Formatters.number(o.quantityOrdered)} টি)',
        charge: o.totalCost,
        credit: 0.0,
      ));
    }
    for (final p in payments) {
      allItems.add(_LedgerItem(
        date: p.date,
        type: 'Payment',
        description: p.notes ?? 'বিল পরিশোধ',
        charge: 0.0,
        credit: p.amount,
      ));
    }

    // Sort chronologically (oldest first) to compute running balance
    allItems.sort((a, b) => a.date.compareTo(b.date));

    double runningBalance = 0.0;
    double openingBalance = 0.0;
    final List<_LedgerItem> filteredItems = [];

    for (final item in allItems) {
      runningBalance += (item.charge - item.credit);
      if (startDate != null && item.date.isBefore(startDate)) {
        openingBalance = runningBalance;
      } else {
        item.runningBal = runningBalance;
        filteredItems.add(item);
      }
    }

    // Sort filtered items descending (newest first) for PDF presentation
    filteredItems.sort((a, b) => b.date.compareTo(a.date));

    // Summary calculations
    double totalCost = orders.fold(0.0, (sum, o) => sum + o.totalCost);
    double totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
    double currentDue = totalCost - totalPaid;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  Text(
                    'ভিলেজকো স্টোর',
                    style: pw.TextStyle(font: defaultFont, fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  Text(
                    'সরবরাহকারী লেজার ও বকেয়া হিসেব রিপোর্ট',
                    style: pw.TextStyle(font: defaultFont, fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                  if (startDate != null)
                    pw.Text(
                      'শুরুর তারিখ: ${Formatters.date(startDate)} থেকে',
                      style: pw.TextStyle(font: defaultFont, fontSize: 9, color: PdfColors.grey700),
                    ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1, color: PdfColors.black),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Supplier Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    Text('সরবরাহকারী: ${supplier.name}', style: pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    Text('মোবাইল: ${supplier.phone}', style: pw.TextStyle(font: defaultFont, fontSize: 9)),
                    if (supplier.address != null && supplier.address!.isNotEmpty)
                      Text('ঠিকানা: ${supplier.address}', style: pw.TextStyle(font: defaultFont, fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Row(
                      children: [
                        Text('মোট ক্রয়: ', style: pw.TextStyle(font: defaultFont, fontSize: 9)),
                        PdfHelper.currencyText(totalCost, style: regularStyle),
                      ],
                    ),
                    pw.Row(
                      children: [
                        Text('মোট পরিশোধ: ', style: pw.TextStyle(font: defaultFont, fontSize: 9)),
                        PdfHelper.currencyText(totalPaid, style: regularStyle),
                      ],
                    ),
                    pw.Row(
                      children: [
                        Text('বকেয়া পাওনা (বাকি): ', style: pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        PdfHelper.currencyText(currentDue, style: boldStyle, isBold: true),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),

            Text('লেনদেন ও পেমেন্ট হিস্ট্রি (Transaction & Payment History)', style: pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(4),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('তারিখ (Date)', style: boldBanglaStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('বিবরণ (Description)', style: boldBanglaStyle)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('ডেবিট (+) (Charge)', style: boldBanglaStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('ক্রেডিট (-) (Paid)', style: boldBanglaStyle, textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('বকেয়া (Balance)', style: boldBanglaStyle, textAlign: pw.TextAlign.right)),
                  ],
                ),
                if (startDate != null)
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(Formatters.date(startDate), style: regularStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('প্রারম্ভিক বকেয়া (Opening Balance)', style: regularBanglaStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('-', style: regularStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('-', style: regularStyle, textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: PdfHelper.currencyText(openingBalance, style: regularStyle, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ...filteredItems.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(Formatters.date(item.date), style: regularStyle)),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(item.description, style: regularBanglaStyle)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: item.charge > 0
                            ? PdfHelper.currencyText(item.charge, style: regularStyle, textAlign: pw.TextAlign.right)
                            : pw.Text('-', style: regularStyle, textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: item.credit > 0
                            ? PdfHelper.currencyText(item.credit, style: regularStyle, textAlign: pw.TextAlign.right)
                            : pw.Text('-', style: regularStyle, textAlign: pw.TextAlign.right),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: PdfHelper.currencyText(item.runningBal, style: regularStyle, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static Future<String?> generateAndSaveSupplierLedgerPdf({
    required Supplier supplier,
    required List<SupplierOrder> orders,
    required List<SupplierPayment> payments,
    required Map<String, String> productNames,
    DateTime? startDate,
    String? customSavePath,
  }) async {
    final pdf = await buildLedgerPdfDocument(
      supplier: supplier,
      orders: orders,
      payments: payments,
      productNames: productNames,
      startDate: startDate,
    );
    final output = await PdfHelper.getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/SupplierLedgers');
    final formattedName = supplier.name.replaceAll(RegExp(r'[^\w\s\-]'), '_');
    final file = File('${output.path}/ledger_${formattedName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  static Future<void> printSupplierLedger({
    required Supplier supplier,
    required List<SupplierOrder> orders,
    required List<SupplierPayment> payments,
    required Map<String, String> productNames,
    DateTime? startDate,
  }) async {
    final pdf = await buildLedgerPdfDocument(
      supplier: supplier,
      orders: orders,
      payments: payments,
      productNames: productNames,
      startDate: startDate,
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}

class _LedgerItem {
  final DateTime date;
  final String type;
  final String description;
  final double charge;
  final double credit;
  double runningBal;

  _LedgerItem({
    required this.date,
    required this.type,
    required this.description,
    required this.charge,
    required this.credit,
    this.runningBal = 0.0,
  });
}
