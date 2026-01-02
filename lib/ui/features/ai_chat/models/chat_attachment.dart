import 'dart:convert';
import 'dart:typed_data';

enum ChatAttachmentType {
  image,
  file,
}

class ChatAttachment {
  ChatAttachment({
    required this.type,
    required this.name,
    required this.mimeType,
    required this.bytes,
    String? id,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  final String id;
  final ChatAttachmentType type;
  final String name;
  final String mimeType;
  final Uint8List bytes;

  bool get isImage => type == ChatAttachmentType.image;

  int get sizeBytes => bytes.lengthInBytes;

  String get sizeLabel => _formatBytes(sizeBytes);

  String toBase64() => base64Encode(bytes);
}

String _formatBytes(int bytes) {
  const kb = 1024;
  const mb = 1024 * 1024;

  if (bytes >= mb) {
    final value = bytes / mb;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} MB';
  }
  if (bytes >= kb) {
    final value = bytes / kb;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} KB';
  }
  return '$bytes B';
}
