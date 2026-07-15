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

class SuppliersReportPdfGenerator {
  static Future<pw.Document> buildSuppliersReportPdfDocument({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();
    final regularStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.normal,
    );
    final regularBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.normal,
    );
    final boldStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final boldBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
    );
    final titleStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );
    final titleBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );
    final subTitleStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final subTitleBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );


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
                  Text(
                    'ভিলেজকো স্টোর',
                    style: titleStyle,
                    banglaStyle: titleBanglaStyle,
                  ),
                  pw.SizedBox(height: 4),
                  Text(
                    'সরবরাহকারী স্টক ও লেনদেন রিপোর্ট ',
                    style: subTitleStyle,
                    banglaStyle: subTitleBanglaStyle,
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
            final totalDamages = damages.fold<double>(
              0,
              (sum, d) => sum + d.quantity,
            );

            // Supplier Profile Summary block
            children.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 8),
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    Text(
                      'সরবরাহকারী: ${sup.name}',
                      style: subTitleStyle,
                      banglaStyle: subTitleBanglaStyle,
                    ),
                    Text(
                      'মোবাইল: ${sup.phone}${sup.email != null ? ' | ইমেইল: ${sup.email}' : ''}',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    if (sup.address != null)
                      Text(
                        'ঠিকানা: ${sup.address}',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                  ],
                ),
              ),
            );

            // 1. Transaction stats summary sub-table
            children.add(
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মোট বিল',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মোট পরিশোধ',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'বকেয়া পাওনা',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'অর্ডার পণ্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'রিসিভড পণ্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'বাকি পণ্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'ক্ষতিগ্রস্ত পণ্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: PdfHelper.buildItemTotalWidget(
                            Formatters.currency(totalCost),
                            regularStyle,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: PdfHelper.buildItemTotalWidget(
                            Formatters.currency(totalPaid),
                            regularStyle,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.center,
                          child: PdfHelper.buildItemTotalWidget(
                            Formatters.currency(totalDue),
                            boldStyle,
                          ),
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
                            Formatters.number(
                              quantityPending > 0 ? quantityPending : 0,
                            ),
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
            children.add(
              Text(
                'সরবরাহকৃত পণ্য ও বর্তমান স্টক',
                style: boldStyle,
                banglaStyle: boldBanglaStyle,
              ),
            );
            children.add(pw.SizedBox(height: 4));

            if (products.isEmpty) {
              children.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    'কোনো পণ্য অ্যাসাইন করা নেই।',
                    style: regularStyle,
                    banglaStyle: regularBanglaStyle,
                  ),
                ),
              );
            } else {
              children.add(
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: Text(
                            'পণ্যের নাম',
                            style: boldStyle,
                            banglaStyle: boldBanglaStyle,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: Text(
                            'বর্তমান স্টক',
                            style: boldStyle,
                            banglaStyle: boldBanglaStyle,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: Text(
                            'ক্রয় মূল্য',
                            style: boldStyle,
                            banglaStyle: boldBanglaStyle,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ...products.map((p) {
                      final isLow = p.currentStock <= p.minimumStock;
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: Text(
                              p.name,
                              style: regularStyle,
                              banglaStyle: regularBanglaStyle,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: Text(
                                '${Formatters.number(p.currentStock)}${isLow ? ' (নিম্ন স্টক)' : ''}',
                                style: isLow
                                    ? boldStyle.copyWith(color: PdfColors.red)
                                    : regularStyle,
                                banglaStyle: isLow
                                    ? boldBanglaStyle.copyWith(
                                        color: PdfColors.red,
                                      )
                                    : regularBanglaStyle,
                                textAlign: pw.TextAlign.right,
                              ),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Align(
                              alignment: pw.Alignment.centerRight,
                              child: PdfHelper.buildItemTotalWidget(
                                Formatters.currency(p.buyingPrice),
                                regularStyle,
                              ),
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
    final pdf = await buildSuppliersReportPdfDocument(
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
    final pdf = await buildSuppliersReportPdfDocument(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );

    final pdfBytes = await pdf.save();

    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/suppliers_stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/suppliers_stock_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Suppliers Stock & Transactions Report');
      return null;
    }
  }

  static Future<pw.Document> buildSuppliersReportPdfDocumentForTesting({
    required List<Supplier> suppliers,
    required Map<String, List<Product>> productsMap,
    required Map<String, List<SupplierOrder>> ordersMap,
    required Map<String, List<DamagedItem>> damagesMap,
  }) {
    return buildSuppliersReportPdfDocument(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );
  }
}
