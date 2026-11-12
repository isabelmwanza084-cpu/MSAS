import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class ClinicStaffDashboard extends StatelessWidget {
  const ClinicStaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic Staff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const LoginScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Kabwata Clinic',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Staff Dashboard',
              style: TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 30),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.add_box),
                title:
                    Text('Record Stock Received'),
              ),
            ),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.remove_circle),
                title:
                    Text('Record Stock Issued'),
              ),
            ),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.inventory),
                title:
                    Text('View Current Stock'),
              ),
            ),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.warning),
                title:
                    Text('View Stock Alerts'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}