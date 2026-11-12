import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/medicine_service.dart';
import 'clinic_admin_dashboard.dart';
import 'medicine_list_screen.dart';
import 'record_stock_screen.dart';
import 'reports_screen.dart';

class _AppColors {
  static const dark = Color(0xFF1E3D3A);
  static const bg = Color(0xFFE9F1EE);
  static const green = Color(0xFF4F9D6E);
  static const amber = Color(0xFFE8A33D);
  static const red = Color(0xFFD9534F);
  static const muted = Color(0xFF6B7B78);
}

enum _StockStatus { normal, low, critical }

// Same rule as the Medicines screen and the dashboard.
_StockStatus _statusOf(Medicine m) {
  if (m.quantity <= m.criticalStock) return _StockStatus.critical;
  if (m.quantity <= m.minimumStock) return _StockStatus.low;
  return _StockStatus.normal;
}

Color _statusColor(_StockStatus s) => switch (s) {
      _StockStatus.critical => _AppColors.red,
      _StockStatus.low => _AppColors.amber,
      _StockStatus.normal => _AppColors.green,
    };

String _statusLabel(_StockStatus s) => switch (s) {
      _StockStatus.critical => 'Critical',
      _StockStatus.low => 'Low',
      _StockStatus.normal => 'Normal',
    };

class _GreenHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;
  final Widget? trailing;

  const _GreenHeader(
      {required this.title,
      required this.subtitle,
      // ignore: unused_element_parameter
      this.child,
      // ignore: unused_element_parameter
      this.trailing});

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
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          if (child != null) ...[const SizedBox(height: 16), child!],
        ],
      ),
    );
  }
}

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const String _clinicId = 'kabwataClinic';

  // Created once so the stream is not restarted on every rebuild.
  late final Stream<List<Medicine>> _medicinesStream =
      MedicineService().getMedicines(_clinicId);

  // IDs of alerts the user has acknowledged.
  // TODO: save acknowledgements in Firestore. For now they are only
  // remembered while this screen is open.
  final Set<String> _acknowledged = {};

  void _acknowledge(Medicine m) {
    setState(() => _acknowledged.add(m.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.bg,
      body: StreamBuilder<List<Medicine>>(
        stream: _medicinesStream,
        builder: (context, snapshot) {
          final hasError = snapshot.hasError;
          final loading =
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;

          // Only medicines that are Low or Critical, most urgent first.
          final alerts = (snapshot.data ?? const <Medicine>[])
              .where((m) =>
                  _statusOf(m) != _StockStatus.normal &&
                  !_acknowledged.contains(m.id))
              .toList()
            ..sort((a, b) {
              final byStatus =
                  _statusOf(b).index.compareTo(_statusOf(a).index);
              if (byStatus != 0) return byStatus;
              return a.medicineName
                  .toLowerCase()
                  .compareTo(b.medicineName.toLowerCase());
            });

          final subtitle = hasError
              ? 'Could not load medicines'
              : loading
                  ? 'Loading alerts...'
                  : alerts.isEmpty
                      ? 'No medicines need attention'
                      : '${alerts.length} ${alerts.length == 1 ? 'medicine needs' : 'medicines need'} attention';

          return Column(
            children: [
              _GreenHeader(title: 'Alerts', subtitle: subtitle),
              Expanded(
                child: _body(alerts, loading: loading, hasError: hasError),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: const _BottomNav(current: 3),
    );
  }

  Widget _body(List<Medicine> alerts,
      {required bool loading, required bool hasError}) {
    if (hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load alerts.\nCheck your internet connection and '
            'Firestore permissions.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _AppColors.muted),
          ),
        ),
      );
    }

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _AppColors.green),
      );
    }

    if (alerts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline,
                  size: 56, color: _AppColors.green),
              SizedBox(height: 12),
              Text('All stock levels are healthy',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.dark)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: alerts.map(_alertCard).toList(),
    );
  }

  Widget _alertCard(Medicine m) {
    final status = _statusOf(m);
    final color = _statusColor(status);
    final isCritical = status == _StockStatus.critical;
    final limitText = isCritical
        ? 'critical level ${m.criticalStock}'
        : 'minimum ${m.minimumStock}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 5, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(_statusLabel(status),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 8),
                    Text(m.medicineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text('Balance ${m.quantity} ${m.unit} ($limitText)',
                        style: const TextStyle(
                            fontSize: 12, color: _AppColors.muted)),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => _acknowledge(m),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _AppColors.dark,
                          side: const BorderSide(
                              color: _AppColors.dark, width: 1.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Acknowledge',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
