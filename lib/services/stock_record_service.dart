import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/medicine.dart';
import '../models/stock_record.dart';

class StockRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      _firestore.collection('stockRecords');

  CollectionReference<Map<String, dynamic>> get _medicinesCollection =>
      _firestore.collection('medicines');

  /// Saves a Received/Issued entry AND changes the medicine balance.
  ///
  /// Both writes go in one batch, so either both happen or neither does.
  /// The balance uses FieldValue.increment, so it is always changed relative
  /// to what is stored, and the batch also works with Firestore's offline
  /// queue later.
  Future<void> recordStock({
    required Medicine medicine,
    required bool received,
    required int quantity,
    required DateTime date,
    String? reason,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }

    if (!received && quantity > medicine.quantity) {
      throw Exception(
        'Only ${medicine.quantity} ${medicine.unit} of '
        '${medicine.medicineName} in stock.',
      );
    }

    final batch = _firestore.batch();

    batch.update(_medicinesCollection.doc(medicine.id), {
      'quantity': FieldValue.increment(received ? quantity : -quantity),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_recordsCollection.doc(), {
      'clinicId': medicine.clinicId,
      'medicineId': medicine.id,
      'medicineName': medicine.medicineName,
      'unit': medicine.unit,
      'type': received ? 'received' : 'issued',
      'quantity': quantity,
      'reason': received ? null : reason,
      // Store the day only, so reports group records by calendar day.
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'recordedBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// All stock records for a clinic. Reports filter by date on the device,
  /// so no Firestore composite index is needed.
  Stream<List<StockRecord>> getRecords(String clinicId) {
    return _recordsCollection
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => StockRecord.fromMap(doc.id, doc.data()))
          .toList();
    });
  }
}
