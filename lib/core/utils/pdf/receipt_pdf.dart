import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:bangla_pdf/bangla_pdf.dart';
import 'pdf_helper.dart';

class ReceiptPdfGenerator {
  static Future<pw.Document> buildReceiptPdfDocument({
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
    final regularStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 7,
      fontWeight: pw.FontWeight.normal,
    );
    final regularBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 7,
      fontWeight: pw.FontWeight.normal,
    );
    final titleStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final titleBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final totalStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final totalBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final thankYouStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
    );
    final thankYouBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    Text(
                      'ভিলেজকো স্টোর',
                      style: titleStyle,
                      banglaStyle: titleBanglaStyle,
                    ),
                    Text(
                      'মুদি দোকান ও পিওএস কেন্দ্র',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    Text(
                      'মোবাইল: +৮৮০১৭০০০০০০০০',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Divider(
                      thickness: 0.8,
                      color: PdfColors.grey600,
                      borderStyle: const pw.BorderStyle(
                        pattern: <num>[1.5, 1.5],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              Text(
                'রশিদ নং: ${saleId.substring(0, 8).toUpperCase()}',
                style: regularStyle,
                banglaStyle: regularBanglaStyle,
              ),
              Text(
                'তারিখ ও সময়: $dateStr',
                style: regularStyle,
                banglaStyle: regularBanglaStyle,
              ),
              Text(
                'পেমেন্ট পদ্ধতি: $paymentMethod',
                style: regularStyle,
                banglaStyle: regularBanglaStyle,
              ),
              Text(
                'ক্রেতার নাম: $customerName',
                style: regularStyle,
                banglaStyle: regularBanglaStyle,
              ),
              pw.SizedBox(height: 4),
              pw.Divider(
                thickness: 0.8,
                color: PdfColors.grey600,
                borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5]),
              ),

              // Product headers
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    flex: 5,
                    child: Text(
                      'পণ্যের বিবরণ',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: Text(
                      'পরিমাণ',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: Text(
                      'মোট টাকা',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.Divider(
                thickness: 0.8,
                color: PdfColors.grey600,
                borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5]),
              ),

              // Items list
              ...items.map((item) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 5,
                        child: Text(
                          item['name'] as String,
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                        ),
                      ),
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
                          child: PdfHelper.buildItemTotalWidget(
                            item['total'] as String,
                            regularStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(
                thickness: 0.8,
                color: PdfColors.grey600,
                borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5]),
              ),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'উপ-মোট বিল:',
                    style: regularStyle,
                    banglaStyle: regularBanglaStyle,
                  ),
                  PdfHelper.currencyText(subtotal, style: regularStyle),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ডিসকাউন্ট ছাড়:',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    PdfHelper.currencyText(-discount, style: regularStyle),
                  ],
                ),
              ],
              pw.Divider(
                thickness: 0.8,
                color: PdfColors.grey600,
                borderStyle: const pw.BorderStyle(pattern: <num>[1.5, 1.5]),
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'পরিশোধযোগ্য মোট বিল:',
                    style: totalStyle,
                    banglaStyle: totalBanglaStyle,
                  ),
                  PdfHelper.currencyText(total, style: totalStyle, isBold: true),
                ],
              ),
              if (paidAmount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'পরিশোধিত টাকা:',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    PdfHelper.currencyText(paidAmount, style: regularStyle),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ফেরতযোগ্য টাকা:',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    PdfHelper.currencyText(
                      paidAmount - total < 0 ? 0.0 : paidAmount - total,
                      style: regularStyle,
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 12),
              pw.Center(
                child: Text(
                  'ভিলেজকো স্টোরে কেনাকাটার জন্য ধন্যবাদ!',
                  style: thankYouStyle,
                  banglaStyle: thankYouBanglaStyle,
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
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
    final pdf = await buildReceiptPdfDocument(
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

    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/receipt_${saleId.substring(0, 8)}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/receipt_${saleId.substring(0, 8)}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Receipt from VillageCO Store');
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
    final pdf = await buildReceiptPdfDocument(
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
}
