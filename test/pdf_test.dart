import 'package:flutter_test/flutter_test.dart';
import 'package:villageco/core/database/database.dart';
import 'package:villageco/core/utils/pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test Suppliers Report PDF Generation', () async {
    final suppliers = [
      const Supplier(
        id: '1',
        name: 'সরবরাহকারী ১',
        phone: '01700000000',
        email: 'test@gmail.com',
        address: 'ঢাকা',
      ),
      const Supplier(
        id: '2',
        name: 'Empty Supplier',
        phone: '',
        email: null,
        address: null,
      ),
    ];

    final productsMap = {
      '1': [
        const Product(
          id: 'p1',
          name: 'আলু',
          buyingPrice: 20,
          sellingPrice: 25,
          currentStock: 10,
          minimumStock: 15,
          unit: 'kg',
          supplierId: '1',
          categoryId: null,
          isArchived: false,
          isFavorite: false,
        ),
      ],
      '2': <Product>[],
    };

    final ordersMap = {
      '1': [
        SupplierOrder(
          id: 'o1',
          supplierId: '1',
          productId: 'p1',
          quantityOrdered: 100,
          quantityReceived: 80,
          totalCost: 1600,
          amountPaid: 1200,
          date: DateTime.now(),
          status: 'Partially Received',
        ),
      ],
      '2': <SupplierOrder>[],
    };

    final damagesMap = {
      '1': [
        DamagedItem(
          id: 'd1',
          supplierId: '1',
          productId: 'p1',
          quantity: 5,
          status: 'Pending Replacement',
          date: DateTime.now(),
        ),
      ],
      '2': <DamagedItem>[],
    };

    final doc = await PdfGenerator.buildSuppliersReportPdfDocumentForTesting(
      suppliers: suppliers,
      productsMap: productsMap,
      ordersMap: ordersMap,
      damagesMap: damagesMap,
    );

    final bytes = await doc.save();
    expect(bytes, isNotEmpty);
  });
}
