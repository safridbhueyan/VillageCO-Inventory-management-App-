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
              Text('রশিদ নং: ${saleId.substring(0, 8).toUpperCase()}', style: regularStyle, banglaStyle: regularStyle),
              Text('তারিখ ও সময়: $dateStr', style: regularStyle, banglaStyle: regularStyle),
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
                      pw.Expanded(flex: 2, child: Text(item['qty'] as String, style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.center)),
                      pw.Expanded(flex: 2, child: Text(item['total'] as String, style: regularStyle, banglaStyle: regularStyle, textAlign: pw.TextAlign.right)),
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
                  Text('TK ${subtotal.toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ডিসকাউন্ট ছাড়:', style: regularStyle, banglaStyle: regularStyle),
                    Text('-TK ${discount.toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle),
                  ],
                ),
              ],
              pw.Divider(thickness: 0.8, color: PdfColors.grey600, borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5])),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text('পরিশোধযোগ্য মোট বিল:', style: totalStyle, banglaStyle: totalStyle),
                  Text('TK ${total.toStringAsFixed(2)}', style: totalStyle, banglaStyle: totalStyle),
                ],
              ),
              if (paidAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('পরিশোধিত টাকা:', style: regularStyle, banglaStyle: regularStyle),
                    Text('TK ${paidAmount.toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ফেরতযোগ্য টাকা:', style: regularStyle, banglaStyle: regularStyle),
                    Text('TK ${(paidAmount - total < 0 ? 0.0 : paidAmount - total).toStringAsFixed(2)}', style: regularStyle, banglaStyle: regularStyle),
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

  static Future<void> generateAndSaveTextReceipt({
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
    
    final file = File('${downloadsDir.path}/receipt_${saleId.substring(0, 8)}.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Receipt from VillageCO Store');
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

  static Future<void> generateAndSaveTextProfitLoss({
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
    
    final file = File('${downloadsDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes);
    await Share.shareXFiles([XFile(file.path)], text: 'Profit & Loss Report');
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
}
