import 'package:cloud_firestore/cloud_firestore.dart';
import './cost_calculation_model.dart';  // Add this import

class MaterialModel {
  final String id;
  final String name;
  final String barcode;
  final double unitCost;
  final int quantity;
  final String unit;
  final String category;
  final double processingCostPerUnit;
  final double recommendedMargin;

  MaterialModel({
    required this.id,
    required this.name,
    required this.barcode,
    required this.unitCost,
    required this.quantity,
    required this.unit,
    required this.category,
    this.processingCostPerUnit = 0.0,
    this.recommendedMargin = 20.0,
  });

  factory MaterialModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MaterialModel(
      id: doc.id,
      name: data['name'] ?? '',
      barcode: data['barcode'] ?? '',
      unitCost: (data['unitCost'] ?? 0.0).toDouble(),
      quantity: data['quantity'] ?? 0,
      unit: data['unit'] ?? '',
      category: data['category'] ?? '',
      processingCostPerUnit: (data['processingCostPerUnit'] ?? 0.0).toDouble(),
      recommendedMargin: (data['recommendedMargin'] ?? 20.0).toDouble(),
    );
  }

  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      barcode: map['barcode'] ?? '',
      unitCost: (map['unitCost'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 0,
      unit: map['unit'] ?? '',
      category: map['category'] ?? '',
      processingCostPerUnit: (map['processingCostPerUnit'] ?? 0.0).toDouble(),
      recommendedMargin: (map['recommendedMargin'] ?? 20.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'barcode': barcode,
      'unitCost': unitCost,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'processingCostPerUnit': processingCostPerUnit,
      'recommendedMargin': recommendedMargin,
    };
  }

  CostCalculation calculateCosts(int quantity) {
    return CostCalculation(
      rawMaterialCost: unitCost * quantity,
      processingCost: processingCostPerUnit * quantity,
      quantity: quantity,
      desiredMarginPercentage: recommendedMargin,
    );
  }
}
