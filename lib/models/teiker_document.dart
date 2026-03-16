import 'package:cloud_firestore/cloud_firestore.dart';

class TeikerDocument {
  const TeikerDocument({
    required this.id,
    required this.teikerId,
    required this.fileName,
    required this.downloadUrl,
    required this.storagePath,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.uploadedById,
    required this.uploadedByName,
  });

  final String id;
  final String teikerId;
  final String fileName;
  final String downloadUrl;
  final String storagePath;
  final int sizeBytes;
  final DateTime uploadedAt;
  final String uploadedById;
  final String uploadedByName;

  Map<String, dynamic> toMap() {
    return {
      'teikerId': teikerId,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'storagePath': storagePath,
      'sizeBytes': sizeBytes,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedById': uploadedById,
      'uploadedByName': uploadedByName,
    };
  }

  factory TeikerDocument.fromMap({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return TeikerDocument(
      id: id,
      teikerId: (map['teikerId'] as String?)?.trim() ?? '',
      fileName: (map['fileName'] as String?)?.trim() ?? '',
      downloadUrl: (map['downloadUrl'] as String?)?.trim() ?? '',
      storagePath: (map['storagePath'] as String?)?.trim() ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      uploadedAt: _readDate(map['uploadedAt']) ?? DateTime.now(),
      uploadedById: (map['uploadedById'] as String?)?.trim() ?? '',
      uploadedByName: (map['uploadedByName'] as String?)?.trim() ?? '',
    );
  }

  static DateTime? _readDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }
}
