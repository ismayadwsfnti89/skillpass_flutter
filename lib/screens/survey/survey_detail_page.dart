import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_mya/routes/app_routes.dart';

class SurveyDetailPage extends StatefulWidget {
  final int surveyId;
  const SurveyDetailPage({super.key, required this.surveyId});

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  Map<String, dynamic>? survey;
  bool isLoading = true;
  String? errorMessage;
  Uint8List? imageBytes;

  static const Color primaryColor = Color(0xFF1E40AF);
  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String imageBaseUrl = 'https://sijala.biz.id/api/image';

  @override
  void initState() {
    super.initState();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      imageBytes = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      if (token.isEmpty) {
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/surveys/${widget.surveyId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        context.go(AppRoutes.login);
        return;
      }

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['status'] == true && result['data'] != null) {
          final data = Map<String, dynamic>.from(result['data']);
          setState(() {
            survey = data;
            isLoading = false;
          });
          final photoName = data['photo']?.toString();
          if (photoName != null && photoName.isNotEmpty) {
            fetchImage(photoName, token);
          }
          return;
        }
      }

      throw Exception('Survey tidak ditemukan');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Gagal memuat detail survey.';
      });
    }
  }

  Future<void> fetchImage(String photoName, String token) async {
    try {
      final fileName =
          photoName.contains('/') ? photoName.split('/').last : photoName;
      final response = await http.get(
        Uri.parse('$imageBaseUrl/$fileName'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;
        setState(() => imageBytes = response.bodyBytes);
      }
    } catch (_) {}
  }

  Future<void> editSurvey() async {
    final result = await context.push(AppRoutes.surveyForm, extra: survey);
    if (result == true && mounted) {
      fetchDetail();
    }
  }

  Future<void> deleteSurvey() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Survey'),
        content:
            const Text('Apakah Anda yakin ingin menghapus survey ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.post(
        Uri.parse('$baseUrl/surveys/${widget.surveyId}/delete'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Survey berhasil dihapus'),
            backgroundColor: Color(0xFF108981),
          ),
        );
        context.pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Gagal menghapus survey (Kode: ${response.statusCode})'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi kesalahan saat menghapus survey.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }

  void copyCoordinates(double lat, double lng) {
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Koordinat berhasil disalin!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detail Survey'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.surveyList);
            }
          },
        ),
        actions: [
          if (survey != null) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Survey',
              onPressed: editSurvey,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Hapus Survey',
              onPressed: deleteSurvey,
            ),
          ],
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: primaryColor),
                  SizedBox(height: 16),
                  Text('Memuat detail survey...',
                      style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : (errorMessage != null || survey == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(errorMessage ?? 'Survey tidak ditemukan',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, color: Color(0xFF0F172A))),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: fetchDetail,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: primaryColor,
                  onRefresh: fetchDetail,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (imageBytes != null)
                        Card(
                          elevation: 0,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(imageBytes!,
                                height: 220,
                                width: double.infinity,
                                fit: BoxFit.cover),
                          ),
                        ),
                      if (imageBytes != null) const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  survey!['category_name']?.toString() ??
                                      (survey!['category'] is Map
                                          ? survey!['category']['name']
                                                  ?.toString() ??
                                              'Tanpa Kategori'
                                          : 'Tanpa Kategori'),
                                  style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                survey!['title']?.toString() ?? '-',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Deskripsi',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                survey!['description']?.toString() ?? '-',
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF334155),
                                    height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Lokasi Survey',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(
                                'Koordinat: ${survey!['latitude'] ?? '-'}, ${survey!['longitude'] ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B)),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final lat = double.tryParse(survey![
                                                    'latitude']
                                                ?.toString() ??
                                            '');
                                        final lng = double.tryParse(survey![
                                                    'longitude']
                                                ?.toString() ??
                                            '');
                                        if (lat != null && lng != null) {
                                          copyCoordinates(lat, lng);
                                        }
                                      },
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Salin Koordinat'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryColor,
                                        side: const BorderSide(
                                            color: primaryColor),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final lat = double.tryParse(survey![
                                                    'latitude']
                                                ?.toString() ??
                                            '');
                                        final lng = double.tryParse(survey![
                                                    'longitude']
                                                ?.toString() ??
                                            '');
                                        if (lat != null && lng != null) {
                                          openGoogleMaps(lat, lng);
                                        }
                                      },
                                      icon: const Icon(Icons.map, size: 16),
                                      label: const Text('Buka Maps'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
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