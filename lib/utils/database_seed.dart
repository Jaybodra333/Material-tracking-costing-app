import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseSeed {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> seedMaterialsData() async {
    final materials = [
      {
        'barcode': 'M-RAW-12345-8',
        'name': 'Steel Rod',
        'unitCost': 10.0,
        'quantity': 100,
        'unit': 'PCS',
        'category': 'RAW',
        'processingCostPerUnit': 2.0,
        'recommendedMargin': 20.0,
        'minStockLevel': 20,
      },
      {
        'barcode': 'M-RAW-23456-9',
        'name': 'Aluminum Sheet',
        'unitCost': 15.0,
        'quantity': 50,
        'unit': 'SHT',
        'category': 'RAW',
        'processingCostPerUnit': 3.0,
        'recommendedMargin': 25.0,
        'minStockLevel': 10,
      },
      {
        'barcode': 'M-PCK-34567-0',
        'name': 'Cardboard Box',
        'unitCost': 5.0,
        'quantity': 200,
        'unit': 'BOX',
        'category': 'PACKAGING',
        'processingCostPerUnit': 1.0,
        'recommendedMargin': 15.0,
        'minStockLevel': 50,
      }
    ];

    final batch = _firestore.batch();
    
    for (final material in materials) {
      final docRef = _firestore.collection('materials').doc();
      batch.set(docRef, material);
    }

    await batch.commit();
    print('Test materials seeded successfully');
  }
}
