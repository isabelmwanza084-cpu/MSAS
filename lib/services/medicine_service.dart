import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/medicine.dart';
import 'zambox_service.dart';

class MedicineService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _medicinesCollection =>
      _firestore.collection('medicines');

  // Add a new medicine.
  Future<void> addMedicine(Medicine medicine) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final data = medicine.toMap();

    // Always use the UID of the authenticated user.
    data['createdBy'] = user.uid;

    await _medicinesCollection.add(data);

    // Check stock level when adding medicine.
    if (medicine.quantity <= medicine.minimumStock) {
      await _triggerStockSms(medicine);
    }
  }

  // Get medicines belonging to a particular clinic.
  Stream<List<Medicine>> getMedicines(String clinicId) {
    return _medicinesCollection
        .where('clinicId', isEqualTo: clinicId)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            return Medicine.fromMap(document.id, document.data());
          }).toList();
        });
  }

  // Update an existing medicine.
  Future<void> updateMedicine(Medicine medicine) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    await _medicinesCollection.doc(medicine.id).update({
      'medicineName': medicine.medicineName,
      'category': medicine.category,
      'unit': medicine.unit,
      'quantity': medicine.quantity,
      'minimumStock': medicine.minimumStock,
      'criticalStock': medicine.criticalStock,
      'expiryDate': Timestamp.fromDate(medicine.expiryDate),
      'clinicId': medicine.clinicId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Check stock level after updating.
    if (medicine.quantity <= medicine.minimumStock) {
      await _triggerStockSms(medicine);
    }
  }

  // Handle both low-stock and critical-stock SMS alerts.
  Future<void> _triggerStockSms(Medicine medicine) async {
    try {
      const String recipientPhone = '+260771009396';

      late String message;

      if (medicine.quantity <= medicine.criticalStock) {
        message =
            'CRITICAL ALERT: ${medicine.medicineName} stock is critically low! '
            'Only ${medicine.quantity} remaining!';
      } else {
        message =
            'LOW STOCK ALERT: ${medicine.medicineName}. '
            'Only ${medicine.quantity} left!';
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

  // Delete a medicine.
  Future<void> deleteMedicine(String medicineId) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('You must be logged in.');
    }

    await _medicinesCollection.doc(medicineId).delete();
  }
}
