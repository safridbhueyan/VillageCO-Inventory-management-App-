import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:bangla_pdf/bangla_pdf.dart';
import '../database/database.dart';
import '../../features/sales/pos_controller.dart';
import 'formatters.dart';
import 'package:permission_handler/permission_handler.dart';

class PdfGenerator {

  static Future<pw.Document> _buildReceiptPdfDocument({
    required String saleId,
    required String dateStr,
    required String paymentMethod,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
  }) async {
    final pdf = pw.Document();

    final defaultFont = BanglaFontManager().defaultFont;
    final regularStyle = pw.TextStyle(font: defaultFont, fontSize: 7, fontWeight: pw.FontWeight.normal);
    final titleStyle = pw.TextStyle(font: defaultFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final totalStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final thankYouStyle = pw.TextStyle(font: defaultFont, fontSize: 7, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleStyle),
                    Text('মুদি দোকান ও পিওএস কেন্দ্র', style: regularStyle, banglaStyle: regularStyle),
                    Text('মোবাইল: +৮৮০১৭০০০০০০০০', style: regularStyle, banglaStyle: regularStyle),
                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  Text('রশিদ নং: ', style: regularStyle, banglaStyle: regularStyle),
                  pw.Text(saleId.substring(0, 8).toUpperCase(), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7)),
                ],
              ),
              pw.Row(
                children: [
                  Text('তারিখ ও সময়: ', style: regularStyle, banglaStyle: regularStyle),
                  pw.Text(dateStr, style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7)),
                ],
              ),
              Text('পেমেন্ট পদ্ধতি: $paymentMethod', style: regularStyle, banglaStyle: regularStyle),
              Text('ক্রেতার নাম: $customerName', style: regularStyle, banglaStyle: regularStyle),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              
              // Product headers
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 5, child: Text('পণ্যের বিবরণ', style: regularStyle, banglaStyle: regularStyle)),
                  pw.Expanded(flex: 2, child: Text('পরিমাণ', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: Text('মোট টাকা', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              
              // Items list
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 5, child: Text(item['name'] as String, style: regularStyle, banglaStyle: regularStyle)),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: RegExp(r'[\u0980-\u09FF]').hasMatch(item['qty'] as String)
                              ? Text(
                                  item['qty'] as String,
                                  style: regularStyle,
                                  banglaStyle: regularStyle,
                                )
                              : pw.Text(
                                  item['qty'] as String,
                                  style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 7),
                                ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: _buildItemTotalWidget(item['total'] as String, regularStyle),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              
              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text('উপ-মোট বিল:', style: regularStyle, banglaStyle: regularStyle),
                  _currencyText(subtotal, style: regularStyle),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ডিসকাউন্ট ছাড়:', style: regularStyle, banglaStyle: regularStyle),
                    _currencyText(-discount, style: regularStyle),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text('পরিশোধযোগ্য মোট বিল:', style: totalStyle, banglaStyle: totalStyle),
                  _currencyText(total, style: totalStyle, isBold: true),
                ],
              ),
              if (paidAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('পরিশোধিত টাকা:', style: regularStyle, banglaStyle: regularStyle),
                    _currencyText(paidAmount, style: regularStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ফেরতযোগ্য টাকা:', style: regularStyle, banglaStyle: regularStyle),
                    _currencyText(paidAmount - total < 0 ? 0.0 : paidAmount - total, style: regularStyle),
                  ],
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Center(
                child: Text('ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!', style: thankYouStyle, banglaStyle: thankYouStyle),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static pw.Widget _currencyText(double amount, {required pw.TextStyle style, bool isBold = false, pw.TextAlign textAlign = pw.TextAlign.left}) {
    final banglaFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();
    final isNegative = amount < 0;
    final absAmount = amount.abs();
    final valueStr = Formatters.currency(absAmount, symbol: '').trim();
    
    return pw.RichText(
      textAlign: textAlign,
      text: pw.TextSpan(
        children: [
          if (isNegative)
            pw.TextSpan(
              text: '-',
              style: pw.TextStyle(
                font: englishFont,
                fontSize: style.fontSize,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: style.color,
              ),
            ),
          pw.TextSpan(
            text: '\$ ', // Kalpurush maps '$' to Taka symbol '৳'
            style: pw.TextStyle(
              font: banglaFont,
              fontSize: style.fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: style.color,
            ),
          ),
          pw.TextSpan(
            text: valueStr,
            style: pw.TextStyle(
              font: englishFont,
              fontSize: style.fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemTotalWidget(String totalStr, pw.TextStyle style) {
    final cleanStr = totalStr.replaceAll('৳', '').trim();
    final banglaFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();
    
    return pw.RichText(
      textAlign: pw.TextAlign.right,
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '\$ ', // Kalpurush maps '$' to Taka symbol '৳'
            style: pw.TextStyle(
              font: banglaFont,
              fontSize: style.fontSize,
              fontWeight: style.fontWeight,
              color: style.color,
            ),
          ),
          pw.TextSpan(
            text: cleanStr,
            style: pw.TextStyle(
              font: englishFont,
              fontSize: style.fontSize,
              fontWeight: style.fontWeight,
              color: style.color,
            ),
          ),
        ],
      ),
    );
  }

  static Future<pw.Document> _buildProfitLossPdfDocument({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text('ভিলেজকো স্টোর', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 20)),
                    Text('লাভ-ক্ষতি বিবরণী (Profit & Loss Statement)', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    Text('তারিখ ও সময়: ${Formatters.dateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1, color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('বিবরণ (Description)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('টাকা (Amount)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('আজকের বিক্রির পরিমাণ', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('TK ${todaySales.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('মজুদ পণ্যের মূল্য', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('TK ${inventoryValue.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('মোট খরচের পরিমাণ', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('-TK ${totalExpenses.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('আজকের নিট লাভ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: Text('TK ${netProfit.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 40),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text('VillageCO Store Inventory & POS System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  static Future<Directory> getCsvSaveDirectory(String? customSavePath) {
    return _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/CSVs');
  }

  static Future<Directory> _getSaveDirectory(String? customSavePath, {required String defaultSubfolder}) async {
    if (customSavePath != null && customSavePath.isNotEmpty) {
      final dir = Directory(customSavePath);
      try {
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      } catch (_) {}
    }
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      downloadsDir = await getDownloadsDirectory();
    }
    downloadsDir ??= await getApplicationDocumentsDirectory();
    
    final defaultDir = Directory('${downloadsDir.path}/$defaultSubfolder');
    try {
      if (!await defaultDir.exists()) {
        await defaultDir.create(recursive: true);
      }
      return defaultDir;
    } catch (_) {
      return downloadsDir;
    }
  }

  static Future<String?> generateAndSaveTextReceipt({
    required String saleId,
    required String dateStr,
    required String paymentMethod,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
    String? customSavePath,
  }) async {
    final pdf = await _buildReceiptPdfDocument(
      saleId: saleId,
      dateStr: dateStr,
      paymentMethod: paymentMethod,
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
    );

    final pdfBytes = await pdf.save();
    
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/receipt_${saleId.substring(0, 8)}.pdf');
    
    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/receipt_${saleId.substring(0, 8)}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Receipt from VillageCO Store');
      return tempFile.path;
    }
  }

  static Future<void> printTextReceipt({
    required String saleId,
    required String dateStr,
    required String paymentMethod,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paidAmount,
  }) async {
    final pdf = await _buildReceiptPdfDocument(
      saleId: saleId,
      dateStr: dateStr,
      paymentMethod: paymentMethod,
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paidAmount: paidAmount,
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'receipt_${saleId.substring(0, 8)}',
    );
  }

  static Future<String?> generateAndSaveTextProfitLoss({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
    String? customSavePath,
  }) async {
    final pdf = await _buildProfitLossPdfDocument(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
    );

    final pdfBytes = await pdf.save();
    
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Profit & Loss Report');
      return null;
    }
  }

  static Future<pw.Document> _buildDailyReportPdfDocument({
    required double todaySales,
    required double totalExpenses,
    required double netProfit,
    required int totalTransactionsCount,
    required List<Map<String, dynamic>> todaySalesList,
  }) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final regularStyle = pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.normal);
    final titleStyle = pw.TextStyle(font: defaultFont, fontSize: 18, fontWeight: pw.FontWeight.bold);
    final subTitleStyle = pw.TextStyle(font: defaultFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleStyle),
                  pw.SizedBox(height: 4),
                  Text('দৈনিক লেনদেন রিপোর্ট (Daily Transaction Report)', style: subTitleStyle, banglaStyle: subTitleStyle),
                  pw.SizedBox(height: 4),
                  Text('তারিখ: ${Formatters.date(DateTime.now())} • সময়: ${Formatters.dateTime(DateTime.now()).split(" ").last}', style: regularStyle, banglaStyle: regularStyle),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.black),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            
            // Financial Summary Block
            Text('আর্থিক সারসংক্ষেপ (Financial Summary)', style: subTitleStyle, banglaStyle: subTitleStyle),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('খাত', style: headerStyle, banglaStyle: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('পরিমাণ (টাকা)', style: headerStyle, banglaStyle: headerStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('আজকের মোট বিক্রি', style: regularStyle, banglaStyle: regularStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('TK ${todaySales.toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('আজকের মোট খরচ', style: regularStyle, banglaStyle: regularStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('-TK ${totalExpenses.toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: netProfit >= 0 ? PdfColors.green50 : PdfColors.red50,
                  ),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('আজকের নিট লাভ', style: headerStyle, banglaStyle: headerStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('TK ${netProfit.toStringAsFixed(2)}', style: headerStyle, banglaStyle: headerStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('মোট লেনদেন সংখ্যা', style: regularStyle, banglaStyle: regularStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('$totalTransactionsCount টি', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            
            // Transactions list
            Text('আজকের বিক্রয় বিবরণী (Today\'s Sales list)', style: subTitleStyle, banglaStyle: subTitleStyle),
            pw.SizedBox(height: 8),
            if (todaySalesList.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: Text('আজকে কোনো বিক্রির লেনদেন হয়নি।', style: regularStyle, banglaStyle: regularStyle),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('রশিদ নং', style: headerStyle, banglaStyle: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('সময়', style: headerStyle, banglaStyle: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('কাস্টমার', style: headerStyle, banglaStyle: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('পদ্ধতি', style: headerStyle, banglaStyle: headerStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('মোট বিল', style: headerStyle, banglaStyle: headerStyle, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...todaySalesList.map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(sale['id'].toString().substring(0, 8).toUpperCase(), style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 10)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['time'] as String, style: regularStyle, banglaStyle: regularStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['customer'] as String, style: regularStyle, banglaStyle: regularStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['payment'] as String, style: regularStyle, banglaStyle: regularStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text('TK ${sale['amount']}', style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.Center(
              child: Text('ভিলেজকো স্টোর - দৈনিক লেনদেন রিপোর্ট ক্লোজিং সেশন', style: regularStyle, banglaStyle: regularStyle),
            ),
          ];
        },
      ),
    );
    return pdf;
  }

  static Future<String?> generateAndSaveDailyTransactionReport({
    required double todaySales,
    required double totalExpenses,
    required double netProfit,
    required int totalTransactionsCount,
    required List<Map<String, dynamic>> todaySalesList,
    String? customSavePath,
  }) async {
    final pdf = await _buildDailyReportPdfDocument(
      todaySales: todaySales,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      totalTransactionsCount: totalTransactionsCount,
      todaySalesList: todaySalesList,
    );

    final pdfBytes = await pdf.save();
    
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'দৈনিক ক্লোজিং রিপোর্ট');
      return tempFile.path;
    }
  }

  static Future<void> printTextProfitLoss({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
  }) async {
    final pdf = await _buildProfitLossPdfDocument(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'profit_loss_report',
    );
  }

  static Future<pw.Document> _buildSuppliersReportPdfDocument({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final regularStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.normal);
    final boldStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(font: defaultFont, fontSize: 16, fontWeight: pw.FontWeight.bold);
    final subTitleStyle = pw.TextStyle(font: defaultFont, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          final List<pw.Widget> children = [];

          // Header Title
          children.add(
            pw.Center(
              child: pw.Column(
                children: [
                  Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleStyle),
                  pw.SizedBox(height: 4),
                  Text('সরবরাহকারী স্টক ও লেনদেন রিপোর্ট ', style: subTitleStyle, banglaStyle: subTitleStyle),
                  pw.SizedBox(height: 4),
                  Text('তারিখ: ${Formatters.date(DateTime.now())} • সময়: ${Formatters.dateTime(DateTime.now()).split(" ").last}', style: regularStyle, banglaStyle: regularStyle),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.black),
                ],
              ),
            ),
          );
          children.add(pw.SizedBox(height: 12));

          for (final sup in suppliers) {
            final products = productsMap[sup.id] ?? [];
            final orders = ordersMap[sup.id] ?? [];
            final damages = damagesMap[sup.id] ?? [];

            double totalCost = 0;
            double totalPaid = 0;
            double quantityOrdered = 0;
            double quantityReceived = 0;
            for (final o in orders) {
              totalCost += o.totalCost;
              totalPaid += o.amountPaid;
              quantityOrdered += o.quantityOrdered;
              quantityReceived += o.quantityReceived;
            }
            final totalDue = totalCost - totalPaid;
            final quantityPending = quantityOrdered - quantityReceived;
            final totalDamages = damages.fold<double>(0, (sum, d) => sum + d.quantity);

            // Supplier Profile Summary block
            children.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    Text('সরবরাহকারী: ${sup.name}', style: subTitleStyle, banglaStyle: subTitleStyle),
                    Text('মোবাইল: ${sup.phone}${sup.email != null ? " | ইমেইল: " + sup.email! : ""}', style: regularStyle, banglaStyle: regularStyle),
                    if (sup.address != null) Text('ঠিকানা: ${sup.address}', style: regularStyle, banglaStyle: regularStyle),
                  ],
                ),
              ),
            );

            // 1. Transaction stats summary sub-table
            children.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোট বিল', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোট পরিশোধ', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বকেয়া পাওনা', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('অর্ডার পণ্য', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('রিসিভড পণ্য', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বাকি পণ্য', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ক্ষতিগ্রস্ত পণ্য', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.currency(totalCost), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.currency(totalPaid), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.currency(totalDue), style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.number(quantityOrdered), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.number(quantityReceived), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.number(quantityPending > 0 ? quantityPending : 0), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(Formatters.number(totalDamages), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                    ],
                  ),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 8));

            // 2. Supplied Products Table
            children.add(Text('সরবরাহকৃত পণ্য ও বর্তমান স্টক', style: boldStyle, banglaStyle: boldStyle));
            children.add(pw.SizedBox(height: 4));

            if (products.isEmpty) {
              children.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 12, bottom: 8), child: Text('কোনো পণ্য অ্যাসাইন করা নেই।', style: regularStyle, banglaStyle: regularStyle)));
            } else {
              children.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('পণ্যের নাম', style: boldStyle, banglaStyle: boldStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('বর্তমান স্টক', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('ক্রয় মূল্য', style: boldStyle, banglaStyle: boldStyle, textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    ...products.map((p) {
                      final isLow = p.currentStock <= p.minimumStock;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(p.name, style: regularStyle, banglaStyle: regularStyle)),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: Text(
                              '${Formatters.number(p.currentStock)} ${isLow ? "(নিম্ন স্টক)" : ""}',
                              style: isLow ? pw.TextStyle(font: defaultFont, fontSize: 8, color: PdfColors.red, fontWeight: pw.FontWeight.bold) : regularStyle,
                              banglaStyle: isLow ? pw.TextStyle(font: defaultFont, fontSize: 8, color: PdfColors.red, fontWeight: pw.FontWeight.bold) : regularStyle,
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(Formatters.currency(p.buyingPrice), style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right)),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }
            children.add(pw.SizedBox(height: 12));
            children.add(pw.Divider(thickness: 0.5, color: PdfColors.grey300));
            children.add(pw.SizedBox(height: 8));
          }

          return children;
        },
      ),
    );

    return pdf;
  }

  static Future<void> printSuppliersReport({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) async {
    final pdf = await _buildSuppliersReportPdfDocument(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'suppliers_stock_report',
    );
  }

  static Future<String?> generateAndSaveSuppliersReport({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
    String? customSavePath,
  }) async {
    final pdf = await _buildSuppliersReportPdfDocument(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );

    final pdfBytes = await pdf.save();
    
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/suppliers_stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    
    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/suppliers_stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Suppliers Stock & Transactions Report');
      return null;
    }
  }

  @visibleForTesting
  static Future<pw.Document> buildSuppliersReportPdfDocumentForTesting({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) {
    return _buildSuppliersReportPdfDocument(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );
  }
}
