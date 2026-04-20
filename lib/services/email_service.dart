import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';

@immutable
class RecentEmailRecipient {
  const RecentEmailRecipient({
    required this.email,
    this.customer,
    required this.lastUsedAt,
    required this.usageCount,
  });

  final String email;
  final String? customer;
  final DateTime lastUsedAt;
  final int usageCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'customer': customer,
    'lastUsedAt': lastUsedAt.toIso8601String(),
    'usageCount': usageCount,
  };

  factory RecentEmailRecipient.fromJson(Map<String, Object?> json) {
    return RecentEmailRecipient(
      email: json['email'] as String? ?? '',
      customer: json['customer'] as String?,
      lastUsedAt:
          DateTime.tryParse(json['lastUsedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class EmailHandoffResult {
  const EmailHandoffResult({
    required this.launched,
    required this.recipients,
    required this.subject,
    required this.body,
    required this.attachmentPath,
  });

  final bool launched;
  final List<String> recipients;
  final String subject;
  final String body;
  final String attachmentPath;
}

class EmailServiceException implements Exception {
  EmailServiceException(this.message, {required this.code});

  final String message;
  final EmailServiceErrorCode code;

  @override
  String toString() => 'EmailServiceException($code): $message';
}

enum EmailServiceErrorCode { io, shareFailed, invalidEmail, config }

abstract class EmailShareAdapter {
  Future<void> sharePdf({
    required File pdfFile,
    required String subject,
    required String body,
  });
}

class SharePlusEmailShareAdapter implements EmailShareAdapter {
  const SharePlusEmailShareAdapter();

  @override
  Future<void> sharePdf({
    required File pdfFile,
    required String subject,
    required String body,
  }) async {
    if (!await pdfFile.exists()) {
      throw EmailServiceException(
        'PDF file does not exist: ${pdfFile.path}',
        code: EmailServiceErrorCode.io,
      );
    }

    final result = await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(pdfFile.path)],
        subject: subject,
        text: body,
      ),
    );

    if (result.status == ShareResultStatus.unavailable) {
      throw EmailServiceException(
        'No compatible share target was available.',
        code: EmailServiceErrorCode.shareFailed,
      );
    }
  }
}

class FakeEmailShareAdapter implements EmailShareAdapter {
  FakeEmailShareAdapter({this.shouldThrow = false});

  final bool shouldThrow;
  File? lastSharedPdf;
  String? lastSubject;
  String? lastBody;

  @override
  Future<void> sharePdf({
    required File pdfFile,
    required String subject,
    required String body,
  }) async {
    if (shouldThrow) {
      throw EmailServiceException(
        'Injected share failure.',
        code: EmailServiceErrorCode.shareFailed,
      );
    }
    lastSharedPdf = pdfFile;
    lastSubject = subject;
    lastBody = body;
  }
}

typedef EmailDirectoryProvider = Future<Directory> Function();

abstract class RecipientStore {
  Future<List<RecentEmailRecipient>> loadRecipients();

  Future<void> saveRecipient(String email, {String? customer});

  Future<String?> lookupCustomerEmail(String customer);

  Future<void> saveCustomerEmail({
    required String customer,
    required String email,
  });
}

class JsonFileRecipientStore implements RecipientStore {
  JsonFileRecipientStore({
    EmailDirectoryProvider? documentsDirectoryProvider,
    String fileName = 'cts_email_recipients.json',
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _fileName = fileName;

  final EmailDirectoryProvider _documentsDirectoryProvider;
  final String _fileName;

  @override
  Future<List<RecentEmailRecipient>> loadRecipients() async {
    final payload = await _readPayload();
    final recipients = (payload['recipients'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((entry) => RecentEmailRecipient.fromJson(entry))
        .where((recipient) => recipient.email.trim().isNotEmpty)
        .toList(growable: false);
    recipients.sort(_sortRecipients);
    return recipients;
  }

  @override
  Future<void> saveRecipient(String email, {String? customer}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw EmailServiceException(
        'Recipient email is required.',
        code: EmailServiceErrorCode.invalidEmail,
      );
    }

    final payload = await _readPayload();
    final recipients = (payload['recipients'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((entry) => RecentEmailRecipient.fromJson(entry))
        .toList(growable: true);
    final now = DateTime.now().toUtc();
    final index = recipients.indexWhere(
      (recipient) => _normalizeEmail(recipient.email) == normalizedEmail,
    );
    if (index == -1) {
      recipients.add(
        RecentEmailRecipient(
          email: email.trim(),
          customer: customer?.trim().isEmpty ?? true ? null : customer!.trim(),
          lastUsedAt: now,
          usageCount: 1,
        ),
      );
    } else {
      final current = recipients[index];
      recipients[index] = RecentEmailRecipient(
        email: current.email,
        customer: customer?.trim().isEmpty ?? current.customer == null
            ? current.customer
            : customer!.trim(),
        lastUsedAt: now,
        usageCount: current.usageCount + 1,
      );
    }

    payload['recipients'] = recipients
        .map((recipient) => recipient.toJson())
        .toList(growable: false);
    await _writePayload(payload);

    if (customer != null && customer.trim().isNotEmpty) {
      await saveCustomerEmail(customer: customer, email: email);
    }
  }

  @override
  Future<String?> lookupCustomerEmail(String customer) async {
    final payload = await _readPayload();
    final mappings =
        (payload['customerMappings'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    final value = mappings[_normalizeCustomer(customer)];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  @override
  Future<void> saveCustomerEmail({
    required String customer,
    required String email,
  }) async {
    final normalizedCustomer = _normalizeCustomer(customer);
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedCustomer.isEmpty || normalizedEmail.isEmpty) {
      throw EmailServiceException(
        'Customer and email are required for recipient mapping.',
        code: EmailServiceErrorCode.invalidEmail,
      );
    }

    final payload = await _readPayload();
    final mappings =
        (payload['customerMappings'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    mappings[normalizedCustomer] = email.trim();
    payload['customerMappings'] = mappings;

    final recipients = (payload['recipients'] as List<dynamic>? ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((entry) => RecentEmailRecipient.fromJson(entry))
        .toList(growable: true);
    if (recipients.indexWhere(
          (recipient) => _normalizeEmail(recipient.email) == normalizedEmail,
        ) ==
        -1) {
      recipients.add(
        RecentEmailRecipient(
          email: email.trim(),
          customer: customer.trim(),
          lastUsedAt: DateTime.now().toUtc(),
          usageCount: 1,
        ),
      );
    }
    payload['recipients'] = recipients
        .map((recipient) => recipient.toJson())
        .toList(growable: false);

    await _writePayload(payload);
  }

  Future<List<RecentEmailRecipient>> suggestionsForCustomer({
    required String? customer,
    int limit = AppConstants.recentRecipientLimit,
  }) async {
    final suggestions = <RecentEmailRecipient>[];
    if (customer != null) {
      final mapped = await lookupCustomerEmail(customer);
      if (mapped != null) {
        suggestions.add(
          RecentEmailRecipient(
            email: mapped,
            customer: customer,
            lastUsedAt: DateTime.now().toUtc(),
            usageCount: 1,
          ),
        );
      }
    }
    final recent = await loadRecipients();
    for (final recipient in recent) {
      final duplicate = suggestions.any(
        (suggestion) =>
            _normalizeEmail(suggestion.email) ==
            _normalizeEmail(recipient.email),
      );
      if (!duplicate) {
        suggestions.add(recipient);
      }
    }
    return suggestions.take(limit).toList(growable: false);
  }

  Future<Map<String, dynamic>> _readPayload() async {
    final file = await _storeFile();
    if (!await file.exists()) {
      return <String, dynamic>{
        'recipients': <dynamic>[],
        'customerMappings': <String, dynamic>{},
      };
    }

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        decoded['recipients'] ??= <dynamic>[];
        decoded['customerMappings'] ??= <String, dynamic>{};
        return decoded;
      }
    } on FormatException {
      // Fall through to a fresh payload.
    }

    return <String, dynamic>{
      'recipients': <dynamic>[],
      'customerMappings': <String, dynamic>{},
    };
  }

  Future<void> _writePayload(Map<String, dynamic> payload) async {
    final file = await _storeFile();
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(pretty, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<File> _storeFile() async {
    final documents = await _documentsDirectoryProvider();
    final directory = Directory(p.join(documents.path, 'email'));
    await directory.create(recursive: true);
    return File(p.join(directory.path, _fileName));
  }

  int _sortRecipients(RecentEmailRecipient a, RecentEmailRecipient b) {
    final lastUsedComparison = b.lastUsedAt.compareTo(a.lastUsedAt);
    if (lastUsedComparison != 0) {
      return lastUsedComparison;
    }
    return b.usageCount.compareTo(a.usageCount);
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

  String _normalizeCustomer(String value) => value.trim().toLowerCase();
}

@immutable
class EmailHandoffRequest {
  const EmailHandoffRequest({
    required this.pdfFile,
    required this.subject,
    required this.body,
    this.recipients = const <String>[],
    this.customer,
    this.rememberRecipient = true,
  });

  final File pdfFile;
  final String subject;
  final String body;
  final List<String> recipients;
  final String? customer;
  final bool rememberRecipient;
}

class EmailService {
  EmailService({
    EmailShareAdapter? shareAdapter,
    RecipientStore? recipientStore,
  }) : _shareAdapter = shareAdapter ?? const SharePlusEmailShareAdapter(),
       _recipientStore = recipientStore ?? JsonFileRecipientStore();

  final EmailShareAdapter _shareAdapter;
  final RecipientStore _recipientStore;

  Future<List<RecentEmailRecipient>> recentRecipients({
    int limit = AppConstants.recentRecipientLimit,
  }) async {
    final recipients = await _recipientStore.loadRecipients();
    recipients.sort((a, b) {
      final comparison = b.lastUsedAt.compareTo(a.lastUsedAt);
      if (comparison != 0) {
        return comparison;
      }
      return b.usageCount.compareTo(a.usageCount);
    });
    return recipients.take(limit).toList(growable: false);
  }

  Future<List<RecentEmailRecipient>> recipientSuggestions({
    String? customer,
    int limit = AppConstants.recentRecipientLimit,
  }) {
    if (_recipientStore case final JsonFileRecipientStore store) {
      return store.suggestionsForCustomer(customer: customer, limit: limit);
    }
    return recentRecipients(limit: limit);
  }

  Future<void> rememberRecipient(String email, {String? customer}) {
    return _recipientStore.saveRecipient(email, customer: customer);
  }

  Future<void> saveCustomerRecipientMapping({
    required String customer,
    required String email,
  }) {
    return _recipientStore.saveCustomerEmail(customer: customer, email: email);
  }

  Future<String?> customerRecipient(String customer) {
    return _recipientStore.lookupCustomerEmail(customer);
  }

  Future<EmailHandoffResult> handoffPdf({
    required EmailHandoffRequest request,
  }) async {
    if (!await request.pdfFile.exists()) {
      throw EmailServiceException(
        'PDF file does not exist: ${request.pdfFile.path}',
        code: EmailServiceErrorCode.io,
      );
    }

    final recipients = request.recipients
        .map((recipient) => recipient.trim())
        .where((recipient) => recipient.isNotEmpty)
        .toList(growable: true);

    if (recipients.isEmpty && request.customer != null) {
      final mapped = await customerRecipient(request.customer!);
      if (mapped != null && mapped.trim().isNotEmpty) {
        recipients.add(mapped.trim());
      }
    }

    await _shareAdapter.sharePdf(
      pdfFile: request.pdfFile,
      subject: request.subject,
      body: request.body,
    );

    if (request.rememberRecipient) {
      for (final recipient in recipients) {
        await rememberRecipient(recipient, customer: request.customer);
      }
    }

    return EmailHandoffResult(
      launched: true,
      recipients: recipients,
      subject: request.subject,
      body: request.body,
      attachmentPath: request.pdfFile.path,
    );
  }
}
