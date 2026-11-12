import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'medicine_form_screen.dart';
import 'clinic_admin_dashboard.dart';
import 'record_stock_screen.dart';
import 'alerts_screen.dart';
import 'reports_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() =>
      _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  final MedicineService _medicineService = MedicineService();

  final String clinicId = 'kabwataClinic';

  final TextEditingController _searchController =
      TextEditingController();

  String searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Determine the stock status of a medicine.
  String getStockStatus(Medicine medicine) {
    if (medicine.quantity <= medicine.criticalStock) {
      return 'CRITICAL';
    } else if (medicine.quantity <= medicine.minimumStock) {
      return 'LOW STOCK';
    } else {
      return 'NORMAL';
    }
  }

  // Return a colour based on the medicine's stock status.
  Color getStatusColor(Medicine medicine) {
    if (medicine.quantity <= medicine.criticalStock) {
      return const Color(0xFFD9534F);
    } else if (medicine.quantity <= medicine.minimumStock) {
      return const Color(0xFFE8A33D);
    } else {
      return const Color(0xFF4F9D6E);
    }
  }

  // Open the form for adding a new medicine.
  void addMedicine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MedicineFormScreen(),
      ),
    );
  }

  // Open the form for editing an existing medicine.
  void editMedicine(Medicine medicine) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MedicineFormScreen(medicine: medicine),
      ),
    );
  }

  // Ask for confirmation before deleting a medicine.
  Future<void> confirmDelete(Medicine medicine) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Medicine'),
          content: Text(
            'Are you sure you want to delete '
            '${medicine.medicineName}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      try {
        await _medicineService.deleteMedicine(medicine.id);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine deleted successfully'),
          ),
        );
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete medicine: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F8),

      // Top app bar.
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F3B38),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(28),
          ),
        ),
        title: const Text(
          'Medicine Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),

      // Main screen content.
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF388E80),
                ),
                suffixIcon: searchText.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            searchText = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Medicine list from Firestore.
          Expanded(
            child: StreamBuilder<List<Medicine>>(
              stream: _medicineService.getMedicines(clinicId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Unable to load medicines.\n'
                        'Check your internet connection and '
                        'Firestore permissions.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF388E80),
                    ),
                  );
                }

                final medicines = snapshot.data ?? [];

                // Filter medicines using the search text.
                final filteredMedicines =
                    medicines.where((medicine) {
                  return medicine.medicineName
                          .toLowerCase()
                          .contains(searchText) ||
                      medicine.category
                          .toLowerCase()
                          .contains(searchText);
                }).toList();

                if (filteredMedicines.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.medication_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            searchText.isEmpty
                                ? 'No medicines registered yet'
                                : 'No matching medicines found',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (searchText.isEmpty)
                            const Text(
                              'Tap "Add Medicine" to register one.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black45,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16, 4, 16, 100,
                  ),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (context, index) {
                    final medicine = filteredMedicines[index];

                    final status = getStockStatus(medicine);
                    final statusColor =
                        getStatusColor(medicine);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: 0.04,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Medicine name and status.
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5F3EF),
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.medication,
                                    color: Color(0xFF388E80),
                                    size: 27,
                                  ),
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medicine.medicineName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.bold,
                                          color: Color(0xFF1E3D3A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        medicine.category,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            // Available quantity.
                            Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 18,
                                  color: Color(0xFF388E80),
                                ),
                                const SizedBox(width: 7),
                                const Text(
                                  'Available stock',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${medicine.quantity} '
                                  '${medicine.unit}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Minimum and critical stock levels.
                            Row(
                              children: [
                                Expanded(
                                  child: _StockDetail(
                                    label: 'Minimum stock',
                                    value:
                                        '${medicine.minimumStock}',
                                  ),
                                ),
                                Expanded(
                                  child: _StockDetail(
                                    label: 'Critical stock',
                                    value:
                                        '${medicine.criticalStock}',
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Expiry date.
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  size: 17,
                                  color: Colors.black45,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Expiry date: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    medicine.expiryDate
                                        .toString()
                                        .split(' ')
                                        .first,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 26),

                            // Edit and delete actions.
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    editMedicine(medicine);
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Edit'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color(0xFF388E80),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    confirmDelete(medicine);
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Delete'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Add medicine button.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addMedicine,
        backgroundColor: const Color(0xFF388E80),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Medicine',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      // Bottom navigation bar with Medicines selected.
      bottomNavigationBar: const _BottomNav(current: 1),
    );
  }
}

// Small widget for displaying stock-level details.
class _StockDetail extends StatelessWidget {
  final String label;
  final String value;

  const _StockDetail({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E3D3A),
          ),
        ),
      ],
    );
  }
}

// Bottom navigation bar.
class _BottomNav extends StatelessWidget {
  final int current;

  const _BottomNav({required this.current});

  void _navigate(BuildContext context, int index) {
    if (index == current) return;

    Widget screen;

    switch (index) {
      case 0:
        screen = const ClinicAdminDashboard();
        break;
      case 1:
        screen = const MedicineListScreen();
        break;
      case 2:
        screen = const RecordStockScreen();
        break;
      case 3:
        screen = const AlertsScreen();
        break;
      case 4:
        screen = const ReportsScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: current,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: const Color(0xFF388E80),
      unselectedItemColor: Colors.grey,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) => _navigate(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.medication_outlined),
          activeIcon: Icon(Icons.medication),
          label: 'Medicines',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined),
          activeIcon: Icon(Icons.add_box),
          label: 'Record',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications_none),
          activeIcon: Icon(Icons.notifications),
          label: 'Alerts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
      ],
    );
  }
}
