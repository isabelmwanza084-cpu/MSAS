import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../services/medicine_service.dart';

// Same design colours used by the dashboard, record stock and alerts screens.
class _AppColors {
  static const dark = Color(0xFF1E3D3A);
  static const bg = Color(0xFFE9F1EE);
  static const green = Color(0xFF4F9D6E);
  static const red = Color(0xFFD9534F);
  static const muted = Color(0xFF6B7B78);
}

// Dark green rounded header (same look as _GreenHeader on the other
// screens) with a back button, because this screen is opened on top of
// the Medicines screen.
class _FormHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FormHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          10, MediaQuery.of(context).padding.top + 10, 22, 22),
      decoration: const BoxDecoration(
        color: _AppColors.dark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            tooltip: 'Back',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MedicineFormScreen extends StatefulWidget {
  final Medicine? medicine;

  const MedicineFormScreen({
    super.key,
    this.medicine,
  });

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicineService _medicineService = MedicineService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController minimumController = TextEditingController();
  final TextEditingController criticalController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  String selectedCategory = 'Malaria Medicines';
  DateTime? selectedExpiryDate;
  bool isSaving = false;

  bool get isEditing => widget.medicine != null;

  final List<String> categories = [
    'Malaria Medicines',
    'Antibiotics',
    'ORS',
  ];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();

    final medicine = widget.medicine;

    if (medicine != null) {
      nameController.text = medicine.medicineName;
      quantityController.text = medicine.quantity.toString();
      minimumController.text = medicine.minimumStock.toString();
      criticalController.text = medicine.criticalStock.toString();
      unitController.text = medicine.unit;
      selectedCategory = medicine.category;
      selectedExpiryDate = medicine.expiryDate;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    minimumController.dispose();
    criticalController.dispose();
    unitController.dispose();
    super.dispose();
  }

  String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? validateInteger(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a number.';
    }

    final number = int.tryParse(value.trim());

    if (number == null) {
      return 'Enter a whole number.';
    }

    if (number < 0) {
      return 'The number cannot be negative.';
    }

    return null;
  }

  Future<void> selectExpiryDate() async {
    final today = DateTime.now();
    final initialDate = selectedExpiryDate ?? today;

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year - 20),
      lastDate: DateTime(today.year + 30),
    );

    if (pickedDate != null) {
      setState(() {
        selectedExpiryDate = pickedDate;
      });
    }
  }

  Future<void> saveMedicine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date.'),
        ),
      );
      return;
    }

    final minimum = int.parse(minimumController.text.trim());
    final critical = int.parse(criticalController.text.trim());
    final quantity = int.parse(quantityController.text.trim());

    if (critical > minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Critical stock must not exceed minimum stock.',
          ),
        ),
      );
      return;
    }

    if (isEditing && quantity != widget.medicine!.quantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Stock quantity will be managed in Phase 4. '
            'Do not change it from this form.',
          ),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again.'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final medicine = Medicine(
        id: widget.medicine?.id ?? '',
        medicineName: nameController.text.trim(),
        category: selectedCategory,
        unit: unitController.text.trim(),
        quantity: quantity,
        minimumStock: minimum,
        criticalStock: critical,
        expiryDate: selectedExpiryDate!,
        clinicId: widget.medicine?.clinicId ?? 'kabwataClinic',
        createdAt: widget.medicine?.createdAt,
        updatedAt: DateTime.now(),
        createdBy: widget.medicine?.createdBy ?? user.uid,
      );

      if (isEditing) {
        await _medicineService.updateMedicine(medicine);
      } else {
        await _medicineService.addMedicine(medicine);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Medicine updated successfully.'
                : 'Medicine registered successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save medicine: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ---------- Design helpers (same style as the Record stock screen) ----------

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _AppColors.muted,
          ),
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _AppColors.dark,
          ),
        ),
      );

  InputDecoration _fieldDecoration({String? hint}) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: 1.2),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: _AppColors.muted.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(_AppColors.green),
      errorBorder: border(_AppColors.red),
      focusedErrorBorder: border(_AppColors.red),
    );
  }

  Widget _numberField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: _fieldDecoration(),
          validator: validateInteger,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = selectedExpiryDate == null
        ? 'Select expiry date'
        : '${selectedExpiryDate!.day} '
            '${_months[selectedExpiryDate!.month - 1]} '
            '${selectedExpiryDate!.year}';

    return Scaffold(
      backgroundColor: _AppColors.bg,
      body: Column(
        children: [
          _FormHeader(
            title: isEditing ? 'Edit medicine' : 'Register medicine',
            subtitle: isEditing
                ? 'Update the details for this medicine'
                : 'Add a new medicine to the clinic stock',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Medicine details'),

                    _label('Medicine name'),
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          _fieldDecoration(hint: 'e.g. Amoxicillin 250mg'),
                      validator: validateRequired,
                    ),
                    const SizedBox(height: 16),

                    _label('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final selected = category == selectedCategory;
                        return ChoiceChip(
                          label: Text(category),
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              selectedCategory = category;
                            });
                          },
                          selectedColor: _AppColors.dark,
                          backgroundColor: Colors.white,
                          showCheckmark: false,
                          side: BorderSide.none,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : _AppColors.dark,
                          ),
                          shape: const StadiumBorder(),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    _label('Unit'),
                    TextFormField(
                      controller: unitController,
                      decoration: _fieldDecoration(
                          hint: 'e.g. tablets, bottles, sachets'),
                      validator: validateRequired,
                    ),

                    const SizedBox(height: 28),
                    _sectionTitle('Stock levels'),

                    _numberField(
                      label: 'Initial stock quantity',
                      controller: quantityController,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _numberField(
                            label: 'Minimum level',
                            controller: minimumController,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _numberField(
                            label: 'Critical level',
                            controller: criticalController,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),
                    _sectionTitle('Expiry'),

                    _label('Expiry date'),
                    GestureDetector(
                      onTap: selectExpiryDate,
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 20, color: _AppColors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                dateText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selectedExpiryDate == null
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                  color: selectedExpiryDate == null
                                      ? _AppColors.muted
                                      : _AppColors.dark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : saveMedicine,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _AppColors.green,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _AppColors.green.withValues(alpha: 0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Update medicine'
                                    : 'Save medicine',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
