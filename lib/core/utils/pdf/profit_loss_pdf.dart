import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:bangla_pdf/bangla_pdf.dart';
import '../formatters.dart';
import 'pdf_helper.dart';

class ProfitLossPdfGenerator {
  static Future<pw.Document> buildProfitLossPdfDocument({
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
                    Text(
                      'ভিলেজকো স্টোর',
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text(
                          'লাভ-ক্ষতি বিবরণী ',
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                        pw.Text(
                          '(Profit & Loss Statement)',
                          style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
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

              Text(
                'আজকের লাভ-ক্ষতি বিবরণী (Today\'s Financials)',
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
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
                          'বিবরণ (Description)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'টাকা (Amount)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'আজকের বিক্রয় রাজস্ব (Sales Revenue)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            todaySales,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'আজকের বিক্রীত পণ্যের খরচ (COGS)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            -todayCOGS,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'আজকের মোট লাভ (Gross Profit)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            todayGrossProfit,
                            style: const pw.TextStyle(fontSize: 9),
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'আজকের খরচ (Operating Expenses)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            -todayExpenses,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'আজকের নিট লাভ (Net Profit)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            todayNetProfit,
                            style: const pw.TextStyle(fontSize: 9),
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              Text(
                'সর্বমোট লাভ-ক্ষতি বিবরণী (All-Time Financials)',
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
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
                          'বিবরণ (Description)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'টাকা (Amount)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সর্বমোট বিক্রয় (Total Sales)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            totalSales,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সর্বমোট পণ্যের খরচ (Total COGS)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            -totalCOGS,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সর্বমোট মোট লাভ (Total Gross Profit)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            grossProfit,
                            style: const pw.TextStyle(fontSize: 9),
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সর্বমোট খরচ (Total Expenses)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            -totalExpenses,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'সর্বমোট নিট লাভ (Total Net Profit)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            netProfit,
                            style: const pw.TextStyle(fontSize: 9),
                            isBold: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
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
                          'সম্পদ বিবরণ (Asset)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'টাকা (Amount)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মজুদ পণ্যের মূল্য (Inventory Value)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            inventoryValue,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text(
                  'VillageCO Store Inventory & POS System',
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
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
    final pdf = await buildProfitLossPdfDocument(
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

    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/profit_loss_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Profit & Loss Report');
      return null;
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
    final pdf = await buildProfitLossPdfDocument(
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
}
