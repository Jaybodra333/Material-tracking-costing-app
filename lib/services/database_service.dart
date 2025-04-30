import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/material_model.dart';

class DatabaseService {
  static Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'materials.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE materials(
            id TEXT PRIMARY KEY,
            name TEXT,
            barcode TEXT,
            unitCost REAL,
            quantity INTEGER,
            unit TEXT,
            category TEXT,
            processingCostPerUnit REAL,
            recommendedMargin REAL,
            minStockLevel INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE usage_logs(
            id TEXT PRIMARY KEY,
            material_id TEXT,
            operator_id TEXT,
            quantity INTEGER,
            timestamp INTEGER,
            is_synced INTEGER,
            product_name TEXT,
            batch_number TEXT
          )
        ''');

        // Create indices for faster searching
        await db.execute('CREATE INDEX idx_usage_timestamp ON usage_logs(timestamp)');
        await db.execute('CREATE INDEX idx_usage_material ON usage_logs(material_id)');
        await db.execute('CREATE INDEX idx_usage_product ON usage_logs(product_name)');

        // Add sync status table
        await db.execute('''
          CREATE TABLE sync_status(
            id INTEGER PRIMARY KEY,
            last_sync TIMESTAMP,
            entity_type TEXT,
            status TEXT
          )
        ''');        
      },
    );
  }

  Future<void> updateSyncStatus(String entityType, String status) async {
    final db = await database;
    await db.insert(
      'sync_status',
      {
        'entity_type': entityType,
        'status': status,
        'last_sync': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DateTime?> getLastSyncTime(String entityType) async {
    final db = await database;
    final result = await db.query(
      'sync_status',
      where: 'entity_type = ?',
      whereArgs: [entityType],
      orderBy: 'last_sync DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(result.first['last_sync'] as int);
    }
    return null;
  }

  Future<void> fullSync() async {
    if (!await _hasInternetConnection()) return;

    try {
      await syncMaterials();
      await syncUsageLogs();
      await updateSyncStatus('all', 'success');
    } catch (e) {
      await updateSyncStatus('all', 'error: $e');
      rethrow;
    }
  }

  Stream<QuerySnapshot> getRealtimeUpdates() {
    return _firestore.collection('materials')
        .where('lastUpdated', isGreaterThan: getLastSyncTime('materials'))
        .snapshots();
  }

  void startRealtimeSync() {
    getRealtimeUpdates().listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        switch (change.type) {
          case DocumentChangeType.added:
          case DocumentChangeType.modified:
            final material = MaterialModel.fromFirestore(change.doc);
            await _updateLocalMaterial(material);
            break;
          case DocumentChangeType.removed:
            await _deleteLocalMaterial(change.doc.id);
            break;
        }
      }
    });
  }

  Future<void> _updateLocalMaterial(MaterialModel material) async {
    final db = await database;
    await db.insert(
      'materials',
      {
        'id': material.id,
        ...material.toMap(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _deleteLocalMaterial(String id) async {
    final db = await database;
    await db.delete(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getConsumptionHistory({
    DateTime? startDate,
    DateTime? endDate,
    String? materialId,
    String? productName,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      whereClause += 'timestamp >= ? ';
      whereArgs.add(startDate.millisecondsSinceEpoch);
    }

    if (endDate != null) {
      whereClause += whereClause.isEmpty ? 'timestamp <= ? ' : 'AND timestamp <= ? ';
      whereArgs.add(endDate.millisecondsSinceEpoch);
    }

    if (materialId != null) {
      whereClause += whereClause.isEmpty ? 'material_id = ? ' : 'AND material_id = ? ';
      whereArgs.add(materialId);
    }

    if (productName != null) {
      whereClause += whereClause.isEmpty ? 'product_name LIKE ? ' : 'AND product_name LIKE ? ';
      whereArgs.add('%$productName%');
    }

    final logs = await db.query(
      'usage_logs',
      where: whereClause.isEmpty ? null : whereClause,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'timestamp DESC',
    );

    // Enrich logs with material details
    for (var log in logs) {
      final material = await getMaterialById(log['material_id'] as String);
      if (material != null) {
        log['material_name'] = material.name;
        log['material_unit'] = material.unit;
      }
    }

    return logs;
  }

  Future<MaterialModel?> getMaterialById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'materials',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return MaterialModel.fromMap(maps.first);
    }
    return null;
  }

  Future<void> checkLowStock() async {
    final db = await database;
    final lowStock = await db.query(
      'materials',
      where: 'quantity <= minStockLevel',
    );

    if (lowStock.isNotEmpty && await _hasInternetConnection()) {
      for (var material in lowStock) {
        await _firestore.collection('low_stock_alerts').add({
          'material_id': material['id'],
          'material_name': material['name'],
          'current_quantity': material['quantity'],
          'min_stock_level': material['minStockLevel'],
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> syncMaterials() async {
    if (!await _hasInternetConnection()) {
      print('No internet connection, skipping sync');
      return;
    }

    try {
      final materials = await _firestore.collection('materials').get();
      final db = await database;

      await db.transaction((txn) async {
        for (var doc in materials.docs) {
          final material = MaterialModel.fromFirestore(doc);
          await txn.insert(
            'materials',
            {
              'id': material.id,
              ...material.toMap(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } catch (e) {
      print('Error syncing materials: $e');
      rethrow;
    }
  }

  Future<List<MaterialModel>> getMaterials({bool forceOnline = false}) async {
    try {
      if (forceOnline && await _hasInternetConnection()) {
        final snapshot = await _firestore.collection('materials').get();
        return snapshot.docs.map((doc) => MaterialModel.fromFirestore(doc)).toList();
      }

      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('materials');

      return List.generate(maps.length, (i) {
        return MaterialModel(
          id: maps[i]['id'] ?? '',
          name: maps[i]['name'] ?? '',
          barcode: maps[i]['barcode'] ?? '',
          unitCost: (maps[i]['unitCost'] ?? 0.0).toDouble(),
          quantity: maps[i]['quantity'] ?? 0,
          unit: maps[i]['unit'] ?? '',
          category: maps[i]['category'] ?? '',
        );
      });
    } catch (e) {
      print('Error getting materials: $e');
      rethrow;
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  Future<MaterialModel?> getMaterialByBarcode(String barcode) async {
    print('Looking up barcode: $barcode'); // Debug log
    try {
      // First check local database
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'materials',
        where: 'barcode = ?',
        whereArgs: [barcode],
      );

      print('Local database result: ${maps.isNotEmpty ? "found" : "not found"}'); // Debug log

      MaterialModel? material;
      if (maps.isNotEmpty) {
        material = MaterialModel(
          id: maps[0]['id'],
          name: maps[0]['name'],
          barcode: maps[0]['barcode'],
          unitCost: (maps[0]['unitCost'] ?? 0.0).toDouble(),
          quantity: maps[0]['quantity'] ?? 0,
          unit: maps[0]['unit'] ?? '',
          category: maps[0]['category'] ?? '',
          processingCostPerUnit: (maps[0]['processingCostPerUnit'] ?? 0.0).toDouble(),
          recommendedMargin: (maps[0]['recommendedMargin'] ?? 20.0).toDouble(),
        );
      }

      // If not found locally, check Firestore
      if (material == null) {
        print('Checking Firestore for barcode: $barcode'); // Debug log
        if (await _hasInternetConnection()) {
          try {
            final snapshot = await _firestore
                .collection('materials')
                .where('barcode', isEqualTo: barcode)
                .get();

            print('Firestore query result count: ${snapshot.docs.length}'); // Debug log

            if (snapshot.docs.isNotEmpty) {
              final doc = snapshot.docs.first;
              material = MaterialModel.fromFirestore(doc);
              
              // Cache in local database
              await db.insert(
                'materials',
                {
                  'id': material.id,
                  ...material.toMap(),
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              print('Material cached in local database'); // Debug log
            }
          } catch (e) {
            print('Firestore lookup error: $e');
          }
        } else {
          print('No internet connection available');
        }
      }

      return material;
    } catch (e) {
      print('Error in getMaterialByBarcode: $e');
      rethrow;
    }
  }

  Future<void> syncUsageLogs() async {
    if (!await _hasInternetConnection()) return;

    final db = await database;
    try {
      final unsynced = await db.query(
        'usage_logs',
        where: 'is_synced = ?',
        whereArgs: [0],
      );

      for (var log in unsynced) {
        try {
          // Update Firestore material quantity
          final materialRef = _firestore.collection('materials').doc(log['material_id'] as String);
          
          await _firestore.runTransaction((transaction) async {
            final materialDoc = await transaction.get(materialRef);
            if (!materialDoc.exists) {
              throw Exception('Material not found in Firestore');
            }
            
            final currentQuantity = materialDoc.data()?['quantity'] ?? 0;
            final newQuantity = currentQuantity - (log['quantity'] as int);
            
            transaction.update(materialRef, {'quantity': newQuantity});
            
            // Add usage log to Firestore
            await _firestore.collection('usage_logs').doc(log['id'] as String).set({
              'material_id': log['material_id'],
              'operator_id': log['operator_id'],
              'quantity': log['quantity'],
              'timestamp': DateTime.fromMillisecondsSinceEpoch(log['timestamp'] as int),
            });
          });

          // Mark as synced in local DB
          await db.update(
            'usage_logs',
            {'is_synced': 1},
            where: 'id = ?',
            whereArgs: [log['id']],
          );
        } catch (e) {
          print('Error syncing individual log ${log['id']}: $e');
          // Continue with next log
        }
      }
    } catch (e) {
      print('Error in syncUsageLogs: $e');
      rethrow;
    }
  }

  Future<void> logMaterialUsage(
    String materialId,
    int quantity, {
    String? productName,
    String? batchNumber,
  }) async {
    final db = await database;
    
    try {
      final operatorId = FirebaseAuth.instance.currentUser?.uid;
      if (operatorId == null) {
        throw Exception('User not logged in');
      }

      // Get material and ensure it's not null before proceeding
      final material = await getMaterialById(materialId);
      
      if (material == null) {
        throw Exception('Material not found');
      }

      if (material.quantity < quantity) {
        throw Exception('Insufficient quantity available');
      }

      final usageLog = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'material_id': materialId,
        'operator_id': operatorId,
        'quantity': quantity,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
        'product_name': productName,
        'batch_number': batchNumber,
      };

      final newQuantity = material.quantity - quantity;

      await db.transaction((txn) async {
        await txn.insert('usage_logs', usageLog);
        
        final result = await txn.update(
          'materials',
          {'quantity': newQuantity},
          where: 'id = ?',
          whereArgs: [materialId],
        );
        
        if (result == 0) {
          throw Exception('Failed to update material quantity');
        }
      });

      // Try to sync immediately if online
      if (await _hasInternetConnection()) {
        await syncUsageLogs();
      }

    } catch (e) {
      print('Error in logMaterialUsage: $e');
      rethrow;
    }
  }
}
