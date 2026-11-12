import 'package:cloud_firestore/cloud_firestore.dart';

/// One "Received" or "Issued" entry saved by the Record stock screen.
/// Stored in the `stockRecords` collection in Firestore.
class StockRecord {
  final String id;
  final String clinicId;
  final String medicineId;
  final String medicineName;
  final String unit;

  /// Either 'received' or 'issued'.
  final String type;
  final int quantity;

  /// Only used for issued stock (Patient use, Expired, Damaged, Transfer).
  final String? reason;

  /// The day the stock moved (chosen on the Record stock screen).
  final DateTime date;
  final String recordedBy;

  const StockRecord({
    required this.id,
    required this.clinicId,
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    required this.type,
    required this.quantity,
    required this.date,
    required this.recordedBy,
    this.reason,
  });

  bool get isReceived => type == 'received';

  factory StockRecord.fromMap(String id, Map<String, dynamic> map) {
    final rawDate = map['date'];

    return StockRecord(
      id: id,
      clinicId: map['clinicId'] as String? ?? '',
      medicineId: map['medicineId'] as String? ?? '',
      medicineName: map['medicineName'] as String? ?? 'Unknown',
      unit: map['unit'] as String? ?? '',
      type: map['type'] as String? ?? 'issued',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      reason: map['reason'] as String?,
      // A record without a date is ignored by the reports (far in the past).
      date: rawDate is Timestamp
          ? rawDate.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      recordedBy: map['recordedBy'] as String? ?? '',
    );
  }
}
