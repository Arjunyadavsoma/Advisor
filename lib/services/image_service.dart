// lib/services/image_service.dart - FIXED VERSION
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart'; // ✅ ADD THIS IMPORT
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../auth/auth_service.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _authService = AuthService();
  final _uuid = const Uuid();

  /// Pick image from gallery
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Take photo with camera
  Future<File?> takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }

  /// Compress and optimize image
  Future<File?> compressImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return null;
      
      // Resize if too large
      img.Image resizedImage;
      if (image.width > 1024 || image.height > 1024) {
        resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? 1024 : null,
          height: image.height > image.width ? 1024 : null,
        );
      } else {
        resizedImage = image;
      }
      
      // Compress
      final compressedBytes = img.encodeJpg(resizedImage, quality: 85);
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final compressedFile = File('${tempDir.path}/compressed_${_uuid.v4()}.jpg');
      await compressedFile.writeAsBytes(compressedBytes);
      
      return compressedFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile; // Return original if compression fails
    }
  }

  /// Upload image to Supabase Storage
  Future<String?> uploadImage(File imageFile, String conversationId) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        print('📸 ❌ No authenticated user');
        return null;
      }

      // Compress image first
      final compressedImage = await compressImage(imageFile);
      if (compressedImage == null) {
        print('📸 ❌ Failed to compress image');
        return null;
      }

      final fileName = '${_uuid.v4()}.jpg';
      final filePath = '${user.uid}/$conversationId/$fileName';

      print('📸 Uploading image to: chat-images/$filePath');

      // ✅ FIX: Upload with proper file bytes
      final imageBytes = await compressedImage.readAsBytes();
      
      final response = await _client.storage
          .from('chat-images')
          .uploadBinary(filePath, imageBytes); // ✅ USE uploadBinary instead

      print('📸 Upload response: $response');

      // Get public URL
      final publicUrl = _client.storage
          .from('chat-images')
          .getPublicUrl(filePath);

      print('📸 ✅ Image uploaded successfully: $publicUrl');
      
      // Clean up temp file
      try {
        if (compressedImage.path != imageFile.path) {
          await compressedImage.delete();
        }
      } catch (e) {
        print('Warning: Could not delete temp file: $e');
      }

      return publicUrl;
    } catch (e) {
      print('📸 ❌ Error uploading image: $e');
      return null;
    }
  }

  /// Show image source selection dialog
  Future<File?> showImageSourceDialog(BuildContext context) async {
    return await showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Image Source',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    context,
                    'Camera',
                    Icons.camera_alt,
                    Colors.blue,
                    () async {
                      // ✅ FIX: Single Navigator.pop with result
                      final image = await takePhoto();
                      Navigator.pop(context, image);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSourceOption(
                    context,
                    'Gallery',
                    Icons.photo_library,
                    Colors.green,
                    () async {
                      // ✅ FIX: Single Navigator.pop with result
                      final image = await pickImageFromGallery();
                      Navigator.pop(context, image);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ ADD: Alternative simple image picker without dialog
  Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  /// ✅ ADD: Check if image upload permissions are available
  Future<bool> checkPermissions() async {
    // This would require permission_handler package
    // For now, return true - you can add proper permission checking later
    return true;
  }

  /// ✅ ADD: Get image size for validation
  Future<Map<String, int>?> getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image != null) {
        return {
          'width': image.width,
          'height': image.height,
        };
      }
      return null;
    } catch (e) {
      print('Error getting image dimensions: $e');
      return null;
    }
  }

  /// ✅ ADD: Validate image file
  bool isValidImage(File imageFile) {
    final extension = imageFile.path.toLowerCase().split('.').last;
    final validExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    return validExtensions.contains(extension);
  }

  /// ✅ ADD: Get file size in MB
  Future<double> getFileSizeInMB(File file) async {
    try {
      final bytes = await file.length();
      return bytes / (1024 * 1024); // Convert to MB
    } catch (e) {
      print('Error getting file size: $e');
      return 0.0;
    }
  }
}
