import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:bangla_pdf/bangla_pdf.dart';
import '../formatters.dart';
import 'package:villageco/features/supply_chain/supply_chain_controller.dart';

class SupplyChainOrderPdfGenerator {
  static Future<pw.Document> buildSupplyChainOrderPdfDocument(
    SupplyChainOrder order,
  ) async {
    final pdf = pw.Document();
    final defaultFont = BanglaFontManager().defaultFont;
    final englishFont = pw.Font.helvetica();

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
    final sectionHeaderStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final sectionHeaderBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    final regularStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 9,
      fontWeight: pw.FontWeight.normal,
    );
    final regularBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 9,
      fontWeight: pw.FontWeight.normal,
    );
    final boldStyle = pw.TextStyle(
      font: englishFont,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );
    final boldBanglaStyle = pw.TextStyle(
      font: defaultFont,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );

    String statusText = order.status;
    if (order.status == 'Pending Approval') statusText = 'অনুমোদনের অপেক্ষায়';
    if (order.status == 'Approved') statusText = 'অনুমোদিত';
    if (order.status == 'Rejected') statusText = 'প্রত্যাখ্যাত';

    String paymentStatusText = order.paymentStatus;
    if (order.paymentStatus == 'Paid') paymentStatusText = 'পরিশোধিত';
    if (order.paymentStatus == 'Unpaid') paymentStatusText = 'অপরিশোধিত';
    if (order.paymentStatus == 'Partially Paid')
      paymentStatusText = 'আংশিক পরিশোধিত';

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
                      style: titleStyle,
                      banglaStyle: titleBanglaStyle,
                    ),
                    pw.SizedBox(height: 4),
                    Text(
                      'শাখা টু শাখা পণ্য স্থানান্তর চালানপত্র',
                      style: regularStyle,
                      banglaStyle: regularBanglaStyle,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey800),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Store and Order Meta Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অর্ডার আইডি: ${order.id.substring(0, 8).toUpperCase()}',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                        pw.SizedBox(height: 2),
                        Text(
                          'তারিখ: ${Formatters.dateTime(order.createdAt)}',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                        ),
                        pw.SizedBox(height: 2),
                        Text(
                          'অবস্থা: $statusText',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                        pw.SizedBox(height: 2),
                        Text(
                          'পেমেন্ট অবস্থা: $paymentStatusText',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        Text(
                          'অনুরোধকারী শাখা (From): ${order.fromStoreName}',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                        pw.SizedBox(height: 4),
                        Text(
                          'সরবরাহকারী শাখা (To): ${order.toStoreName}',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 25),

              Text(
                'পণ্য স্থানান্তর বিবরণ:',
                style: sectionHeaderStyle,
                banglaStyle: sectionHeaderBanglaStyle,
              ),
              pw.SizedBox(height: 8),

              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // details
                  1: const pw.FlexColumnWidth(1.5), // barcode
                  2: const pw.FlexColumnWidth(1.2), // price
                  3: const pw.FlexColumnWidth(1), // requested
                  4: const pw.FlexColumnWidth(1), // sent
                  5: const pw.FlexColumnWidth(1), // received
                  6: const pw.FlexColumnWidth(1.3), // total
                },
                children: [
                  // Table Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'পণ্যের নাম',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'বারকোড',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'একক মূল্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'অনুরোধ',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'পাঠানো',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'গ্রহণ',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          'মোট মূল্য',
                          style: boldStyle,
                          banglaStyle: boldBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  // Table Item
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          order.productName,
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          order.productBarcode.isNotEmpty
                              ? order.productBarcode
                              : 'N/A',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          Formatters.currency(order.productSellingPrice),
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          '${order.quantityRequested} ${order.productUnit}',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          '${order.quantitySent} ${order.productUnit}',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          '${order.quantityReceived} ${order.productUnit}',
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: Text(
                          Formatters.currency(order.totalPrice),
                          style: regularStyle,
                          banglaStyle: regularBanglaStyle,
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 180,
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'মোট মূল্য:',
                              style: regularStyle,
                              banglaStyle: regularBanglaStyle,
                            ),
                            Text(
                              Formatters.currency(order.totalPrice),
                              style: regularStyle,
                              banglaStyle: regularBanglaStyle,
                            ),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'পরিশোধিত:',
                              style: regularStyle,
                              banglaStyle: regularBanglaStyle,
                            ),
                            Text(
                              Formatters.currency(order.amountPaid),
                              style: regularStyle,
                              banglaStyle: regularBanglaStyle,
                            ),
                          ],
                        ),
                        pw.Divider(thickness: 0.5),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'বকেয়া:',
                              style: boldStyle,
                              banglaStyle: boldBanglaStyle,
                            ),
                            Text(
                              Formatters.currency(order.paymentDue),
                              style: boldStyle,
                              banglaStyle: boldBanglaStyle,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 50),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 100,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 4),
                      Text(
                        'অনুরোধকারী স্বাক্ষর',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 100,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 4),
                      Text(
                        'সরবরাহকারী স্বাক্ষর',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 100,
                        height: 1,
                        color: PdfColors.grey600,
                      ),
                      pw.SizedBox(height: 4),
                      Text(
                        'সুপার অ্যাডমিন অনুমোদন',
                        style: regularStyle,
                        banglaStyle: regularBanglaStyle,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  static Future<void> printSupplyChainOrder(SupplyChainOrder order) async {
    final pdf = await buildSupplyChainOrderPdfDocument(order);
    final pdfBytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'supply_chain_${order.id.substring(0, 8)}',
    );
  }
}
