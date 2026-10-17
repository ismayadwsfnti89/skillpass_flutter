import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mya/routes/app_routes.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const Color primaryColor = Color(0xFF1E3A8A); // Warna biru tua

  Map<String, dynamic>? user;
  int totalSurvey = 0;
  int totalKategori = 0;
  List<Map<String, dynamic>> recentSurveys = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchDashboardData();
  }

  Future<void> fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Ambil data user dari local storage dulu
      final userStr = prefs.getString('user');
      if (userStr != null) {
        user = jsonDecode(userStr);
      }

      if (token.isEmpty) {
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      // 1. Ambil data dashboard (nama, total survey, total kategori)
      final dashRes = await http.get(
        Uri.parse('$baseUrl/dashboard'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (dashRes.statusCode == 200) {
        final dashData = jsonDecode(dashRes.body);
        if (dashData['data'] != null) {
          setState(() {
            user = dashData['data']['user'] ?? user;
            
            // --- FIX: Ambil angka fleksibel (bisa total_survey, total_surveys, dll)
            final data = dashData['data'];
            totalSurvey = data['total_survey'] ?? data['total_surveys'] ?? data['survey_count'] ?? 0;
            totalKategori = data['total_category'] ?? data['total_categories'] ?? data['category_count'] ?? 0;
          });
        }
      }

      // 2. Ambil list survey terbaru
      final surveyRes = await http.get(
        Uri.parse('$baseUrl/surveys'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (surveyRes.statusCode == 200) {
        final surveyData = jsonDecode(surveyRes.body);
        if (surveyData['data'] is List) {
          setState(() {
            recentSurveys = (surveyData['data'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .take(3) // Ambil 3 teratas aja
                .toList();
          });
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : RefreshIndicator(
                onRefresh: fetchDashboardData,
                color: primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER: Sapaan
                      const Text(
                        'Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Halo, Selamat datang ${user?['name'] ?? ''} 👋',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CARD BIRU: Kelola Survey
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.surveyList),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.assignment,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kelola Survey',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Pantau dan kelola data survey kamu dengan mudah.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // RINGKASAN SURVEY
                      const Text(
                        'Ringkasan Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              icon: Icons.assignment,
                              value: totalSurvey.toString(),
                              label: 'Total Survey',
                              iconColor: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _summaryCard(
                              icon: Icons.category,
                              value: totalKategori.toString(),
                              label: 'Total Kategori',
                              iconColor: const Color.fromARGB(255, 19, 100, 66),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // SURVEY TERBARU
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Survey Terbaru',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.surveyList),
                            child: const Text(
                              'Lihat semua',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // List Survey Terbaru
                      if (recentSurveys.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text('Belum ada data survey.',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        )
                      else
                        ...recentSurveys.map((s) {
                          // --- FIX: Ambil data dengan nama field yang fleksibel
                          final title = s['title']?.toString() ?? s['judul']?.toString() ?? '-';
                          final lat = s['latitude']?.toString();
                          final lng = s['longitude']?.toString();
                          final status = s['status']?.toString() ?? '';
                          
                          String lokasi = 'Lokasi tidak tersedia';
                          if (lat != null && lng != null && lat.isNotEmpty && lng.isNotEmpty) {
                            // Biar rapi, ambil 6 angka di belakang koma aja
                            String latStr = lat.length > 8 ? lat.substring(0, 8) : lat;
                            String lngStr = lng.length > 8 ? lng.substring(0, 8) : lng;
                            lokasi = '$latStr, $lngStr';
                          }

                          // Warna badge status
                          Color statusColor = Colors.orange;
                          if (status.toLowerCase() == 'selesai' || status.toLowerCase() == 'approved') {
                            statusColor = Colors.green;
                          } else if (status.toLowerCase() == 'rejected') {
                            statusColor = Colors.red;
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment,
                                    color: primaryColor, size: 24),
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A)),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        lokasi,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.assignment), label: 'Survey'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
        onTap: (index) {
          if (index == 1) context.go(AppRoutes.surveyList);
          if (index == 2) context.go(AppRoutes.profile);
        },
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}