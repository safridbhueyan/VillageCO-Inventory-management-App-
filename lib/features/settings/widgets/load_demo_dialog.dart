import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/categories_controller.dart';
import '../../products/products_controller.dart';
import '../../reports/reports_controller.dart';
import '../../suppliers/suppliers_controller.dart';
import '../settings_controller.dart';

class LoadDemoDialog extends ConsumerStatefulWidget {
  const LoadDemoDialog({super.key});

  @override
  ConsumerState<LoadDemoDialog> createState() => _LoadDemoDialogState();
}

class _LoadDemoDialogState extends ConsumerState<LoadDemoDialog> {
  bool isLoading = false;

  static const demoJson = '''
  {
    "categories": [
      {"id": "c1", "name": "পানীয় ও জুস", "icon": "local_cafe", "color": "0xFF008060"},
      {"id": "c2", "name": "নাস্তা ও চিপস", "icon": "fastfood", "color": "0xFFFF8C00"},
      {"id": "c3", "name": "নিত্য প্রয়োজনীয়", "icon": "shopping_basket", "color": "0xFF4682B4"},
      {"id": "c4", "name": "চাল ও ডাল", "icon": "grass", "color": "0xFFDAA520"}
    ],
    "suppliers": [
      {"id": "s1", "name": "মেট্রো ডিস্ট্রিবিউশন লিঃ", "phone": "01711223344", "email": "info@metro.com", "address": "তেজগাঁও শিল্প এলাকা, ঢাকা"},
      {"id": "s2", "name": "গ্রিন ভ্যালি ট্রেডার্স", "phone": "01999998888", "email": "sales@greenvalley.com", "address": "খাতুনগঞ্জ, চট্টগ্রাম"},
      {"id": "s3", "name": "প্রাণ-আরএফএল গ্রুপ", "phone": "01822334455", "email": "sales@pranrfl.com", "address": "বাড্ডা, ঢাকা"},
      {"id": "s4", "name": "এসিআই কনজুমার ব্র্যান্ডস", "phone": "01911224466", "email": "customer@aci-bd.com", "address": "মতিঝিল, ঢাকা"}
    ],
    "customers": [
      {"id": "cust1", "name": "কামাল উদ্দিন", "phone": "01671112222", "email": "kamal@gmail.com", "address": "মিরপুর, ঢাকা"},
      {"id": "cust2", "name": "ফাতেমা বেগম", "phone": "01851234567", "email": "fatima@gmail.com", "address": "গুলশান, ঢাকা"}
    ],
    "products": [
      {"id": "p1", "name": "কোকাকোলা ২৫০ মিলি", "barcode": "88010203040", "categoryId": "c1", "brand": "কোকাকোলা", "buyingPrice": 30.00, "sellingPrice": 35.00, "currentStock": 120.0, "minimumStock": 30.0, "unit": "pcs", "supplierId": "s1", "description": "কোকাকোলা সফট ড্রিংক ক্যান।", "imageUrl": "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p2", "name": "স্প্রাইট ২৫০ মিলি", "barcode": "88010203045", "categoryId": "c1", "brand": "কোকাকোলা", "buyingPrice": 30.00, "sellingPrice": 35.00, "currentStock": 80.0, "minimumStock": 20.0, "unit": "pcs", "supplierId": "s1", "description": "স্প্রাইট সফট ড্রিংক।", "imageUrl": "https://images.unsplash.com/photo-1625772290748-160b6160168f?q=80&w=400", "isArchived": false, "isFavorite": false},
      {"id": "p3", "name": "বসুন্ধরা আটা ২ কেজি", "barcode": "88010203052", "categoryId": "c4", "brand": "বসুন্ধরা", "buyingPrice": 120.00, "sellingPrice": 135.00, "currentStock": 40.0, "minimumStock": 10.0, "unit": "bag", "supplierId": "s2", "description": "প্যাকেটজাত সাদা ময়দা/আটা।", "imageUrl": "https://images.unsplash.com/photo-1574316071802-0d684efa7bf5?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p4", "name": "মিনিকেট চাল ২৫ কেজি", "barcode": "88010203058", "categoryId": "c4", "brand": "রশিদ রাইস", "buyingPrice": 1600.00, "sellingPrice": 1750.00, "currentStock": 8.0, "minimumStock": 15.0, "unit": "bag", "supplierId": "s2", "description": "প্রিমিয়াম মিনিকেট চালের বস্তা।", "imageUrl": "https://images.unsplash.com/photo-1586201375761-83865001e31c?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p5", "name": "লেস পটেটো চিপস মাসালা", "barcode": "88010203061", "categoryId": "c2", "brand": "পেপসিকো", "buyingPrice": 18.00, "sellingPrice": 25.00, "currentStock": 15.0, "minimumStock": 25.0, "unit": "pcs", "supplierId": "s1", "description": "লেস ম্যাজিক মাসালা চিপস।", "imageUrl": "https://images.unsplash.com/photo-1566478989037-eec170784d0b?q=80&w=400", "isArchived": false, "isFavorite": false},
      {"id": "p6", "name": "লিপটন ব্ল্যাক টি ১০০ ব্যাগ", "barcode": "88010203070", "categoryId": "c3", "brand": "ইউনিলিভার", "buyingPrice": 220.00, "sellingPrice": 270.00, "currentStock": 25.0, "minimumStock": 5.0, "unit": "pcs", "supplierId": "s1", "description": "লিপটন ব্ল্যাক টি ব্যাগ।", "imageUrl": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?q=80&w=400", "isArchived": false, "isFavorite": false},
      {"id": "p7", "name": "প্রাণ ফ্রুটো ২৫০ মিলি", "barcode": "88010203080", "categoryId": "c1", "brand": "প্রাণ", "buyingPrice": 15.00, "sellingPrice": 20.00, "currentStock": 150.0, "minimumStock": 40.0, "unit": "pcs", "supplierId": "s3", "description": "প্রাণ ম্যাঙ্গো ফ্রুট ড্রিংক।", "imageUrl": "https://images.unsplash.com/photo-1600271886742-f049cd451bba?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p8", "name": "রুচি চানাচুর ৩৫০ গ্রাম", "barcode": "88010203085", "categoryId": "c2", "brand": "স্কয়ার", "buyingPrice": 65.00, "sellingPrice": 75.00, "currentStock": 60.0, "minimumStock": 15.0, "unit": "pcs", "supplierId": "s3", "description": "রুচি ঝাল চানাচুর প্যাকেট।", "imageUrl": "https://images.unsplash.com/photo-1601050690597-df056fb4ce78?q=80&w=400", "isArchived": false, "isFavorite": false},
      {"id": "p9", "name": "এসিআই পিওর লবণ ১ কেজি", "barcode": "88010203090", "categoryId": "c3", "brand": "এসিআই", "buyingPrice": 35.00, "sellingPrice": 42.00, "currentStock": 90.0, "minimumStock": 20.0, "unit": "pcs", "supplierId": "s4", "description": "আয়োডিনযুক্ত এসিআই পিওর লবণ।", "imageUrl": "https://images.unsplash.com/photo-1594911774802-8822a7079af1?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p10", "name": "ড্যানিশ কনডেন্সড মিল্ক", "barcode": "88010203095", "categoryId": "c3", "brand": "ড্যানিশ", "buyingPrice": 70.00, "sellingPrice": 80.00, "currentStock": 45.0, "minimumStock": 12.0, "unit": "pcs", "supplierId": "s4", "description": "ড্যানিশ সুইটেন্ড কনডেন্সড মিল্ক।", "imageUrl": "https://images.unsplash.com/photo-1563636619-e9143da7973b?q=80&w=400", "isArchived": false, "isFavorite": false},
      {"id": "p11", "name": "চাষী সুগন্ধি পোলাও চাল ২ কেজি", "barcode": "88010203100", "categoryId": "c4", "brand": "এসিআই", "buyingPrice": 270.00, "sellingPrice": 300.00, "currentStock": 30.0, "minimumStock": 8.0, "unit": "bag", "supplierId": "s4", "description": "চাষী চিনিগুঁড়া সুগন্ধি পোলাও চাল।", "imageUrl": "https://images.unsplash.com/photo-1586201375761-83865001e31c?q=80&w=400", "isArchived": false, "isFavorite": true},
      {"id": "p12", "name": "ডোভ সাবান ৭৫ গ্রাম", "barcode": "88010203110", "categoryId": "c3", "brand": "ইউনিলিভার", "buyingPrice": 85.00, "sellingPrice": 100.00, "currentStock": 50.0, "minimumStock": 10.0, "unit": "pcs", "supplierId": "s1", "description": "ডোভ বিউটি ময়েশ্চারাইজিং বার।", "imageUrl": "https://images.unsplash.com/photo-1607006342411-985f1635f729?q=80&w=400", "isArchived": false, "isFavorite": false}
    ]
  }
  ''';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isLoading,
      child: AlertDialog(
        title: const Text('ডেমো ডেটা লোড করবেন?'),
        content: isLoading
            ? const SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('ডেমো ডেটা লোড হচ্ছে, অনুগ্রহ করে অপেক্ষা করুন...'),
                    ],
                  ),
                ),
              )
            : const Text('সতর্কতা: এটি করলে আপনার বর্তমান পণ্য, ক্যাটাগরি এবং বিক্রির হিসাব মুছে যাবে এবং পরীক্ষামূলক নতুন ডেমো পণ্যের তালিকা লোড হবে।'),
        actions: isLoading
            ? []
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('বাতিল'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setState(() => isLoading = true);
                    try {
                      await ref.read(settingsControllerProvider.notifier).importFromJson(demoJson);
                      ref.invalidate(productsListProvider);
                      ref.invalidate(categoriesControllerProvider);
                      ref.invalidate(suppliersControllerProvider);
                      ref.invalidate(salesHistoryProvider);
                      ref.invalidate(dashboardMetricsProvider);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ডেমো পণ্যের ডেটাসেট লোড সম্পন্ন হয়েছে! ড্যাশবোর্ড দেখুন।')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ডেমো ডেটা লোড ব্যর্থ: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('ডেমো ডেটা লোড'),
                ),
              ],
      ),
    );
  }
}
