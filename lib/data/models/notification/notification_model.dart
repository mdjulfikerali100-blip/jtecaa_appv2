/// lib/data/models/notification/notification_model.dart
///
/// One entry in the LOCAL Notification History (Hive `notif_cache`,
/// §6.2's "notifications: 7 days" TTL). See fcm_service.dart's header
/// comment for why this is local-only rather than the Firestore
/// `notification_log` collection Architecture §4.2.H describes — that
/// collection is `allow write: if false` for every client and this app
/// has no Cloud Functions/Admin SDK to write it from anywhere else.
class NotificationRecord {
  final String id; // FCM message.messageId, or a local fallback id
  final String title;
  final String body;
  final String type; // 'job' | 'news' | 'other'
  final String? refId; // job/news id from the FCM data payload, if any
  final DateTime receivedAt;
  final bool read;

  const NotificationRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    required this.receivedAt,
    required this.read,
  });

  factory NotificationRecord.fromMap(Map<String, dynamic> map) {
    return NotificationRecord(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? 'Update').toString(),
      body: (map['body'] ?? '').toString(),
      type: (map['type'] ?? 'other').toString(),
      refId: map['refId'] as String?,
      receivedAt: DateTime.tryParse((map['receivedAt'] ?? '').toString()) ??
          DateTime.now(),
      read: map['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'refId': refId,
        'receivedAt': receivedAt.toIso8601String(),
        'read': read,
      };

  NotificationRecord copyWith({bool? read}) => NotificationRecord(
        id: id,
        title: title,
        body: body,
        type: type,
        refId: refId,
        receivedAt: receivedAt,
        read: read ?? this.read,
      );
}
