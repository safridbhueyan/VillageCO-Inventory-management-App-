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

class SupplierOrderPdfGenerator {
  static Future<pw.Document> buildSupplierOrderPdfDocument({
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
                    Text(
                      'ভিলেজকো স্টোর',
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        Text(
                          'সরবরাহকারী অর্ডার মেমো ',
                          fontSize: 12,
                          color: PdfColors.grey700,
                        ),
                        pw.Text(
                          '(Supplier Order Memo)',
                          style: pw.TextStyle(
                            font: pw.Font.helvetica(),
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
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
                'অর্ডার বিবরণ (Order Details)',
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
                        child: Text('অর্ডার পরিমাণ (Qty Ordered)', fontSize: 9),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            '${Formatters.number(order.quantityOrdered)} ${product.unit}',
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
                          'গ্রহণকৃত পরিমাণ (Qty Received)',
                          fontSize: 9,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            '${Formatters.number(order.quantityReceived)} ${product.unit}',
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
                        child: Text('বাকি পরিমাণ (Qty Pending)', fontSize: 9),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            '${Formatters.number(order.quantityOrdered - order.quantityReceived)} ${product.unit}',
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (order.unitCost != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: Text('একক মূল্য (Unit Cost)', fontSize: 9),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Align(
                            alignment: pw.Alignment.centerRight,
                            child: PdfHelper.currencyText(
                              order.unitCost!,
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
                          'মোট খরচ (Total Cost)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            order.totalCost,
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
                        child: Text('পরিশোধিত অর্থ (Amount Paid)', fontSize: 9),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            order.amountPaid,
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
                          'বকেয়া (Amount Due)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: PdfHelper.currencyText(
                            order.totalCost - order.amountPaid,
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
                          'ডেলিভারি স্ট্যাটাস (Status)',
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerRight,
                          child: Text(
                            order.status == 'Received'
                                ? 'Received (পূর্ণ গ্রহণ)'
                                : (order.status == 'Partially Received'
                                      ? 'Partially (আংশিক গ্রহণ)'
                                      : 'Pending (অপেক্ষমান)'),
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

  static Future<String?> generateAndSaveSupplierOrderPdf({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
    String? customSavePath,
  }) async {
    final pdf = await buildSupplierOrderPdfDocument(
      order: order,
      supplier: supplier,
      product: product,
    );

    final pdfBytes = await pdf.save();
    final downloadsDir = await PdfHelper.getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/PDFs',
    );
    final file = File(
      '${downloadsDir.path}/supplier_order_${order.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    try {
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/supplier_order_${order.id.substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await tempFile.writeAsBytes(pdfBytes);
      await Share.shareXFiles([
        XFile(tempFile.path),
      ], text: 'Supplier Order Receipt');
      return null;
    }
  }

  static Future<void> printSupplierOrder({
    required SupplierOrder order,
    required Supplier supplier,
    required Product product,
  }) async {
    final pdf = await buildSupplierOrderPdfDocument(
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
}
