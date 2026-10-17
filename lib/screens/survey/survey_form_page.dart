import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Import Peta
import 'package:latlong2/latlong.dart'; // Import Koordinat
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_mya/routes/app_routes.dart';

class SurveyFormPage extends StatefulWidget {
  final Map<String, dynamic>? survey;
  const SurveyFormPage({super.key, this.survey});

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  
  // Controller ini disembunyikan, hanya untuk menyimpan nilai sebelum dikirim ke API
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  final MapController _mapController = MapController();
  // Default lokasi awal (Monas / titik tengah)
  LatLng _selectedLocation = const LatLng(-6.200000, 106.816666); 

  int? selectedCategoryId;
  List<Map<String, dynamic>> categories = [];
  bool isLoadingCategories = true;
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Uint8List? existingImageBytes;
  bool isSubmitting = false;

  bool get isEdit => widget.survey != null;

  static const Color primaryColor = Color(0xFF1E40AF);
  
  // URL BASE (Disamakan dengan Detail Page)
  static const String baseUrl = 'https://sijala.biz.id';
  static const String apiUrl = 'https://sijala.biz.id/api/v1'; // Untuk endpoint API
  static const String imageBaseUrl = 'https://sijala.biz.id'; // Untuk gambar

  @override
  void initState() {
    super.initState();
    if (isEdit) {
      titleController.text = widget.survey!['title']?.toString() ?? '';
      descriptionController.text = widget.survey!['description']?.toString() ?? '';
      
      // Jika mode edit, ambil koordinat dari data lama
      final lat = double.tryParse(widget.survey!['latitude']?.toString() ?? '');
      final lng = double.tryParse(widget.survey!['longitude']?.toString() ?? '');
      
      if (lat != null && lng != null) {
        _selectedLocation = LatLng(lat, lng);
        latitudeController.text = lat.toStringAsFixed(7);
        longitudeController.text = lng.toStringAsFixed(7);
      }

      final catId = widget.survey!['category_id'];
      if (catId != null) {
        selectedCategoryId = int.tryParse(catId.toString());
      } else if (widget.survey!['category'] is Map) {
        selectedCategoryId = int.tryParse(
          widget.survey!['category']['id']?.toString() ?? '',
        );
      }

      final photo = widget.survey!['photo']?.toString();
      if (photo != null && photo.isNotEmpty) {
        fetchExistingImage(photo);
      }
    }
    fetchCategories();
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      
      // MENGGUNAKAN /api/v1/categories AGAR SINKRON DENGAN DETAIL PAGE
      final response = await http.get(
        Uri.parse('$apiUrl/categories'), 
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Cek apakah data berbentuk List atau di dalam object 'data'
        final List rawData = data['data'] is List 
            ? data['data'] 
            : (data is List ? data : []);

        setState(() {
          categories = rawData
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => e['id'] != null) // Filter ID yang kosong
              .toList();
          isLoadingCategories = false;
        });
        return;
      }
      if (mounted) setState(() => isLoadingCategories = false);
    } catch (e) {
      debugPrint('Error fetchCategories: $e');
      if (mounted) setState(() => isLoadingCategories = false);
    }
  }

  Future<void> fetchExistingImage(String photoName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final fileName = photoName.contains('/')
          ? photoName.split('/').last
          : photoName;
      final response = await http.get(
        Uri.parse('$imageBaseUrl/$fileName'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          existingImageBytes = response.bodyBytes;
        });
      }
    } catch (_) {}
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          selectedImage = picked;
          selectedImageBytes = bytes;
        });
      }
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar('Gagal memilih foto.');
    }
  }

  void removeSelectedImage() {
    setState(() {
      selectedImage = null;
      selectedImageBytes = null;
      existingImageBytes = null;
    });
  }

  void showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> saveSurvey() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedCategoryId == null) {
      showErrorSnackBar('Pilih kategori survey dulu.');
      return;
    }
    
    // Pastikan peta sudah diketuk / digeser
    if (latitudeController.text.isEmpty || longitudeController.text.isEmpty) {
      showErrorSnackBar('Silakan ketuk peta untuk memilih lokasi survey.');
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Endpoint simpan menggunakan /api/v1/surveys/save
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/surveys/save'),
      );

      if (isEdit) {
        request.fields['id'] = widget.survey!['id'].toString();
        request.fields['_method'] = 'PUT';
      }

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = titleController.text.trim();
      request.fields['category_id'] = selectedCategoryId.toString();
      request.fields['description'] = descriptionController.text.trim();
      
      // Mengirim koordinat hasil klik peta ke API
      request.fields['latitude'] = latitudeController.text.trim();
      request.fields['longitude'] = longitudeController.text.trim();

      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEdit
                  ? 'Survey berhasil diperbarui!'
                  : 'Survey berhasil disimpan!',
            ),
            backgroundColor: const Color(0xFF108981),
          ),
        );
        context.pop(true);
        return;
      }

      if (response.statusCode == 422) {
        final decoded = jsonDecode(response.body);
        throw Exception(decoded['message'] ?? 'Data tidak valid.');
      }

      throw Exception('Gagal menyimpan (Kode: ${response.statusCode})');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  void showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Survey' : 'Tambah Survey'),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- CARD DATA UTAMA ---
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
                      const Text(
                        'Data Utama Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Judul Survey *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'Contoh: Survey Lokasi Wisata',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Judul wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kategori *',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // --- PERBAIKAN DROPDOWN KATEGORI ---
                      isLoadingCategories
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : categories.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Gagal memuat kategori. Periksa koneksi internet Anda.',
                                    style: TextStyle(color: Colors.red, fontSize: 12),
                                  ),
                                )
                              : DropdownButtonFormField<int>(
                                  value: categories.any((c) => int.tryParse(c['id'].toString()) == selectedCategoryId)
                                      ? selectedCategoryId
                                      : null, // Mencegah crash jika ID tidak ditemukan
                                  decoration: const InputDecoration(
                                    hintText: 'Pilih kategori',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: categories.map((c) {
                                    final id = int.tryParse(c['id'].toString()) ?? 0;
                                    final name = c['name']?.toString() ?? 'Tanpa Nama';
                                    return DropdownMenuItem<int>(
                                      value: id,
                                      child: Text(name),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => selectedCategoryId = v),
                                ),
                      const SizedBox(height: 16),
                      const Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Deskripsi survey...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CARD FOTO SURVEY ---
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
                      const Text(
                        'Foto Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedImageBytes != null ||
                          existingImageBytes != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                selectedImageBytes ?? existingImageBytes!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                cacheWidth: 600,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: removeSelectedImage,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        InkWell(
                          onTap: showImageSourceDialog,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: 36,
                                  color: primaryColor,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Ketuk untuk memilih foto',
                                  style: TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // --- CARD LOKASI MENGGUNAKAN PETA ---
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
                      const Text(
                        'Lokasi Survey',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Geser dan ketuk pada peta untuk memilih koordinat lokasi.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // KOMPONEN PETA
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _selectedLocation,
                                  initialZoom: 15.0,
                                  onTap: (tapPosition, point) {
                                    setState(() {
                                      _selectedLocation = point;
                                      // Simpan koordinat ke controller (tanpa input form)
                                      latitudeController.text = point.latitude.toStringAsFixed(7);
                                      longitudeController.text = point.longitude.toStringAsFixed(7);
                                    });
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                ],
                              ),
                              // Pin penanda lokasi di tengah peta
                              const IgnorePointer(
                                child: Icon(Icons.location_on, size: 50, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Menampilkan Teks Koordinat yang Dipilih
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 16, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            latitudeController.text.isEmpty
                                ? 'Belum ada lokasi yang dipilih'
                                : 'Lat: ${latitudeController.text}  |  Lng: ${longitudeController.text}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : saveSurvey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isEdit ? 'Simpan Perubahan' : 'Simpan Survey',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}