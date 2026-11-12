import 'dart:async';

import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import '../services/stock_record_service.dart';
import 'alerts_screen.dart';
import 'clinic_admin_dashboard.dart';
import 'medicine_list_screen.dart';
import 'reports_screen.dart';

class _AppColors {
  static const dark = Color(0xFF1E3D3A);
  static const bg = Color(0xFFE9F1EE);
  static const green = Color(0xFF4F9D6E);
  static const muted = Color(0xFF6B7B78);
}

class _GreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GreenHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          22, MediaQuery.of(context).padding.top + 16, 22, 22),
      decoration: const BoxDecoration(
        color: _AppColors.dark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
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
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class RecordStockScreen extends StatefulWidget {
  const RecordStockScreen({super.key});

  @override
  State<RecordStockScreen> createState() => _RecordStockScreenState();
}

class _RecordStockScreenState extends State<RecordStockScreen> {
  static const String _clinicId = 'kabwataClinic';

  final StockRecordService _stockService = StockRecordService();
  StreamSubscription<List<Medicine>>? _subscription;

  // Medicines you registered on the Medicines screen.
  List<Medicine> _medicines = [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;

  bool _received = true;
  String? _medicineId;
  int _quantity = 1;
  DateTime _date = DateTime.now();
  String _reason = 'Patient use';

  static const _reasons = ['Patient use', 'Expired', 'Damaged', 'Transfer'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void initState() {
    super.initState();

    _subscription = MedicineService().getMedicines(_clinicId).listen(
      (list) {
        list.sort((a, b) => a.medicineName
            .toLowerCase()
            .compareTo(b.medicineName.toLowerCase()));

        if (!mounted) return;
        setState(() {
          _medicines = list;
          _loading = false;
          _loadFailed = false;
          // If the selected medicine was deleted, clear the selection.
          if (_medicineId != null && !list.any((m) => m.id == _medicineId)) {
            _medicineId = null;
          }
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Medicine? get _selectedMedicine {
    for (final m in _medicines) {
      if (m.id == _medicineId) return m;
    }
    return null;
  }

  String get _dateLabel {
    final now = DateTime.now();
    final isToday = _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final d = '${_date.day} ${_months[_date.month - 1]}';
    return isToday ? 'Today, $d' : d;
  }

  String get _dropdownHint {
    if (_loading) return 'Loading medicines...';
    if (_loadFailed) return 'Could not load medicines';
    if (_medicines.isEmpty) return 'No medicines registered yet';
    return 'Select medicine';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // Lets the user type a large quantity (e.g. 500) instead of tapping +.
  Future<void> _editQuantity() async {
    final controller = TextEditingController(text: '$_quantity');

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. 500'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, value != null && value > 0 ? value : null);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null && mounted) setState(() => _quantity = result);
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    final medicine = _selectedMedicine;

    if (medicine == null) {
      _showMessage('Please select a medicine.');
      return;
    }

    setState(() => _saving = true);

    try {
      await _stockService.recordStock(
        medicine: medicine,
        received: _received,
        quantity: _quantity,
        date: _date,
        reason: _received ? null : _reason,
      );

      if (!mounted) return;

      _showMessage(
          '${_received ? 'Received' : 'Issued'} $_quantity ${medicine.unit} '
          'of ${medicine.medicineName} saved');

      setState(() => _quantity = 1);
    } catch (e) {
      if (!mounted) return;
      _showMessage(
          'Unable to save: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.bg,
      body: _content(context),
      bottomNavigationBar: const _BottomNav(current: 2),
    );
  }

  Widget _content(BuildContext context) {
    final selected = _selectedMedicine;

    return Column(
      children: [
        const _GreenHeader(
            title: 'Record stock', subtitle: 'Log what came in or went out'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Received / Issued toggle
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    _toggle('Received', _received, () {
                      setState(() => _received = true);
                    }),
                    _toggle('Issued', !_received, () {
                      setState(() => _received = false);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _label('Medicine'),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: _box(),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _medicineId,
                    isExpanded: true,
                    hint: Text(_dropdownHint,
                        style: const TextStyle(color: _AppColors.muted)),
                    items: _medicines
                        .map((m) => DropdownMenuItem(
                            value: m.id, child: Text(m.medicineName)))
                        .toList(),
                    onChanged: _medicines.isEmpty
                        ? null
                        : (v) => setState(() => _medicineId = v),
                  ),
                ),
              ),
              if (selected != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    'Current balance: ${selected.quantity} ${selected.unit}',
                    style: const TextStyle(
                        fontSize: 12, color: _AppColors.muted),
                  ),
                ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Quantity'),
                        Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: _box(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _stepper(Icons.remove, () {
                                if (_quantity > 1) setState(() => _quantity--);
                              }),
                              GestureDetector(
                                onTap: _editQuantity,
                                child: Text('$_quantity',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700)),
                              ),
                              _stepper(
                                  Icons.add, () => setState(() => _quantity++)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Date'),
                        GestureDetector(
                          onTap: _pickDate,
                          child: Container(
                            height: 52,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: _box(),
                            child: Text(_dateLabel),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (!_received) ...[
                const SizedBox(height: 16),
                _label('Reason (for issues)'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _reasons.map((r) {
                    final isSelected = r == _reason;
                    return ChoiceChip(
                      label: Text(r),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _reason = r),
                      selectedColor: _AppColors.dark,
                      backgroundColor: Colors.white,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : _AppColors.dark),
                      shape: const StadiumBorder(),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 28),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        _AppColors.green.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Save record',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggle(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _AppColors.green : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _AppColors.dark)),
        ),
      ),
    );
  }

  Widget _stepper(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: _AppColors.green.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 18, color: _AppColors.green),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _AppColors.muted)),
      );

  BoxDecoration _box() => BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14));
}

class _BottomNav extends StatelessWidget {
  final int current;

  const _BottomNav({required this.current});

  void _go(BuildContext context, int i) {
    if (i == current) return;

    Widget? page = switch (i) {
      0 => const ClinicAdminDashboard(),
      1 => const MedicineListScreen(),
      2 => const RecordStockScreen(),
      3 => const AlertsScreen(),
      4 => const ReportsScreen(),
      _ => null,
    };

    if (page == null) return;

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.medication_outlined, 'Medicines'),
      (Icons.add, 'Record'),
      (Icons.notifications_none, 'Alerts'),
      (Icons.bar_chart, 'Reports'),
    ];

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final selected = i == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => _go(context, i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? _AppColors.dark : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(items[i].$1,
                          size: 22,
                          color: selected ? Colors.white : _AppColors.muted),
                      const SizedBox(height: 2),
                      Text(items[i].$2,
                          style: TextStyle(
                              fontSize: 10,
                              color: selected ? Colors.white : _AppColors.muted)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
