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

class DamagedItemPdfGenerator {
  static Future<pw.Document> buildDamagedItemPdfDocument({
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
                    Text(
                      'ভিলেজকো স্টোর',
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text(
                          'ক্ষতিগ্রস্ত পণ্য বিবরণী ',
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                        pw.Text(
                          '(Damaged Item Record)',
                          style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
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

              Text(
                'সরবরাহকারী তথ্য (Supplier Information)',
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'নাম (Name)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(supplier.name, fontSize: 9),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মোবাইল (Phone)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(supplier.phone, fontSize: 9),
                      ),
                    ],
                  ),
                  if (supplier.email != null && supplier.email!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            'ইমেইল (Email)',
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(supplier.email!, fontSize: 9),
                        ),
                      ],
                    ),
                  if (supplier.address != null && supplier.address!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            'ঠিকানা (Address)',
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(supplier.address!, fontSize: 9),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 20),

              Text(
                'রেকর্ড বিবরণ (Record Details)',
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
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
                          'তথ্যাদি (Details)',
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
                        child: Text('পণ্য (Product)', fontSize: 9),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(product.name, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text('ক্ষতির পরিমাণ (Qty Damaged)', fontSize: 9),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            '${Formatters.number(damage.quantity)} ${product.unit}',
                            fontSize: 9,
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
                          'বর্তমান স্ট্যাটাস (Status)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            damage.status == 'Pending'
                                ? 'Pending (অমীমাংসিত)'
                                : 'Resolved (মীমাংসিত)',
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
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text(
                            'নিষ্পত্তির তারিখ (Resolution Date)',
                            fontSize: 9,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: Text(
                              Formatters.dateTime(damage.resolutionDate!),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (damage.notes != null && damage.notes!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text('মন্তব্য (Notes/Remarks)', fontSize: 9),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: Text(damage.notes!, fontSize: 9),
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 40),
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.Center(
                child: Text(
                  'VillageCO Store Inventory & Supplier Management',
                  fontSize: 7,
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

  static Future<String?> generateAndSaveDamagedItemPdf({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) async {
    final pdf = await buildDamagedItemPdfDocument(
      damage: damage,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/damaged_item_${damage.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/damaged_item_${damage.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Damaged Item Record PDF');
      return null;
    }
  }

  static Future<void> printDamagedItem({
    required DamagedItem damage,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = await buildDamagedItemPdfDocument(
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
