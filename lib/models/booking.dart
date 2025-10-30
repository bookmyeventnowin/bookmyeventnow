import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, accepted, declined, paid }

extension BookingStatusDisplay on BookingStatus {
  String get label => switch (this) {
    BookingStatus.pending => 'Pending',
    BookingStatus.accepted => 'Accepted',
    BookingStatus.declined => 'Declined',
    BookingStatus.paid => 'Paid',
  };

  static BookingStatus fromStorage(String? value) {
    switch (value) {
      case 'accepted':
        return BookingStatus.accepted;
      case 'declined':
        return BookingStatus.declined;
      case 'paid':
        return BookingStatus.paid;
      default:
        return BookingStatus.pending;
    }
  }

  String get storageValue => switch (this) {
    BookingStatus.pending => 'pending',
    BookingStatus.accepted => 'accepted',
    BookingStatus.declined => 'declined',
    BookingStatus.paid => 'paid',
  };
}

class Booking {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String vendorId;
  final String vendorOwnerUid;
  final String vendorName;
  final String vendorCategory;
  final double pricePerHour;
  final int hoursBooked;
  final double totalAmount;
  final DateTime eventDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final BookingStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? paymentReference;

  const Booking({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.vendorId,
    required this.vendorOwnerUid,
    required this.vendorName,
    required this.vendorCategory,
    required this.pricePerHour,
    required this.hoursBooked,
    required this.totalAmount,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentReference,
  });

  factory Booking.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Booking(
      id: doc.id,
      userId: (data['userId'] as String?)?.trim() ?? '',
      userName: (data['userName'] as String?)?.trim() ?? '',
      userEmail: (data['userEmail'] as String?)?.trim() ?? '',
      vendorId: (data['vendorId'] as String?)?.trim() ?? '',
      vendorOwnerUid: (data['vendorOwnerUid'] as String?)?.trim() ?? '',
      vendorName: (data['vendorName'] as String?)?.trim() ?? '',
      vendorCategory: (data['vendorCategory'] as String?)?.trim() ?? '',
      pricePerHour: _toDouble(data['pricePerHour']),
      hoursBooked: _toInt(data['hoursBooked']),
      totalAmount: _toDouble(data['totalAmount']),
      eventDate: _toDate(data['eventDate']) ?? DateTime.now(),
      startTime: _toDate(data['startTime']),
      endTime: _toDate(data['endTime']),
      status: BookingStatusDisplay.fromStorage(data['status'] as String?),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      paymentReference: (data['paymentReference'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'vendorId': vendorId,
      'vendorOwnerUid': vendorOwnerUid,
      'vendorName': vendorName,
      'vendorCategory': vendorCategory,
      'pricePerHour': pricePerHour,
      'hoursBooked': hoursBooked,
      'totalAmount': totalAmount,
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.storageValue,
      'paymentReference': paymentReference,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  Booking copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? vendorId,
    String? vendorOwnerUid,
    String? vendorName,
    String? vendorCategory,
    double? pricePerHour,
    int? hoursBooked,
    double? totalAmount,
    DateTime? eventDate,
    DateTime? startTime,
    DateTime? endTime,
    BookingStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paymentReference,
  }) {
    return Booking(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      vendorId: vendorId ?? this.vendorId,
      vendorOwnerUid: vendorOwnerUid ?? this.vendorOwnerUid,
      vendorName: vendorName ?? this.vendorName,
      vendorCategory: vendorCategory ?? this.vendorCategory,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      hoursBooked: hoursBooked ?? this.hoursBooked,
      totalAmount: totalAmount ?? this.totalAmount,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentReference: paymentReference ?? this.paymentReference,
    );
  }

  bool get awaitingVendor => status == BookingStatus.pending;

  bool get awaitingPayment => status == BookingStatus.accepted;

  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return null;
  }
}
