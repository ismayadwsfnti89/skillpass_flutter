import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_mya/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const EditProfilePage({super.key, this.profile});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController birthPlaceController;
  late TextEditingController birthDateController;

  String? gender;
  String? apiBirthDate;
  XFile? selectedImage;
  Uint8List? selectedImageBytes;
  Future<Uint8List?>? oldProfileImageFuture;
  bool isLoading = false;

  static const String baseUrl = 'https://sijala.biz.id/api/v1';
  static const String profileUpdateEndpoint = '$baseUrl/profile/update';
  static const String imageEndpoint = 'https://sijala.biz.id/api/image';

  @override
  void initState() {
    super.initState();
    final profile = widget.profile ?? {};

    nameController = TextEditingController(text: profile['name']?.toString() ?? '');
    emailController = TextEditingController(text: profile['email']?.toString() ?? '');
    phoneController = TextEditingController(text: profile['phone']?.toString() ?? '');
    birthPlaceController = TextEditingController(text: profile['birth_place']?.toString() ?? '');

    if (profile['gender'] != null) {
      final g = profile['gender'].toString().toLowerCase();
      if (g.startsWith('l')) {
        gender = 'L';
      } else if (g.startsWith('p')) {
        gender = 'P';
      }
    }

    String displayBirthDate = '';
    final String? rawDate = profile['birth_date']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        DateTime? parsedDate;
        if (rawDate.contains('-')) {
          final parts = rawDate.split('-');
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              parsedDate = DateTime.parse(rawDate);
            } else if (parts[2].length == 4) {
              final int day = int.parse(parts[0]);
              final int month = int.parse(parts[1]);
              final int year = int.parse(parts[2]);
              parsedDate = DateTime(year, month, day);
            }
          }
        }
        if (parsedDate != null) {
          final String dayStr = parsedDate.day.toString().padLeft(2, '0');
          final String monthStr = parsedDate.month.toString().padLeft(2, '0');
          final String yearStr = parsedDate.year.toString();
          displayBirthDate = '$dayStr-$monthStr-$yearStr';
          apiBirthDate = '$yearStr-$monthStr-$dayStr';
        } else {
          displayBirthDate = rawDate;
          apiBirthDate = rawDate;
        }
      } catch (_) {
        displayBirthDate = rawDate;
        apiBirthDate = rawDate;
      }
    }
    birthDateController = TextEditingController(text: displayBirthDate);

    final oldPhoto = profile['photo']?.toString();
    if (oldPhoto != null && oldPhoto.isNotEmpty) {
      oldProfileImageFuture = fetchProfileImage(oldPhoto);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    birthPlaceController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  dynamic safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengambil gambar dari galeri.'),
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
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> selectBirthDate() async {
    DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 10));
    if (apiBirthDate != null && apiBirthDate!.isNotEmpty) {
      try {
        initialDate = DateTime.parse(apiBirthDate!);
      } catch (_) {}
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1980),
      lastDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    if (picked != null) {
      final String day = picked.day.toString().padLeft(2, '0');
      final String month = picked.month.toString().padLeft(2, '0');
      final String year = picked.year.toString();
      setState(() {
        birthDateController.text = '$day-$month-$year';
        apiBirthDate = '$year-$month-$day';
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih jenis kelamin.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null || token.isEmpty) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final request = http.MultipartRequest('POST', Uri.parse(profileUpdateEndpoint));
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['name'] = nameController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['phone'] = phoneController.text.trim();
      request.fields['gender'] = gender!;
      request.fields['birth_place'] = birthPlaceController.text.trim();
      if (apiBirthDate != null) {
        request.fields['birth_date'] = apiBirthDate!;
      }
      if (selectedImage != null && selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      final data = safeJsonDecode(response.body);

      if (streamedResponse.statusCode == 200) {
        if (data != null && data['status'] == true) {
          if (data['data'] != null) {
            await prefs.setString('user', jsonEncode(data['data']));
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (streamedResponse.statusCode == 422) {
        String validationErrors = '';
        if (data != null && data['errors'] != null && data['errors'] is Map) {
          final errorsMap = data['errors'] as Map;
          for (var key in errorsMap.keys) {
            final List messages = errorsMap[key];
            for (var msg in messages) {
              validationErrors += '$msg\n';
            }
          }
        }
        if (validationErrors.isEmpty) {
          validationErrors = data['message'] ?? 'Validasi gagal.';
        }
        throw Exception(validationErrors.trim());
      } else if (streamedResponse.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');
        if (!mounted) return;
        context.go(AppRoutes.login);
        throw Exception('Sesi telah berakhir. Silakan login kembali.');
      } else {
        throw Exception('Gagal memperbarui profil. Error Code: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.toLowerCase().contains('socket') ||
          msg.toLowerCase().contains('failed to connect') ||
          msg.toLowerCase().contains('clientexception')) {
        msg = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
    final oldPhoto = widget.profile?['photo']?.toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Profil'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.profile);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.shade50,
                        backgroundImage: selectedImageBytes != null
                            ? MemoryImage(selectedImageBytes!)
                            : null,
                        child: selectedImageBytes == null
                            ? (oldPhoto != null && oldPhoto.isNotEmpty
                                ? FutureBuilder<Uint8List?>(
                                    future: oldProfileImageFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const CircularProgressIndicator(strokeWidth: 2);
                                      }
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return ClipOval(
                                          child: Image.memory(
                                            snapshot.data!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      }
                                      return const Icon(Icons.person, size: 50, color: Colors.blue);
                                    },
                                  )
                                : const Icon(Icons.person, size: 50, color: Colors.blue))
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: isLoading ? null : pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Ubah Foto Profil'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nama', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'Nama lengkap Anda',
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
                          if (value.trim().length > 255) return 'Nama maksimal 255 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'alamat@email.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Email wajib diisi';
                          if (!value.contains('@')) return 'Format email tidak valid';
                          if (value.trim().length > 255) return 'Email maksimal 255 karakter';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Nomor HP', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: '08xxxxxxxxxx',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Nomor HP wajib diisi';
                          final numStr = value.trim();
                          if (numStr.length < 10) return 'Nomor HP minimal 10 digit';
                          if (numStr.length > 15) return 'Nomor HP maksimal 15 digit';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Jenis Kelamin', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: gender,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.wc_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
                          DropdownMenuItem(value: 'P', child: Text('Perempuan')),
                        ],
                        onChanged: isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  gender = value;
                                });
                              },
                        validator: (value) {
                          if (value == null) return 'Jenis kelamin wajib dipilih';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Tempat Lahir', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: birthPlaceController,
                        decoration: InputDecoration(
                          hintText: 'Kota tempat Anda lahir',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Tanggal Lahir', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: birthDateController,
                        readOnly: true,
                        onTap: isLoading ? null : selectBirthDate,
                        decoration: InputDecoration(
                          hintText: 'DD-MM-YYYY',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'SIMPAN PERUBAHAN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}