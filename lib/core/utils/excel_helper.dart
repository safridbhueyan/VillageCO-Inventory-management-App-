import 'package:excel/excel.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../../features/products/products_controller.dart';


class ExcelHelper {
  static List<int>? exportProducts(List<ProductWithDetails> products) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet() ?? 'Sheet1'];
    
    // Add Headers
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Name'),
      TextCellValue('Barcode'),
      TextCellValue('Brand'),
      TextCellValue('Buying Price'),
      TextCellValue('Selling Price'),
      TextCellValue('Current Stock'),
      TextCellValue('Minimum Stock'),
      TextCellValue('Unit'),
      TextCellValue('Description'),
    ]);
    
    for (final pWithDetails in products) {
      final p = pWithDetails.product;
      sheet.appendRow([
        TextCellValue(p.id),
        TextCellValue(p.name),
        TextCellValue(p.barcode ?? ''),
        TextCellValue(p.brand ?? ''),
        DoubleCellValue(p.buyingPrice),
        DoubleCellValue(p.sellingPrice),
        DoubleCellValue(p.currentStock),
        DoubleCellValue(p.minimumStock),
        TextCellValue(p.unit),
        TextCellValue(p.description ?? ''),
      ]);
    }
    
    return excel.encode();
  }

  static List<ProductsCompanion> importProducts(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<ProductsCompanion> list = [];
    
    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows <= 1) continue;
      
      // Skip header row at index 0
      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        if (row.length < 2) continue; // Must have at least ID and Name
        
        final id = row[0]?.value?.toString() ?? '';
        final name = row[1]?.value?.toString() ?? '';
        if (name.isEmpty) continue; // Name is required
        
        final barcode = row.length > 2 ? row[2]?.value?.toString() : null;
        final brand = row.length > 3 ? row[3]?.value?.toString() : null;
        
        final buyPrice = row.length > 4 ? double.tryParse(row[4]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
        final sellPrice = row.length > 5 ? double.tryParse(row[5]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
        final currentStock = row.length > 6 ? double.tryParse(row[6]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
        final minStock = row.length > 7 ? double.tryParse(row[7]?.value?.toString() ?? '0') ?? 0.0 : 0.0;
        
        final unit = row.length > 8 ? row[8]?.value?.toString() ?? 'pcs' : 'pcs';
        final description = row.length > 9 ? row[9]?.value?.toString() : null;
        
        list.add(ProductsCompanion(
          id: drift.Value(id.isEmpty ? '${DateTime.now().microsecondsSinceEpoch}_$i' : id),
          name: drift.Value(name),
          barcode: drift.Value(barcode?.isEmpty == true ? null : barcode),
          brand: drift.Value(brand?.isEmpty == true ? null : brand),
          buyingPrice: drift.Value(buyPrice),
          sellingPrice: drift.Value(sellPrice),
          currentStock: drift.Value(currentStock),
          minimumStock: drift.Value(minStock),
          unit: drift.Value(unit.isEmpty ? 'pcs' : unit),
          description: drift.Value(description?.isEmpty == true ? null : description),
        ));
      }
    }
    
    return list;
  }
}
