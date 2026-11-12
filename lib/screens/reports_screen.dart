import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../models/stock_record.dart';
import '../services/medicine_service.dart';
import '../services/stock_record_service.dart';
import 'alerts_screen.dart';
import 'clinic_admin_dashboard.dart';
import 'medicine_list_screen.dart';
import 'record_stock_screen.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFE9F1EE);
  static const Color card = Colors.white;
  static const Color green = Color(0xFF4F9D6E);
  static const Color ink = Color(0xFF1E3D3A);
  static const Color muted = Color(0xFF6B7B78);
  static const Color danger = Color(0xFFD9534F);
  static const Color amber = Color(0xFFE8A33D);
}

/// Report figures for one period (7, 30 or 90 days), worked out from the
/// stock records saved on the Record stock screen.
class _PeriodData {
  final List<String> labels;
  final List<int> received;
  final List<int> issued;
  final int shortages;
  final String chartSubtitle;
  final Map<String, int> topIssued;

  const _PeriodData({
    required this.labels,
    required this.received,
    required this.issued,
    required this.shortages,
    required this.chartSubtitle,
    required this.topIssued,
  });

  int get totalReceived => received.fold(0, (total, value) => total + value);
  int get totalIssued => issued.fold(0, (total, value) => total + value);
}

_PeriodData _buildPeriodData({
  required List<StockRecord> records,
  required List<Medicine> medicines,
  required int days,
}) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final start = today.subtract(Duration(days: days - 1));

  // 7 days -> 7 daily bars, 30 days -> 4 bars, 90 days -> 3 bars.
  final bucketCount = switch (days) {
    7 => 7,
    30 => 4,
    _ => 3,
  };

  final labels = switch (days) {
    7 => List.generate(
        7, (i) => weekdays[start.add(Duration(days: i)).weekday - 1]),
    30 => List.generate(4, (i) => 'Wk ${i + 1}'),
    _ => List.generate(3, (i) => 'Month ${i + 1}'),
  };

  final chartSubtitle = switch (days) {
    7 => 'Units per day, last 7 days',
    30 => 'Units per week, last 30 days',
    _ => 'Units per month, last 90 days',
  };

  final received = List<int>.filled(bucketCount, 0);
  final issued = List<int>.filled(bucketCount, 0);
  final issuedByMedicine = <String, int>{};

  for (final r in records) {
    final day = DateTime.utc(r.date.year, r.date.month, r.date.day);
    final offset = day.difference(start).inDays;

    // Skip records outside the selected period.
    if (offset < 0 || offset >= days) continue;

    final bucket = offset * bucketCount ~/ days;

    if (r.isReceived) {
      received[bucket] += r.quantity;
    } else {
      issued[bucket] += r.quantity;
      issuedByMedicine[r.medicineName] =
          (issuedByMedicine[r.medicineName] ?? 0) + r.quantity;
    }
  }

  final sorted = issuedByMedicine.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Medicines that are Low or Critical right now (same rule as Alerts).
  final shortages =
      medicines.where((m) => m.quantity <= m.minimumStock).length;

  return _PeriodData(
    labels: labels,
    received: received,
    issued: issued,
    shortages: shortages,
    chartSubtitle: chartSubtitle,
    topIssued: {for (final e in sorted.take(5)) e.key: e.value},
  );
}

class ReportsScreen extends StatefulWidget {
  /// Keep this optional so the screen can be opened from the dashboard
  /// without passing a role. If supplied, it can be used for role-specific UI.
  final String role;

  const ReportsScreen({super.key, this.role = 'ClinicAdministrator'});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const String _clinicId = 'kabwataClinic';

  // Created once so the streams are not restarted on every rebuild.
  late final Stream<List<StockRecord>> _recordsStream =
      StockRecordService().getRecords(_clinicId);
  late final Stream<List<Medicine>> _medicinesStream =
      MedicineService().getMedicines(_clinicId);

  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: const _BottomNav(current: 4),
      body: StreamBuilder<List<StockRecord>>(
        stream: _recordsStream,
        builder: (context, recordsSnap) {
          return StreamBuilder<List<Medicine>>(
            stream: _medicinesStream,
            builder: (context, medicinesSnap) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  const _Header(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: _body(recordsSnap, medicinesSnap),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _body(AsyncSnapshot<List<StockRecord>> recordsSnap,
      AsyncSnapshot<List<Medicine>> medicinesSnap) {
    if (recordsSnap.hasError || medicinesSnap.hasError) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Text(
          'Unable to load reports.\nCheck your internet connection and '
          'Firestore permissions.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    if (!recordsSnap.hasData || !medicinesSnap.hasData) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.green),
        ),
      );
    }

    final data = _buildPeriodData(
      records: recordsSnap.data!,
      medicines: medicinesSnap.data!,
      days: _days,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PeriodSelector(
          selected: _days,
          onChanged: (days) => setState(() => _days = days),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _StatTile(
              value: '${data.totalReceived}',
              label: 'Received',
              color: AppColors.green,
            ),
            const SizedBox(width: 10),
            _StatTile(
              value: '${data.totalIssued}',
              label: 'Issued',
              color: AppColors.ink,
            ),
            const SizedBox(width: 10),
            _StatTile(
              value: '${data.shortages}',
              label: 'Shortages now',
              color: AppColors.danger,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ChartCard(data: data),
        const SizedBox(height: 14),
        _TopIssuedCard(items: data.topIssued),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 28,
        24,
        36,
      ),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Stock movement at Kabwata Clinic',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final days in const [7, 30, 90])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(days),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: days == selected
                        ? AppColors.ink
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$days days',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: days == selected
                          ? Colors.white
                          : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final _PeriodData data;

  const _ChartCard({required this.data});

  static const double _maxBarHeight = 110;

  @override
  Widget build(BuildContext context) {
    final values = [...data.received, ...data.issued];
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b).toDouble();
    final barWidth = data.labels.length > 5 ? 8.0 : 16.0;

    Widget bar(int value, Color color) {
      final height = maxValue == 0 ? 0.0 : value / maxValue * _maxBarHeight;
      return Container(
        width: barWidth,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Received and issued',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            data.chartSubtitle,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < data.labels.length; i++)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bar(data.received[i], AppColors.green),
                            const SizedBox(width: 4),
                            bar(data.issued[i], AppColors.ink),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.labels[i],
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AppColors.green, label: 'Received'),
              SizedBox(width: 16),
              _LegendDot(color: AppColors.ink, label: 'Issued'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.muted)),
      ],
    );
  }
}

class _TopIssuedCard extends StatelessWidget {
  final Map<String, int> items;

  const _TopIssuedCard({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Text('No medicine issue data available.'),
      );
    }

    final maxValue = items.values.reduce((a, b) => a > b ? a : b);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Most issued medicines',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final entry in items.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: maxValue <= 0 ? 0 : entry.value / maxValue,
                        minHeight: 8,
                        color: AppColors.ink,
                        backgroundColor: AppColors.background,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int current;

  const _BottomNav({required this.current});

  void _go(BuildContext context, int index) {
    if (index == current) return;

    final Widget page = switch (index) {
      0 => const ClinicAdminDashboard(),
      1 => const MedicineListScreen(),
      2 => const RecordStockScreen(),
      3 => const AlertsScreen(),
      _ => const ReportsScreen(),
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
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
              offset: const Offset(0, 4),
            ),
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
                    color: selected ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 22,
                        color: selected ? Colors.white : AppColors.muted,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        items[i].$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white : AppColors.muted,
                        ),
                      ),
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
