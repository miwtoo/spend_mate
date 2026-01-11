import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spend_mate/ui/features/ai_chat/models/chat_attachment.dart';

void main() {
  group('ChatAttachment', () {
    test('formats size labels', () {
      final small = ChatAttachment(
        type: ChatAttachmentType.file,
        name: 'small.txt',
        mimeType: 'text/plain',
        bytes: Uint8List(512),
      );
      final kb = ChatAttachment(
        type: ChatAttachmentType.file,
        name: 'kb.txt',
        mimeType: 'text/plain',
        bytes: Uint8List(2048),
      );
      final mb = ChatAttachment(
        type: ChatAttachmentType.file,
        name: 'mb.txt',
        mimeType: 'text/plain',
        bytes: Uint8List(10 * 1024 * 1024),
      );

      expect(small.sizeLabel, '512 B');
      expect(kb.sizeLabel, '2.0 KB');
      expect(mb.sizeLabel, '10 MB');
    });

    test('identifies image attachments and base64 encodes bytes', () {
      final attachment = ChatAttachment(
        type: ChatAttachmentType.image,
        name: 'photo.png',
        mimeType: 'image/png',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(attachment.isImage, isTrue);
      expect(attachment.toBase64(), 'AQID');
    });
  });
}
