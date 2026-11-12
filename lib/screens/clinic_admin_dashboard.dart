import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/medicine.dart';
import '../services/auth_service.dart';
import '../services/medicine_service.dart';
import 'alerts_screen.dart';
import 'login_screen.dart';
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

// Same rule as the Medicines screen, so both screens always agree.
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
      this.child,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final int normal, low, critical;

  _DonutPainter(
      {required this.normal, required this.low, required this.critical});

  @override
  void paint(Canvas canvas, Size size) {
    final total = (normal + low + critical).toDouble();
    if (total == 0) return;

    const stroke = 10.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke,
        size.height - stroke);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    double start = -math.pi / 2;

    void arc(int value, Color color) {
      if (value == 0) return;
      final sweep = 2 * math.pi * value / total;
      paint.color = color;
      canvas.drawArc(rect, start, sweep - 0.04, false, paint);
      start += sweep;
    }

    arc(normal, _AppColors.green);
    arc(low, _AppColors.amber);
    arc(critical, _AppColors.red);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.normal != normal || old.low != low || old.critical != critical;
}

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;

  const _MedicineCard({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(medicine);
    final color = _statusColor(status);

    // Marker sits at 50% of the bar, so the bar scale is 2x the minimum level.
    final min = medicine.minimumStock;
    final double fill = min <= 0
        ? (medicine.quantity > 0 ? 1.0 : 0.0)
        : (medicine.quantity / (min * 2)).clamp(0.0, 1.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(medicine.medicineName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text('Balance: ${medicine.quantity} ${medicine.unit}',
                        style: const TextStyle(
                            fontSize: 12, color: _AppColors.muted)),
                  ],
                ),
              ),
              _StatusPill(label: _statusLabel(status), color: color),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, c) {
            return SizedBox(
              height: 10,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: const Color(0xFFE6EAE9),
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  Container(
                    height: 6,
                    width: c.maxWidth * fill,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(3)),
                  ),
                  Positioned(
                    left: c.maxWidth * 0.5,
                    child: Container(
                        width: 2, height: 10, color: _AppColors.muted),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ClinicAdminDashboard extends StatefulWidget {
  const ClinicAdminDashboard({super.key});

  @override
  State<ClinicAdminDashboard> createState() => _ClinicAdminDashboardState();
}

class _ClinicAdminDashboardState extends State<ClinicAdminDashboard> {
  static const String _clinicId = 'kabwataClinic';

  // Created once so the stream is not restarted on every rebuild.
  late final Stream<List<Medicine>> _medicinesStream =
      MedicineService().getMedicines(_clinicId);

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
          final meds = [...(snapshot.data ?? const <Medicine>[])];

          // Most urgent first: critical, then low, then normal.
          meds.sort((a, b) {
            final byStatus =
                _statusOf(b).index.compareTo(_statusOf(a).index);
            if (byStatus != 0) return byStatus;
            return a.medicineName
                .toLowerCase()
                .compareTo(b.medicineName.toLowerCase());
          });

          return _content(context, meds, loading: loading, hasError: hasError);
        },
      ),
      bottomNavigationBar: const _BottomNav(current: 0),
    );
  }

  Widget _content(BuildContext context, List<Medicine> meds,
      {required bool loading, required bool hasError}) {
    final normal =
        meds.where((m) => _statusOf(m) == _StockStatus.normal).length;
    final low = meds.where((m) => _statusOf(m) == _StockStatus.low).length;
    final critical =
        meds.where((m) => _statusOf(m) == _StockStatus.critical).length;

    final subtitle = hasError
        ? 'Could not load medicines'
        : loading
            ? 'Loading medicines...'
            : '${meds.length} ${meds.length == 1 ? 'medicine' : 'medicines'} tracked';

    return Column(
      children: [
        _GreenHeader(
          title: 'Stock today',
          subtitle: subtitle,
          trailing: IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () async {
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          child: Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _DonutPainter(
                      normal: normal, low: low, critical: critical),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${meds.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        const Text('medicines',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legend(_AppColors.green, normal, 'Normal'),
                  _legend(_AppColors.amber, low, 'Low'),
                  _legend(_AppColors.red, critical, 'Critical'),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _body(meds, loading: loading, hasError: hasError)),
      ],
    );
  }

  Widget _body(List<Medicine> meds,
      {required bool loading, required bool hasError}) {
    if (hasError) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load medicines.\nCheck your internet connection and '
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

    if (meds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medication_outlined,
                  size: 56, color: _AppColors.muted),
              SizedBox(height: 12),
              Text('No medicines registered yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _AppColors.dark)),
              SizedBox(height: 6),
              Text('Open the Medicines tab and tap "Add Medicine".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _AppColors.muted)),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      children: [
        ...meds.map((m) => _MedicineCard(medicine: m)),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Marker on each bar shows the minimum level.',
              style: TextStyle(fontSize: 11, color: _AppColors.muted)),
        ),
      ],
    );
  }

  Widget _legend(Color c, int count, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
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
