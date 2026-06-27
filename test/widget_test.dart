// This is a basic Flutter widget test.
// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';
import 'package:villageco/main.dart';
import 'package:villageco/core/database/database.dart';
import 'package:villageco/core/database/database_providers.dart';
import 'package:villageco/features/products/products_controller.dart';

void main() {
  testWidgets('App loads and renders PIN login screen', (WidgetTester tester) async {
    // Set standard window size for the test environment
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Let the flutter_animate animations finish
    await tester.pump(const Duration(seconds: 1));

    // Verify that the login PIN terminal is displayed
    expect(find.text('অ্যাক্সেস করতে অ্যাডমিন পিন দিন'), findsOneWidget);

    // Reset size after test
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  test('ProductsRepository.addProduct inserts successfully into database', () async {
    // Initialize in-memory database for testing
    final db = AppDatabase(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final repo = container.read(productsRepositoryProvider);
    
    // Register a new product
    final id = const Uuid().v4();
    final product = ProductsCompanion(
      id: Value(id),
      name: const Value('Test Product'),
      buyingPrice: const Value(5.0),
      sellingPrice: const Value(10.0),
      currentStock: const Value(20.0),
      minimumStock: const Value(5.0),
      unit: const Value('pcs'),
      supplierId: const Value(null),
      categoryId: const Value(null),
    );

    // This should run without throwing any SQLite or null errors
    await repo.addProduct(product);

    final list = await db.select(db.products).get();
    expect(list.length, 1);
    expect(list.first.name, 'Test Product');
    expect(list.first.currentStock, 20.0);

    // Verify stock history entry was logged automatically
    final history = await db.select(db.stockHistory).get();
    expect(history.length, 1);
    expect(history.first.productId, id);
    expect(history.first.changeAmount, 20.0);
  });
}
