import 'package:cloud_firestore/cloud_firestore.dart';

class Medicine {
  final String id;
  final String medicineName;
  final String category;
  final String unit;
  final int quantity;
  final int minimumStock;
  final int criticalStock;
  final DateTime expiryDate;
  final String clinicId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;

  Medicine({
    required this.id,
    required this.medicineName,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.minimumStock,
    required this.criticalStock,
    required this.expiryDate,
    required this.clinicId,
    this.createdAt,
    this.updatedAt,
    required this.createdBy,
  });

  // Convert a Medicine object into Firestore data.
  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'minimumStock': minimumStock,
      'criticalStock': criticalStock,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'clinicId': clinicId,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': createdBy,
    };
  }

  // Convert Firestore data into a Medicine object.
  factory Medicine.fromMap(
    String documentId,
    Map<String, dynamic> data,
  ) {
    return Medicine(
      id: documentId,
      medicineName: data['medicineName'] ?? '',
      category: data['category'] ?? '',
      unit: data['unit'] ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      minimumStock:
          (data['minimumStock'] as num?)?.toInt() ?? 0,
      criticalStock:
          (data['criticalStock'] as num?)?.toInt() ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp).toDate(),
      clinicId: data['clinicId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }
}