import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../collections_intelligence/collection_insight.dart';

class CollectionMessageOpenResult {
  final bool opened;
  final String message;

  const CollectionMessageOpenResult({
    required this.opened,
    required this.message,
  });
}

class CollectionMessageService {
  const CollectionMessageService();

  String generateMessage(CollectionInsight insight) => insight.suggestedMessage;

  String normalizeDominicanPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return '1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return digits;
    return digits;
  }

  Uri whatsappUri({required String phone, required String message}) {
    return Uri.https('wa.me', '/${normalizeDominicanPhone(phone)}', {
      'text': message,
    });
  }

  Future<CollectionMessageOpenResult> openWhatsAppMessage(
    CollectionInsight insight,
  ) async {
    final message = generateMessage(insight);
    final uri = whatsappUri(phone: insight.clientPhone, message: message);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await Clipboard.setData(ClipboardData(text: message));
    }
    return CollectionMessageOpenResult(opened: opened, message: message);
  }
}
