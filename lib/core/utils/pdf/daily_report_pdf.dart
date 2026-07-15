import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bangla_pdf/bangla_pdf.dart';
import '../formatters.dart';
import 'pdf_helper.dart';

class DailyReportPdfGenerator {
  static Future<pw.Document> buildDailyReportPdfDocument({
    required double todaySales,
    required double totalExpenses,
    required double netProfit,
    required int totalTransactionsCount,
    required List<Map<String, dynamic>> todaySalesList,
  }) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();
    final regularStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 10,
      fontWeight: pw.FontWeight.normal,
    );
    final regularBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 10,
      fontWeight: pw.FontWeight.normal,
    );
    final titleStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    final titleBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 18,
      fontWeight: pw.FontWeight.bold,
    );
    final subTitleStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final subTitleBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
    );
    final headerStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );
    final headerBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Column(
                children: [
                  Text(
                    'ভিলেজকো স্টোর',
                    style: titleStyle,
                    banglaStyle: titleBanglaStyle,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      Text(
                        'দৈনিক লেনদেন রিপোর্ট ',
                        style: subTitleStyle,
                        banglaStyle: subTitleBanglaStyle,
                      ),
                      pw.Text(
                        '(Daily Transaction Report)',
                        style: subTitleStyle,
                      ),
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
                Text(
                  'আর্থিক সারসংক্ষেপ ',
                  style: subTitleStyle,
                  banglaStyle: subTitleBanglaStyle,
                ),
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
                      child: Text(
                        'খাত',
                        style: headerStyle,
                        banglaStyle: headerBanglaStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text(
                        'পরিমাণ (টাকা)',
                        style: headerStyle,
                        banglaStyle: headerBanglaStyle,
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text(
                        'আজকের মোট বিক্রি',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: PdfHelper.currencyText(
                          todaySales,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text(
                        'আজকের মোট খরচ',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: PdfHelper.currencyText(
                          -totalExpenses,
                          style: regularStyle,
                          textAlign: pw.TextAlign.right,
                        ),
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
                      child: Text(
                        'আজকের নিট লাভ',
                        style: headerStyle,
                        banglaStyle: headerBanglaStyle,
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Align(
                        alignment: pw.Alignment.centerRight,
                        child: PdfHelper.currencyText(
                          netProfit,
                          style: headerStyle,
                          isBold: true,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: Text(
                        'মোট লেনদেন সংখ্যা',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
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
                Text(
                  'আজকের বিক্রয় বিবরণী ',
                  style: subTitleStyle,
                  banglaStyle: subTitleBanglaStyle,
                ),
                pw.Text('(Today\'s Sales list)', style: subTitleStyle),
              ],
            ),
            pw.SizedBox(height: 8),
            if (todaySalesList.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: Text(
                  'আজকে কোনো বিক্রির লেনদেন হয়নি।',
                  style: regularStyle,
                  banglaStyle: regularBanglaStyle,
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'রশিদ নং',
                          style: headerStyle,
                          banglaStyle: headerBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সময়',
                          style: headerStyle,
                          banglaStyle: headerBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'কাস্টমার',
                          style: headerStyle,
                          banglaStyle: headerBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'পদ্ধতি',
                          style: headerStyle,
                          banglaStyle: headerBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মোট বিল',
                          style: headerStyle,
                          banglaStyle: headerBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  ...todaySalesList.map((sale) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            sale['id'].toString().substring(0, 8).toUpperCase(),
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            sale['time'] as String,
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            sale['customer'] as String,
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            sale['payment'] as String,
                            style: regularStyle,
                            banglaStyle: regularBanglaStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: PdfHelper.buildItemTotalWidget(
                              sale['amount'] as String,
                              regularStyle,
                            ),
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
              child: Text(
                'ভিলেজকো স্টোর - দৈনিক লেনদেন রিপোর্ট ক্লোজিং সেশন',
                style: regularStyle,
                banglaStyle: regularBanglaStyle,
              ),
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
    final pdf = await buildDailyReportPdfDocument(
      todaySales: todaySales,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      totalTransactionsCount: totalTransactionsCount,
      todaySalesList: todaySalesList,
    );

    final pdfBytes = await pdf.save();

    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      debugPrint(
        'Saving PDF to downloads folder failed: $e. Trying fallback directory.',
      );
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File(
          '${fallbackDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await fallbackFile.writeAsBytes(pdfBytes);
        return fallbackFile.path;
      } catch (fallbackError) {
        debugPrint('Saving PDF to fallback folder failed: $fallbackError');
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
          '${tempDir.path}/daily_closing_report_${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await tempFile.writeAsBytes(pdfBytes);
        return tempFile.path;
      }
    }
  }
}
