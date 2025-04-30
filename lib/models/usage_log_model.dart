import 'package:cloud_firestore/cloud_firestore.dart';

class UsageLogModel {
  final String id;
  final String materialId;
  final String operatorId;
  final int quantity;
  final DateTime timestamp;
  final bool isSynced;

  UsageLogModel({
    required this.id,
    required this.materialId,
    required this.operatorId,
    required this.quantity,
    required this.timestamp,
    this.isSynced = false,
  });

  factory UsageLogModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UsageLogModel(
      id: doc.id,
      materialId: data['materialId'],
      operatorId: data['operatorId'],
      quantity: data['quantity'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'operatorId': operatorId,
      'quantity': quantity,
      'timestamp': timestamp,
    };
  }
}
