import 'package:flutter/material.dart';
import '../Service/AppServices.dart';


class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ValueListenableBuilder<Map<String, dynamic>>(
        valueListenable: UserService().currentUserNotifier,
        builder: (context, user, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(user['avatarUrl']),
                ),
                title: Text(user['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                subtitle: Text(user['email']),
              ),
              const Divider(height: 32),

              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: Colors.indigo),
                title: const Text('Switch to Business Dashboard'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pushNamed(context, '/business-dashboard'),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Colors.indigo),
                title: const Text('Switch to Seller Hub'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.pushNamed(context, '/seller-dashboard'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings & Privacy'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ],
          );
        },
      ),
    );
  }
}