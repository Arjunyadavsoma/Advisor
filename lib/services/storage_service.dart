// storage_service.dart - CORRECTED VERSION
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final String _bucketName = 'character-images';
  
  // Cache for uploaded file URLs
  final Map<String, String> _urlCache = {};

  /// Upload character image with enhanced error handling and optimization
  Future<String?> uploadCharacterImage(
    File file, 
    String fileName, {
    int maxSizeKB = 2048, // 2MB default
    List<String> allowedExtensions = const ['.jpg', '.jpeg', '.png', '.webp'],
  }) async {
    try {
      // Validate file
      final validationError = _validateFile(file, fileName, maxSizeKB, allowedExtensions);
      if (validationError != null) {
        print('File validation failed: $validationError');
        return null;
      }

      // Generate unique filename to prevent conflicts
      final uniqueFileName = _generateUniqueFileName(fileName);
      
      // Check if bucket exists, create if not
      await _ensureBucketExists();
      
      // Read file bytes
      final bytes = await file.readAsBytes();
      
      print('Uploading ${bytes.length} bytes to $uniqueFileName');
      
      // Upload with retry logic
      await _uploadWithRetry(uniqueFileName, bytes);
      
      // Generate and cache public URL
      final publicUrl = _client.storage
          .from(_bucketName)
          .getPublicUrl(uniqueFileName);
      
      _urlCache[uniqueFileName] = publicUrl;
      
      print('Successfully uploaded: $publicUrl');
      return publicUrl;
      
    } catch (e, stackTrace) {
      print('Error uploading file: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  /// Upload from bytes (useful for web or processed images)
  Future<String?> uploadImageFromBytes(
    Uint8List bytes,
    String fileName, {
    int maxSizeKB = 2048,
  }) async {
    try {
      // Validate size
      if (bytes.length > maxSizeKB * 1024) {
        print('File too large: ${bytes.length} bytes (max: ${maxSizeKB * 1024})');
        return null;
      }

      final uniqueFileName = _generateUniqueFileName(fileName);
      await _ensureBucketExists();
      await _uploadWithRetry(uniqueFileName, bytes);
      
      final publicUrl = _client.storage
          .from(_bucketName)
          .getPublicUrl(uniqueFileName);
      
      _urlCache[uniqueFileName] = publicUrl;
      return publicUrl;
      
    } catch (e) {
      print('Error uploading bytes: $e');
      return null;
    }
  }

  /// Delete character image with enhanced error handling
  Future<bool> deleteCharacterImage(String fileName) async {
    try {
      // Extract filename from URL if full URL is provided
      final actualFileName = _extractFileNameFromUrl(fileName);
      
      await _client.storage
          .from(_bucketName)
          .remove([actualFileName]);
      
      // Remove from cache
      _urlCache.remove(actualFileName);
      
      print('Successfully deleted: $actualFileName');
      return true;
      
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// List all images in the bucket - CORRECTED VERSION
  Future<List<FileObject>> listImages({
    String? path,
  }) async {
    try {
      final files = await _client.storage
          .from(_bucketName)
          .list(path: path);
      
      // Sort manually if needed (since API doesn't support sortBy)
      files.sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
      
      return files;
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }

  /// Get file info - CORRECTED VERSION
  Future<FileObject?> getFileInfo(String fileName) async {
    try {
      final files = await _client.storage
          .from(_bucketName)
          .list();
      
      // Manual search since API doesn't support search parameter
      for (final file in files) {
        if (file.name == fileName || file.name.contains(fileName)) {
          return file;
        }
      }
      
      return null;
    } catch (e) {
      print('Error getting file info: $e');
      return null;
    }
  }

  /// Search files by name - NEW METHOD
  Future<List<FileObject>> searchFiles(String searchTerm) async {
    try {
      final allFiles = await listImages();
      
      return allFiles.where((file) => 
        file.name.toLowerCase().contains(searchTerm.toLowerCase())
      ).toList();
    } catch (e) {
      print('Error searching files: $e');
      return [];
    }
  }

  /// Get paginated files - NEW METHOD
  Future<List<FileObject>> getPaginatedFiles({
    int page = 1,
    int itemsPerPage = 10,
  }) async {
    try {
      final allFiles = await listImages();
      
      final startIndex = (page - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;
      
      if (startIndex >= allFiles.length) {
        return [];
      }
      
      return allFiles.sublist(
        startIndex,
        endIndex > allFiles.length ? allFiles.length : endIndex,
      );
    } catch (e) {
      print('Error getting paginated files: $e');
      return [];
    }
  }

  /// Check if file exists
  Future<bool> fileExists(String fileName) async {
    final info = await getFileInfo(fileName);
    return info != null;
  }

  /// Get cached URL or fetch new one
  String? getCachedUrl(String fileName) {
    return _urlCache[fileName];
  }

  /// Download file as bytes
  Future<Uint8List?> downloadFile(String fileName) async {
    try {
      final bytes = await _client.storage
          .from(_bucketName)
          .download(fileName);
      
      return bytes;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }

  /// Copy file within bucket
  Future<bool> copyFile(String sourceFileName, String destFileName) async {
    try {
      await _client.storage
          .from(_bucketName)
          .copy(sourceFileName, destFileName);
      
      return true;
    } catch (e) {
      print('Error copying file: $e');
      return false;
    }
  }

  /// Move file within bucket
  Future<bool> moveFile(String sourceFileName, String destFileName) async {
    try {
      await _client.storage
          .from(_bucketName)
          .move(sourceFileName, destFileName);
      
      // Update cache
      if (_urlCache.containsKey(sourceFileName)) {
        final url = _urlCache.remove(sourceFileName);
        if (url != null) {
          _urlCache[destFileName] = url;
        }
      }
      
      return true;
    } catch (e) {
      print('Error moving file: $e');
      return false;
    }
  }

  /// Get file public URL
  String getPublicUrl(String fileName) {
    return _client.storage
        .from(_bucketName)
        .getPublicUrl(fileName);
  }

  /// Create signed URL (for private files)
  Future<String?> createSignedUrl(String fileName, {int expiresIn = 3600}) async {
    try {
      final signedUrl = await _client.storage
          .from(_bucketName)
          .createSignedUrl(fileName, expiresIn);
      
      return signedUrl;
    } catch (e) {
      print('Error creating signed URL: $e');
      return null;
    }
  }

  /// Validate file before upload
  String? _validateFile(
    File file,
    String fileName,
    int maxSizeKB,
    List<String> allowedExtensions,
  ) {
    // Check if file exists
    if (!file.existsSync()) {
      return 'File does not exist';
    }
    
    // Check file size
    final fileSizeKB = file.lengthSync() / 1024;
    if (fileSizeKB > maxSizeKB) {
      return 'File too large: ${fileSizeKB.toStringAsFixed(1)}KB (max: ${maxSizeKB}KB)';
    }
    
    // Check file extension
    final fileExtension = path.extension(fileName).toLowerCase();
    if (!allowedExtensions.contains(fileExtension)) {
      return 'Invalid file type: $fileExtension (allowed: ${allowedExtensions.join(', ')})';
    }
    
    return null; // Valid
  }

  /// Generate unique filename to prevent conflicts
  String _generateUniqueFileName(String originalFileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(originalFileName);
    final nameWithoutExt = path.basenameWithoutExtension(originalFileName);
    
    // Create hash of original filename for uniqueness
    final bytes = utf8.encode('$nameWithoutExt$timestamp');
    final hash = sha256.convert(bytes).toString().substring(0, 8);
    
    return '${nameWithoutExt}_${timestamp}_$hash$extension';
  }

  /// Ensure bucket exists
  Future<void> _ensureBucketExists() async {
    try {
      await _client.storage.getBucket(_bucketName);
    } catch (e) {
      // Bucket might not exist, try to create it
      try {
        await _client.storage.createBucket(
          _bucketName,
          BucketOptions(
            public: true,
            allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
            fileSizeLimit: "2097152", // 2MB
          ),
        );
        print('Created bucket: $_bucketName');
      } catch (createError) {
        print('Error creating bucket: $createError');
        // Don't rethrow - bucket might exist but user doesn't have getBucket permission
        print('Continuing without bucket verification...');
      }
    }
  }

  /// Upload with retry logic
  Future<void> _uploadWithRetry(String fileName, Uint8List bytes) async {
    const maxRetries = 3;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _client.storage
            .from(_bucketName)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
        return; // Success
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow; // Last attempt failed
        }
        print('Upload attempt $attempt failed: $e, retrying...');
        await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
      }
    }
  }

  /// Extract filename from full URL
  String _extractFileNameFromUrl(String urlOrFileName) {
    if (urlOrFileName.startsWith('http')) {
      return Uri.parse(urlOrFileName).pathSegments.last;
    }
    return urlOrFileName;
  }

  /// Get bucket stats
  Future<Map<String, dynamic>> getBucketStats() async {
    try {
      final files = await listImages();
      final totalFiles = files.length;
      final totalSize = files.fold<int>(
        0, 
        (sum, file) => sum + (file.metadata?['size'] as int? ?? 0),
      );
      
      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting bucket stats: $e');
      return {'error': e.toString()};
    }
  }

  /// Clear URL cache
  void clearCache() {
    _urlCache.clear();
  }

  /// Test storage connection
  Future<bool> testConnection() async {
    try {
      await _client.storage.listBuckets();
      return true;
    } catch (e) {
      print('Storage connection test failed: $e');
      return false;
    }
  }

  /// Get storage info
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final buckets = await _client.storage.listBuckets();
      final bucket = buckets.firstWhere(
        (b) => b.name == _bucketName,
        orElse: () => Bucket(
          id: '',
          name: _bucketName,
          owner: '',
          createdAt: '',
          updatedAt: '',
          public: false,
        ),
      );
      
      return {
        'bucketName': _bucketName,
        'bucketExists': bucket.id.isNotEmpty,
        'isPublic': bucket.public,
        'createdAt': bucket.createdAt,
      };
    } catch (e) {
      print('Error getting storage info: $e');
      return {'error': e.toString()};
    }
  }
}
