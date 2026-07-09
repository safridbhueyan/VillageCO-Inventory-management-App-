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
    final englishFont = pw.Font.helvetica();
    final regularStyle = pw.TextStyle(font: englishFont, fontSize: 7, fontWeight: pw.FontWeight.normal);
    final regularBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 7, fontWeight: pw.FontWeight.normal);
    final titleStyle = pw.TextStyle(font: englishFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final titleBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final totalStyle = pw.TextStyle(font: englishFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final totalBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final thankYouStyle = pw.TextStyle(font: englishFont, fontSize: 7, fontWeight: pw.FontWeight.bold);
    final thankYouBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 7, fontWeight: pw.FontWeight.bold);

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
                    Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleBanglaStyle),
                    Text('মুদি দোকান ও পিওএস কেন্দ্র', style: regularStyle, banglaStyle: regularBanglaStyle),
                    Text('মোবাইল: +৮৮০১৭০০০০০০০০', style: regularStyle, banglaStyle: regularBanglaStyle),
                    pw.SizedBox(height: 6),
                    pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              Text('রশিদ নং: ${saleId.substring(0, 8).toUpperCase()}', style: regularStyle, banglaStyle: regularBanglaStyle),
              Text('তারিখ ও সময়: $dateStr', style: regularStyle, banglaStyle: regularBanglaStyle),
              Text('পেমেন্ট পদ্ধতি: $paymentMethod', style: regularStyle, banglaStyle: regularBanglaStyle),
              Text('ক্রেতার নাম: $customerName', style: regularStyle, banglaStyle: regularBanglaStyle),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              
              // Product headers
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(flex: 5, child: Text('পণ্যের বিবরণ', style: regularStyle, banglaStyle: regularBanglaStyle)),
                  pw.Expanded(flex: 2, child: Text('পরিমাণ', style: regularStyle, banglaStyle: regularBanglaStyle, textAlign: pw.TextAlign.center)),
                  pw.Expanded(flex: 2, child: Text('মোট টাকা', style: regularStyle, banglaStyle: regularBanglaStyle, textAlign: pw.TextAlign.right)),
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
                      pw.Expanded(flex: 5, child: Text(item['name'] as String, style: regularStyle, banglaStyle: regularBanglaStyle)),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: Text(
                            item['qty'] as String,
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
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
                  Text('উপ-মোট বিল:', style: regularStyle, banglaStyle: regularBanglaStyle),
                  _currencyText(subtotal, style: regularStyle),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ডিসকাউন্ট ছাড়:', style: regularStyle, banglaStyle: regularBanglaStyle),
                    _currencyText(-discount, style: regularStyle),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text('পরিশোধযোগ্য মোট বিল:', style: totalStyle, banglaStyle: totalBanglaStyle),
                  _currencyText(total, style: totalStyle, isBold: true),
                ],
              ),
              if (paidAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('পরিশোধিত টাকা:', style: regularStyle, banglaStyle: regularBanglaStyle),
                    _currencyText(paidAmount, style: regularStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ফেরতযোগ্য টাকা:', style: regularStyle, banglaStyle: regularBanglaStyle),
                    _currencyText(paidAmount - total < 0 ? 0.0 : paidAmount - total, style: regularStyle),
                  ],
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Center(
                child: Text('ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!', style: thankYouStyle, banglaStyle: thankYouBanglaStyle),
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
    required double todayExpenses,
    required double todayGrossProfit,
    required double todayNetProfit,
    required double totalSales,
    required double todayCOGS,
    required double totalCOGS,
    required double grossProfit,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text('ভিলেজকো স্টোর', fontSize: 20, fontWeight: pw.FontWeight.bold),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text('লাভ-ক্ষতি বিবরণী ', fontSize: 12, color: PdfColors.grey700),
                        pw.Text('(Profit & Loss Statement)', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    Text(
                      'তারিখ ও সময়: ${Formatters.dateTime(DateTime.now())}',
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1, color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              
              Text('আজকের লাভ-ক্ষতি বিবরণী (Today\'s Financials)', fontSize: 12, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
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
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বিবরণ (Description)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('টাকা (Amount)', fontSize: 9, fontWeight: pw.FontWeight.bold, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('আজকের বিক্রয় রাজস্ব (Sales Revenue)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(todaySales, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('আজকের বিক্রীত পণ্যের খরচ (COGS)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(-todayCOGS, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('আজকের মোট লাভ (Gross Profit)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(todayGrossProfit, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('আজকের খরচ (Operating Expenses)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(-todayExpenses, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('আজকের নিট লাভ (Net Profit)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(todayNetProfit, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              Text('সর্বমোট লাভ-ক্ষতি বিবরণী (All-Time Financials)', fontSize: 12, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
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
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বিবরণ (Description)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('টাকা (Amount)', fontSize: 9, fontWeight: pw.FontWeight.bold, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সর্বমোট বিক্রয় (Total Sales)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(totalSales, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সর্বমোট পণ্যের খরচ (Total COGS)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(-totalCOGS, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সর্বমোট মোট লাভ (Total Gross Profit)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(grossProfit, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সর্বমোট খরচ (Total Expenses)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(-totalExpenses, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সর্বমোট নিট লাভ (Total Net Profit)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(netProfit, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                ],
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
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('সম্পদ বিবরণ (Asset)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('টাকা (Amount)', fontSize: 9, fontWeight: pw.FontWeight.bold, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মজুদ পণ্যের মূল্য (Inventory Value)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(inventoryValue, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 30),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text('VillageCO Store Inventory & POS System', fontSize: 8, color: PdfColors.grey600),
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
    required double todayExpenses,
    required double todayGrossProfit,
    required double todayNetProfit,
    required double totalSales,
    required double todayCOGS,
    required double totalCOGS,
    required double grossProfit,
    String? customSavePath,
  }) async {
    final pdf = await _buildProfitLossPdfDocument(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      todayExpenses: todayExpenses,
      todayGrossProfit: todayGrossProfit,
      todayNetProfit: todayNetProfit,
      totalSales: totalSales,
      todayCOGS: todayCOGS,
      totalCOGS: totalCOGS,
      grossProfit: grossProfit,
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
    final englishFont = pw.Font.helvetica();
    final regularStyle = pw.TextStyle(font: englishFont, fontSize: 10, fontWeight: pw.FontWeight.normal);
    final regularBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.normal);
    final titleStyle = pw.TextStyle(font: englishFont, fontSize: 18, fontWeight: pw.FontWeight.bold);
    final titleBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 18, fontWeight: pw.FontWeight.bold);
    final subTitleStyle = pw.TextStyle(font: englishFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final subTitleBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 12, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(font: englishFont, fontSize: 10, fontWeight: pw.FontWeight.bold);
    final headerBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 10, fontWeight: pw.FontWeight.bold);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleBanglaStyle),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      Text('দৈনিক লেনদেন রিপোর্ট ', style: subTitleStyle, banglaStyle: subTitleBanglaStyle),
                      pw.Text('(Daily Transaction Report)', style: subTitleStyle),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  Text(
                    'তারিখ: ${Formatters.date(DateTime.now())} | সময়: ${Formatters.dateTime(DateTime.now()).split(" ").last}',
                    style: regularStyle,
                    banglaStyle: regularBanglaStyle,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Divider(thickness: 1, color: PdfColors.black),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            
            // Financial Summary Block
            pw.Row(
              children: [
                Text('আর্থিক সারসংক্ষেপ ', style: subTitleStyle, banglaStyle: subTitleBanglaStyle),
                pw.Text('(Financial Summary)', style: subTitleStyle),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('খাত', style: headerStyle, banglaStyle: headerBanglaStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('পরিমাণ (টাকা)', style: headerStyle, banglaStyle: headerBanglaStyle, textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('আজকের মোট বিক্রি', style: regularStyle, banglaStyle: regularBanglaStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: _currencyText(todaySales, style: regularStyle, textAlign: pw.TextAlign.right),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('আজকের মোট খরচ', style: regularStyle, banglaStyle: regularBanglaStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: _currencyText(-totalExpenses, style: regularStyle, textAlign: pw.TextAlign.right),
                      ),
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
                      child: Text('আজকের নিট লাভ', style: headerStyle, banglaStyle: headerBanglaStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: _currencyText(netProfit, style: headerStyle, isBold: true, textAlign: pw.TextAlign.right),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text('মোট লেনদেন সংখ্যা', style: regularStyle, banglaStyle: regularBanglaStyle),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: Text(
                          '$totalTransactionsCount',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            
            // Transactions list
            pw.Row(
              children: [
                Text('আজকের বিক্রয় বিবরণী ', style: subTitleStyle, banglaStyle: subTitleBanglaStyle),
                pw.Text('(Today\'s Sales list)', style: subTitleStyle),
              ],
            ),
            pw.SizedBox(height: 8),
            if (todaySalesList.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: Text('আজকে কোনো বিক্রির লেনদেন হয়নি।', style: regularStyle, banglaStyle: regularBanglaStyle),
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
                        child: Text('রশিদ নং', style: headerStyle, banglaStyle: headerBanglaStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('সময়', style: headerStyle, banglaStyle: headerBanglaStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('কাস্টমার', style: headerStyle, banglaStyle: headerBanglaStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('পদ্ধতি', style: headerStyle, banglaStyle: headerBanglaStyle),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('মোট বিল', style: headerStyle, banglaStyle: headerBanglaStyle, textAlign: pw.TextAlign.right),
                      ),
                    ],
                  ),
                  ...todaySalesList.map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['id'].toString().substring(0, 8).toUpperCase(), style: regularStyle, banglaStyle: regularBanglaStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['time'] as String, style: regularStyle, banglaStyle: regularBanglaStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['customer'] as String, style: regularStyle, banglaStyle: regularBanglaStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(sale['payment'] as String, style: regularStyle, banglaStyle: regularBanglaStyle),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: _buildItemTotalWidget(sale['amount'] as String, regularStyle),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            pw.SizedBox(height: 40),
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.Center(
              child: Text('ভিলেজকো স্টোর - দৈনিক লেনদেন রিপোর্ট ক্লোজিং সেশন', style: regularStyle, banglaStyle: regularBanglaStyle),
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
      debugPrint('Saving PDF to downloads folder failed: $e. Trying fallback directory.');
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${fallbackDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await fallbackFile.writeAsBytes(pdfBytes);
        return fallbackFile.path;
      } catch (fallbackError) {
        debugPrint('Saving PDF to fallback folder failed: $fallbackError');
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await tempFile.writeAsBytes(pdfBytes);
        return tempFile.path;
      }
    }
  }

  static Future<void> printTextProfitLoss({
    required double todaySales,
    required double inventoryValue,
    required double totalExpenses,
    required double netProfit,
    required double todayExpenses,
    required double todayGrossProfit,
    required double todayNetProfit,
    required double totalSales,
    required double todayCOGS,
    required double totalCOGS,
    required double grossProfit,
  }) async {
    final pdf = await _buildProfitLossPdfDocument(
      todaySales: todaySales,
      inventoryValue: inventoryValue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      todayExpenses: todayExpenses,
      todayGrossProfit: todayGrossProfit,
      todayNetProfit: todayNetProfit,
      totalSales: totalSales,
      todayCOGS: todayCOGS,
      totalCOGS: totalCOGS,
      grossProfit: grossProfit,
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
    final englishFont = pw.Font.helvetica();
    final regularStyle = pw.TextStyle(font: englishFont, fontSize: 8, fontWeight: pw.FontWeight.normal);
    final regularBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.normal);
    final boldStyle = pw.TextStyle(font: englishFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final boldBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final titleStyle = pw.TextStyle(font: englishFont, fontSize: 16, fontWeight: pw.FontWeight.bold);
    final titleBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 16, fontWeight: pw.FontWeight.bold);
    final subTitleStyle = pw.TextStyle(font: englishFont, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final subTitleBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 11, fontWeight: pw.FontWeight.bold);
    final headerStyle = pw.TextStyle(font: englishFont, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final headerBanglaStyle = pw.TextStyle(font: defaultFont, fontSize: 8, fontWeight: pw.FontWeight.bold);

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
                  Text('ভিলেজকো স্টোর', style: titleStyle, banglaStyle: titleBanglaStyle),
                  pw.SizedBox(height: 4),
                  Text('সরবরাহকারী স্টক ও লেনদেন রিপোর্ট ', style: subTitleStyle, banglaStyle: subTitleBanglaStyle),
                  pw.SizedBox(height: 4),
                  Text(
                    'তারিখ: ${Formatters.date(DateTime.now())} | সময়: ${Formatters.dateTime(DateTime.now()).split(" ").last}',
                    style: regularStyle,
                    banglaStyle: regularBanglaStyle,
                  ),
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
                    Text('সরবরাহকারী: ${sup.name}', style: subTitleStyle, banglaStyle: subTitleBanglaStyle),
                    Text(
                      'মোবাইল: ${sup.phone}${sup.email != null ? ' | ইমেইল: ${sup.email}' : ''}',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    if (sup.address != null) Text('ঠিকানা: ${sup.address}', style: regularStyle, banglaStyle: regularBanglaStyle),
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
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোট বিল', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোট পরিশোধ', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বকেয়া পাওনা', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('অর্ডার পণ্য', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('রিসিভড পণ্য', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বাকি পণ্য', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ক্ষতিগ্রস্ত পণ্য', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.center)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: _buildItemTotalWidget(Formatters.currency(totalCost), regularStyle),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: _buildItemTotalWidget(Formatters.currency(totalPaid), regularStyle),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: _buildItemTotalWidget(Formatters.currency(totalDue), boldStyle),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: Text(
                            Formatters.number(quantityOrdered),
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: Text(
                            Formatters.number(quantityReceived),
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: Text(
                            Formatters.number(quantityPending > 0 ? quantityPending : 0),
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: Text(
                            Formatters.number(totalDamages),
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            children.add(pw.SizedBox(height: 8));

            // 2. Supplied Products Table
            children.add(Text('সরবরাহকৃত পণ্য ও বর্তমান স্টক', style: boldStyle, banglaStyle: boldBanglaStyle));
            children.add(pw.SizedBox(height: 4));

            if (products.isEmpty) {
              children.add(pw.Padding(padding: const pw.EdgeInsets.only(left: 12, bottom: 8), child: Text('কোনো পণ্য অ্যাসাইন করা নেই।', style: regularStyle, banglaStyle: regularBanglaStyle)));
            } else {
              children.add(
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('পণ্যের নাম', style: boldStyle, banglaStyle: boldBanglaStyle)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('বর্তমান স্টক', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text('ক্রয় মূল্য', style: boldStyle, banglaStyle: boldBanglaStyle, textAlign: pw.TextAlign.right)),
                      ],
                    ),
                    ...products.map((p) {
                      final isLow = p.currentStock <= p.minimumStock;
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: Text(p.name, style: regularStyle, banglaStyle: regularBanglaStyle)),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: Text(
                                '${Formatters.number(p.currentStock)}${isLow ? ' (নিম্ন স্টক)' : ''}',
                                style: isLow ? boldStyle.copyWith(color: PdfColors.red) : regularStyle,
                                banglaStyle: isLow ? boldBanglaStyle.copyWith(color: PdfColors.red) : regularBanglaStyle,
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: _buildItemTotalWidget(Formatters.currency(p.buyingPrice), regularStyle),
                            ),
                          ),
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

  static Future<pw.Document> _buildSupplierOrderPdfDocument({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text('ভিলেজকো স্টোর', fontSize: 20, fontWeight: pw.FontWeight.bold),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text('সরবরাহকারী অর্ডার মেমো ', fontSize: 12, color: PdfColors.grey700),
                        pw.Text('(Supplier Order Memo)', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    Text(
                      'অর্ডার আইডি: ${order.id}',
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                    Text(
                      'তারিখ: ${Formatters.dateTime(order.date)}',
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1, color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              
              Text('সরবরাহকারী তথ্য (Supplier Information)', fontSize: 11, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('নাম (Name)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.name, fontSize: 9)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোবাইল (Phone)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.phone, fontSize: 9)),
                    ],
                  ),
                  if (supplier.email != null && supplier.email!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ইমেইল (Email)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.email!, fontSize: 9)),
                      ],
                    ),
                  if (supplier.address != null && supplier.address!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ঠিকানা (Address)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.address!, fontSize: 9)),
                      ],
                    ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              Text('অর্ডার বিবরণ (Order Details)', fontSize: 11, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বিবরণ (Description)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('তথ্যাদি (Details)', fontSize: 9, fontWeight: pw.FontWeight.bold, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('পণ্য (Product)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text(product.name, fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('অর্ডার পরিমাণ (Qty Ordered)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text('${Formatters.number(order.quantityOrdered)} ${product.unit}', fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('গ্রহণকৃত পরিমাণ (Qty Received)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text('${Formatters.number(order.quantityReceived)} ${product.unit}', fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বাকি পরিমাণ (Qty Pending)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text('${Formatters.number(order.quantityOrdered - order.quantityReceived)} ${product.unit}', fontSize: 9))),
                    ],
                  ),
                  if (order.unitCost != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('একক মূল্য (Unit Cost)', fontSize: 9)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(order.unitCost!, style: const pw.TextStyle(fontSize: 9)))),
                      ],
                    ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোট খরচ (Total Cost)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(order.totalCost, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('পরিশোধিত অর্থ (Amount Paid)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(order.amountPaid, style: const pw.TextStyle(fontSize: 9)))),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বকেয়া (Amount Due)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: _currencyText(order.totalCost - order.amountPaid, style: const pw.TextStyle(fontSize: 9), isBold: true))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ডেলিভারি স্ট্যাটাস (Status)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            order.status == 'Received'
                                ? 'Received (পূর্ণ গ্রহণ)'
                                : (order.status == 'Partially Received' ? 'Partially (আংশিক গ্রহণ)' : 'Pending (অপেক্ষমান)'),
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 40),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text('VillageCO Store Inventory & Supplier Management', fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<String?> generateAndSaveSupplierOrderPdf({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) async {
    final pdf = await _buildSupplierOrderPdfDocument(
      order: order,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/supplier_order_${order.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf');

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/supplier_order_${order.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Supplier Order Receipt');
      return null;
    }
  }

  static Future<void> printSupplierOrder({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = await _buildSupplierOrderPdfDocument(
      order: order,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'supplier_order_${order.id.substring(0, 8)}',
    );
  }

  static Future<pw.Document> _buildDamagedItemPdfDocument({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text('ভিলেজকো স্টোর', fontSize: 20, fontWeight: pw.FontWeight.bold),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text('ক্ষতিগ্রস্ত পণ্য বিবরণী ', fontSize: 12, color: PdfColors.grey700),
                        pw.Text('(Damaged Item Record)', style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12, color: PdfColors.grey700)),
                      ],
                    ),
                    Text(
                      'ক্ষতিগ্রস্ত রেকর্ড আইডি: ${damage.id}',
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                    Text(
                      'তারিখ: ${Formatters.dateTime(damage.date)}',
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(thickness: 1, color: PdfColors.black),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              
              Text('সরবরাহকারী তথ্য (Supplier Information)', fontSize: 11, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('নাম (Name)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.name, fontSize: 9)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মোবাইল (Phone)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.phone, fontSize: 9)),
                    ],
                  ),
                  if (supplier.email != null && supplier.email!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ইমেইল (Email)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.email!, fontSize: 9)),
                      ],
                    ),
                  if (supplier.address != null && supplier.address!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ঠিকানা (Address)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text(supplier.address!, fontSize: 9)),
                      ],
                    ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              Text('রেকর্ড বিবরণ (Record Details)', fontSize: 11, fontWeight: pw.FontWeight.bold),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বিবরণ (Description)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('তথ্যাদি (Details)', fontSize: 9, fontWeight: pw.FontWeight.bold, textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('পণ্য (Product)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text(product.name, fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('ক্ষতির পরিমাণ (Qty Damaged)', fontSize: 9)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text('${Formatters.number(damage.quantity)} ${product.unit}', fontSize: 9))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('বর্তমান স্ট্যাটাস (Status)', fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            damage.status,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (damage.resolutionDate != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('নিষ্পত্তির তারিখ (Resolution Date)', fontSize: 9)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text(Formatters.dateTime(damage.resolutionDate!), fontSize: 9))),
                      ],
                    ),
                  if (damage.notes != null && damage.notes!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: Text('মন্তব্য (Notes/Remarks)', fontSize: 9)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Align(alignment: pw.Alignment.centerRight, child: Text(damage.notes!, fontSize: 9))),
                      ],
                    ),
                ],
              ),
              
              pw.SizedBox(height: 40),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text('VillageCO Store Inventory & Supplier Management', fontSize: 7, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<String?> generateAndSaveDamagedItemPdf({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) async {
    final pdf = await _buildDamagedItemPdfDocument(
      damage: damage,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    final downloadsDir = await _getSaveDirectory(customSavePath, defaultSubfolder: 'VillageCO/PDFs');
    final file = File('${downloadsDir.path}/damaged_item_${damage.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf');

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/damaged_item_${damage.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(tempFile.path)], text: 'Damaged Item Record PDF');
      return null;
    }
  }

  static Future<void> printDamagedItem({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = await _buildDamagedItemPdfDocument(
      damage: damage,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'damaged_item_${damage.id.substring(0, 8)}',
    );
  }
}
