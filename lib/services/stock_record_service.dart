import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/medicine.dart';
import '../models/stock_record.dart';
import 'zambox_service.dart';

class StockRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _recordsCollection =>
      _firestore.collection('stockRecords');

  CollectionReference<Map<String, dynamic>> get _medicinesCollection =>
      _firestore.collection('medicines');

  // Saves a Received/Issued entry AND changes the medicine balance.
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

    // Calculate the expected new stock balance.
    final int newQuantity = received
        ? medicine.quantity + quantity
        : medicine.quantity - quantity;

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
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'recordedBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    // Check stock levels after the stock transaction succeeds.
    if (newQuantity <= medicine.minimumStock) {
      await _triggerStockSms(medicine: medicine, newQuantity: newQuantity);
    }
  }

  // Send low-stock or critical-stock SMS.
  Future<void> _triggerStockSms({
    required Medicine medicine,
    required int newQuantity,
  }) async {
    try {
      const String recipientPhone = '+260771009396';

      late String message;

      if (newQuantity <= medicine.criticalStock) {
        message =
            'CRITICAL ALERT: ${medicine.medicineName} stock is critically low! '
            'Only $newQuantity remaining!';
      } else {
        message =
            'LOW STOCK ALERT: ${medicine.medicineName}. '
            'Only $newQuantity left!';
      }

      final bool success = await ZamboxService.sendSms(
        recipientPhone: recipientPhone,
        message: message,
      );

      if (success) {
        print('Zambox stock alert sent successfully!');
      } else {
        print('Zambox failed to send stock alert.');
      }
    } catch (e) {
      print('Error triggering Zambox SMS: $e');
    }
  }

  // All stock records for a clinic.
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
