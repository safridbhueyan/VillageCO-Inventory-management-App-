import 'dart:io';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../../features/products/products_controller.dart';

class CsvHelper {
  // RFC 4180 compliant CSV Encoder
  static String toCsvValue(dynamic val) {
    if (val == null) return '';
    String str = val.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  static String exportProductsToCsv(List<ProductWithDetails> products) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln('ID,Name,Barcode,Brand,Buying Price,Selling Price,Current Stock,Minimum Stock,Unit,Description');
    
    for (final pWithDetails in products) {
      final p = pWithDetails.product;
      final row = [
        p.id,
        p.name,
        p.barcode ?? '',
        p.brand ?? '',
        p.buyingPrice,
        p.sellingPrice,
        p.currentStock,
        p.minimumStock,
        p.unit,
        p.description ?? ''
      ];
      buffer.writeln(row.map(toCsvValue).join(','));
    }
    
    return buffer.toString();
  }

  static String exportSalesToCsv(List<Sale> sales) {
    final buffer = StringBuffer();
    buffer.writeln('Sale ID,Date,Subtotal,Discount,Total,Payment Method,Customer ID');
    
    for (final s in sales) {
      final row = [
        s.id,
        s.date.toIso8601String(),
        s.subtotal,
        s.discount,
        s.total,
        s.paymentMethod,
        s.customerId ?? ''
      ];
      buffer.writeln(row.map(toCsvValue).join(','));
    }
    
    return buffer.toString();
  }

  // RFC 4180 compliant CSV Decoder
  static List<List<String>> parseCsv(String csvText) {
    List<List<String>> result = [];
    List<String> currentRow = [];
    StringBuffer currentField = StringBuffer();
    bool inQuotes = false;
    
    for (int i = 0; i < csvText.length; i++) {
      int char = csvText.codeUnitAt(i);
      int nextChar = i + 1 < csvText.length ? csvText.codeUnitAt(i + 1) : 0;
      
      if (char == 34) { // double quote (")
        if (inQuotes && nextChar == 34) {
          currentField.write('"');
          i++; // skip next quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == 44 && !inQuotes) { // comma (,)
        currentRow.add(currentField.toString());
        currentField.clear();
      } else if ((char == 10 || char == 13) && !inQuotes) { // newline (\n or \r)
        if (char == 13 && nextChar == 10) {
          i++; // skip linefeed
        }
        currentRow.add(currentField.toString());
        currentField.clear();
        if (currentRow.isNotEmpty && (currentRow.length > 1 || currentRow[0].isNotEmpty)) {
          result.add(List.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentField.writeCharCode(char);
      }
    }
    
    if (currentField.length > 0 || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString());
      result.add(currentRow);
    }
    
    return result;
  }

  static List<ProductsCompanion> importProductsFromCsv(String csvText) {
    final rows = parseCsv(csvText);
    final List<ProductsCompanion> list = [];
    if (rows.isEmpty || rows.length <= 1) return list;
    
    // Skip header row at index 0
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 2) continue; // Must have at least ID and Name
      
      final id = row[0].trim();
      final name = row[1].trim();
      if (name.isEmpty) continue;
      
      final barcode = row.length > 2 && row[2].isNotEmpty ? row[2].trim() : null;
      final brand = row.length > 3 && row[3].isNotEmpty ? row[3].trim() : null;
      final buyPrice = row.length > 4 ? double.tryParse(row[4].trim()) ?? 0.0 : 0.0;
      final sellPrice = row.length > 5 ? double.tryParse(row[5].trim()) ?? 0.0 : 0.0;
      final currStock = row.length > 6 ? double.tryParse(row[6].trim()) ?? 0.0 : 0.0;
      final minStock = row.length > 7 ? double.tryParse(row[7].trim()) ?? 0.0 : 0.0;
      final unit = row.length > 8 && row[8].isNotEmpty ? row[8].trim() : 'pcs';
      final desc = row.length > 9 && row[9].isNotEmpty ? row[9].trim() : null;
      
      list.add(ProductsCompanion(
        id: drift.Value(id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString() + i.toString()),
        name: drift.Value(name),
        barcode: drift.Value(barcode),
        brand: drift.Value(brand),
        buyingPrice: drift.Value(buyPrice),
        sellingPrice: drift.Value(sellPrice),
        currentStock: drift.Value(currStock),
        minimumStock: drift.Value(minStock),
        unit: drift.Value(unit),
        description: drift.Value(desc),
      ));
    }
    
    return list;
  }
}
