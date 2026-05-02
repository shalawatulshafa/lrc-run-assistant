import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/run_history_storage.dart';
import '../utils/snackbar_helper.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onDataDeleted;

  const SettingsScreen({super.key, this.onDataDeleted});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userName = '';
  String userEmail = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('authToken');

    try {
      if (token != null && token.isNotEmpty) {
        final Map<String, dynamic> profile = await ApiService.getProfile(token);
        userName = profile['name']?.toString() ?? 'Pengguna';
        userEmail = profile['email']?.toString() ?? 'email@example.com';

        await prefs.setString('userName', userName);
        await prefs.setString('userEmail', userEmail);
      } else {
        userName = prefs.getString('userName') ?? 'Pengguna';
        userEmail = prefs.getString('userEmail') ?? 'email@example.com';
      }
    } catch (_) {
      userName = prefs.getString('userName') ?? 'Pengguna';
      userEmail = prefs.getString('userEmail') ?? 'email@example.com';
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveUserData(String name, String email) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('authToken');

    try {
      if (token != null && token.isNotEmpty) {
        final Map<String, dynamic> updated = await ApiService.updateProfile(token, name, email);
        userName = updated['name']?.toString() ?? name;
        userEmail = updated['email']?.toString() ?? email;
      } else {
        userName = name;
        userEmail = email;
      }

      await prefs.setString('userName', userName);
      await prefs.setString('userEmail', userEmail);

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pengaturan',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Profil'),
            _buildProfileCard(
              name: userName,
              email: userEmail,
              photoUrl: '',
              onEditPressed: () {
                _showEditProfileDialog(context, userName, userEmail);
              },
            ),
            const SizedBox(height: 30),
            _buildSectionTitle('Pengelolaan Data'),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: _cardDecoration(),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline,
                    color: Colors.orange,
                    size: 40,
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hapus Data Lokal',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Hapus semua data sesi lari yang tersimpan di perangkat (tidak dapat dikembalikan)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _showDeleteConfirmDialog(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.cleaning_services, color: Colors.white, size: 16),
                          Text(
                            'Hapus',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _buildSectionTitle('Informasi & Bantuan'),
            _buildInfoCard(
              icon: Icons.mail_outline,
              title: 'Kontak Pengembang',
              subtitle: 'Hubungi tim dukungan dan pengembang proyek',
              onTap: () {
                _showDeveloperContactDialog(context);
              },
            ),
            const SizedBox(height: 15),
            _buildInfoCard(
              icon: Icons.info_outline,
              title: 'Tentang LRC Run Assistant',
              subtitle: 'Versi aplikasi, hak cipta dan dokumentasi proyek',
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            const SizedBox(height: 15),
            _buildInfoCard(
              icon: Icons.storage,
              title: 'Debug: Lihat Data Tersimpan',
              subtitle: 'Cek isi SharedPreferences (untuk developer)',
              onTap: () async {
                await _showSavedDataDialog(context);
              },
            ),
            const SizedBox(height: 40),
            Center(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showLogoutConfirmDialog(context);
                  },
                  icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.orange[800],
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Divider(color: Colors.orange[800], thickness: 1),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _buildProfileCard({
    required String name,
    required String email,
    required String photoUrl,
    required VoidCallback onEditPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.orange.shade100,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty ? Icon(Icons.person, size: 35, color: Colors.orange.shade800) : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEditPressed,
            icon: Icon(Icons.edit, size: 18, color: Colors.orange.shade700),
            label: Text('Edit', style: TextStyle(color: Colors.orange.shade700)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.orange.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Icon(icon, color: Colors.orange, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.grey.shade300),
    );
  }

  void _showEditProfileDialog(BuildContext context, String currentName, String currentEmail) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    final TextEditingController emailController = TextEditingController(text: currentEmail);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveUserData(nameController.text.trim(), emailController.text.trim());
                Navigator.pop(context);
                SnackbarHelper.showSuccess(context, 'Profil berhasil diperbarui');
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF77226)),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Data Lokal'),
          content: const Text('Yakin ingin menghapus semua data sesi lari? Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                await RunHistoryStorage.clear();

                widget.onDataDeleted?.call();

                if (mounted) {
                  Navigator.pop(context);
                  SnackbarHelper.showSuccess(context, 'Data lokal telah dihapus');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final SharedPreferences prefs = await SharedPreferences.getInstance();
                final String? token = prefs.getString('authToken');

                try {
                  if (token != null && token.isNotEmpty) {
                    await ApiService.logout(token);
                  }
                } catch (_) {
                  // Keep logout flow even when backend is unreachable.
                }

                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('authToken');

                if (mounted) {
                  Navigator.pop(context);
                  SnackbarHelper.showInfo(context, 'Logout berhasil');
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showDeveloperContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kontak Pengembang'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: TimTA22@gmail.com'),
              SizedBox(height: 8),
              Text('Phone: +62 812 3456 7890'),
              SizedBox(height: 8),
              Text('Website: www.TimTA22.com'),
              SizedBox(height: 16),
              Divider(),
              SizedBox(height: 8),
              Text('Tim Pengembang:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('- Shalawatul Shafa - Frontend'),
              Text('- Kayla Pramudio Bagaskara - Backend'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tentang LRC Run Assistant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(Icons.directions_run, size: 50, color: Color(0xFFF77226)),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('LRC Run Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              const Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey))),
              const SizedBox(height: 16),
              const Text(
                'Aplikasi pendamping lari untuk membantu atlet memantau kepatuhan LRC (Langkah per menit) menggunakan chest strap.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('© 2025 LRC Run Assistant Team'),
              Text('All rights reserved', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSavedDataDialog(BuildContext context) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? data = prefs.getStringList('runHistory');

    String message = 'Total data: ${data?.length ?? 0}\n\n';
    if (data != null && data.isNotEmpty) {
      for (int i = 0; i < data.length; i++) {
        try {
          final Map<String, dynamic> run = jsonDecode(data[i]);
          message += '${i + 1}. ${run['title']}\n';
          message += '   Date: ${run['date']}\n';
          message += '   ${run['distance']} km | ${run['duration']}\n';
          message += '   Kepatuhan: ${run['compliance']}%\n';
          message += '   ID: ${run['id']}\n\n';
        } catch (_) {
          message += '${i + 1}. Error parsing data\n\n';
        }
      }
    } else {
      message += 'Belum ada data lari yang tersimpan\n';
      message += 'Silakan coba download data lari terlebih dahulu';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data SharedPreferences'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          if (data != null && data.isNotEmpty)
            TextButton(
              onPressed: () async {
                await prefs.remove('runHistory');
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Data debug telah dihapus')),
                  );
                }
              },
              child: const Text('Hapus Semua', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
