import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class DistrictDashboard extends StatelessWidget {
  const DistrictDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'District Supply Officer',
        ),
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
              'District Monitoring',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              'Stock monitoring dashboard',
              style: TextStyle(
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 30),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.dashboard),
                title:
                    Text('Stock Overview'),
                subtitle:
                    Text('View current stock information'),
              ),
            ),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.warning),
                title:
                    Text('Critical Stock'),
                subtitle:
                    Text('View medicines requiring attention'),
              ),
            ),

            const Card(
              child: ListTile(
                leading:
                    Icon(Icons.bar_chart),
                title:
                    Text('Reports'),
                subtitle:
                    Text('View stock reports'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}