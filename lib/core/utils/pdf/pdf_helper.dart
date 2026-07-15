import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:bangla_pdf/bangla_pdf.dart';
import '../formatters.dart';

class PdfHelper {
  static pw.Widget currencyText(
    double amount, {
    required pw.TextStyle style,
    bool isBold = false,
    pw.TextAlign textAlign = pw.TextAlign.left,
  }) {
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

  static pw.Widget buildItemTotalWidget(String totalStr, pw.TextStyle style) {
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

  static Future<Directory> getCsvSaveDirectory(String? customSavePath) {
    return getSaveDirectory(
      customSavePath,
      defaultSubfolder: 'VillageCO/CSVs',
    );
  }

  static Future<Directory> getSaveDirectory(
    String? customSavePath, {
    required String defaultSubfolder,
  }) async {
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
}
