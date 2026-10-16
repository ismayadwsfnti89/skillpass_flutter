import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mya/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileEndpoint = '$baseUrl/profile';
  static const String imageEndpoint = 'https://sijala.biz.id/api/image';

  Map<String, dynamic>? profile;
  Future<Uint8List?>? profileImageFuture;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    getProfile();
  }

  Future<void> getProfile() async {
    try {
      setState(() => isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse(profileEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        final profileData = Map<String, dynamic>.from(data['data']);
        final photo = profileData['photo']?.toString();

        setState(() {
          profile = profileData;
          profileImageFuture = (photo != null && photo.isNotEmpty)
              ? fetchProfileImage(photo)
              : null;
          isLoading = false;
        });
      } else {
        throw Exception(data['message'] ?? 'Gagal mengambil data profile.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List?> fetchProfileImage(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$imageEndpoint/$fileName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Logout berhasil'),
              backgroundColor: Colors.green),
        );
        context.go(AppRoutes.login);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Logout gagal. Silakan coba lagi.'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak dapat terhubung ke server.'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> handleRefresh() async {
    await getProfile();
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            flex: 5,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget profileCard() {
    if (profile == null) {
      return const Center(child: Text('Data profile tidak ditemukan.'));
    }

    final name = profile!['name']?.toString() ?? '';
    final username = profile!['username']?.toString() ?? '-';
    final photo = profile!['photo']?.toString();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.blue.shade50,
            child: photo != null && photo.isNotEmpty
                ? FutureBuilder<Uint8List?>(
                    future: profileImageFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasData && snapshot.data != null) {
                        return ClipOval(
                          child: Image.memory(snapshot.data!,
                              width: 84, height: 84, fit: BoxFit.cover),
                        );
                      }
                      return const Icon(Icons.person,
                          size: 45, color: Colors.blue);
                    },
                  )
                : const Icon(Icons.person, size: 45, color: Colors.blue),
          ),
          const SizedBox(height: 14),
          Text(name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('@$username', style: const TextStyle(color: Colors.grey)),
          const Divider(height: 30),
          infoRow('Username', username),
          infoRow('Email', profile!['email']?.toString() ?? '-'),
          infoRow('Nomor HP', profile!['phone']?.toString() ?? '-'),
          infoRow('Jenis Kelamin', profile!['gender']?.toString() ?? '-'),
          infoRow('Tempat Lahir', profile!['birth_place']?.toString() ?? '-'),
          infoRow('Tanggal Lahir', profile!['birth_date']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: ListTile(
        leading: Icon(icon, color: isLogout ? Colors.red : Colors.blue),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLogout ? Colors.red : Colors.black87)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Beranda',
            onPressed: () => context.go(AppRoutes.dashboard),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: handleRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Tombol kembali ke Beranda
                // Tombol kembali (paling atas)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.dashboard),
                    icon: const Icon(Icons.home),
                    label: const Text('Kembali ke Beranda'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),

                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  )
                else
                  profileCard(),
                const SizedBox(height: 16),

                actionCard(
                  icon: Icons.edit,
                  title: 'Edit Profil',
                  subtitle: 'Perbarui data diri',
                  onTap: () async {
                    final result = await context.push(
                      AppRoutes.editProfile,
                      extra: profile,
                    );
                    if (result == true) {
                      getProfile();
                    }
                  },
                ),

                actionCard(
                  icon: Icons.logout,
                  title: 'Keluar',
                  subtitle: 'Logout dari akun',
                  isLogout: true,
                  onTap: logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}