import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus { pending, accepted, declined, paid }

enum ProposalStatus {
  sent,
  vendorQuoted,
  userCounter,
  vendorAccepted,
  vendorDeclined,
}

extension ProposalStatusDisplay on ProposalStatus {
  String get label => switch (this) {
        ProposalStatus.sent => 'Proposal sent',
        ProposalStatus.vendorQuoted => 'Quote received',
        ProposalStatus.userCounter => 'Counter offer sent',
        ProposalStatus.vendorAccepted => 'Quote accepted',
        ProposalStatus.vendorDeclined => 'Proposal declined',
      };

  String get storageValue => switch (this) {
        ProposalStatus.sent => 'sent',
        ProposalStatus.vendorQuoted => 'vendorQuoted',
        ProposalStatus.userCounter => 'userCounter',
        ProposalStatus.vendorAccepted => 'vendorAccepted',
        ProposalStatus.vendorDeclined => 'vendorDeclined',
      };

  static ProposalStatus? fromStorage(String? value) {
    switch (value) {
      case 'sent':
        return ProposalStatus.sent;
      case 'vendorQuoted':
        return ProposalStatus.vendorQuoted;
      case 'userCounter':
        return ProposalStatus.userCounter;
      case 'vendorAccepted':
        return ProposalStatus.vendorAccepted;
      case 'vendorDeclined':
        return ProposalStatus.vendorDeclined;
      default:
        return null;
    }
  }
}

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
  // Logical group identifier for multiple slots booked in one user flow.
  // If null, the booking is treated as its own order.
  final String? orderId;
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
  final String bookingType;
  final DateTime eventDate;
  final DateTime? startTime;
  final DateTime? endTime;
  final BookingStatus status;
  final ProposalStatus? proposalStatus;
  final List<ProposalMenuItem> proposalMenu;
  final int? proposalGuestCount;
  final bool proposalDeliveryRequired;
  final String? proposalDeliveryAddress;
  final DateTime? proposalDeliveryTime;
  final double? vendorQuoteAmount;
  final double? userCounterAmount;
  final double? agreedAmount;
  final String? proposalNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? paymentReference;
  final int? rating;
  final String? review;
  final DateTime? ratedAt;

  const Booking({
    required this.id,
    required this.orderId,
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
    required this.bookingType,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.proposalStatus,
    required this.proposalMenu,
    required this.proposalGuestCount,
    required this.proposalDeliveryRequired,
    required this.proposalDeliveryAddress,
    required this.proposalDeliveryTime,
    required this.vendorQuoteAmount,
    required this.userCounterAmount,
    required this.agreedAmount,
    required this.proposalNotes,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentReference,
    required this.rating,
    required this.review,
    required this.ratedAt,
  });

  factory Booking.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawOrderId = (data['orderId'] as String?)?.trim();
    return Booking(
      id: doc.id,
      orderId: (rawOrderId != null && rawOrderId.isNotEmpty) ? rawOrderId : doc.id,
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
      bookingType: (data['bookingType'] as String?)?.trim() ?? 'standard',
      eventDate: _toDate(data['eventDate']) ?? DateTime.now(),
      startTime: _toDate(data['startTime']),
      endTime: _toDate(data['endTime']),
      status: BookingStatusDisplay.fromStorage(data['status'] as String?),
      proposalStatus: ProposalStatusDisplay.fromStorage(
        data['proposalStatus'] as String?,
      ),
      proposalMenu: _parseProposalMenu(data['proposalMenu']),
      proposalGuestCount: _toIntNullable(data['proposalGuestCount']),
      proposalDeliveryRequired: data['proposalDeliveryRequired'] == true,
      proposalDeliveryAddress:
          (data['proposalDeliveryAddress'] as String?)?.trim(),
      proposalDeliveryTime: _toDate(data['proposalDeliveryTime']),
      vendorQuoteAmount: _toDoubleNullable(data['vendorQuoteAmount']),
      userCounterAmount: _toDoubleNullable(data['userCounterAmount']),
      agreedAmount: _toDoubleNullable(
        data['agreedAmount'] ?? data['finalAmount'],
      ),
      proposalNotes: (data['proposalNotes'] as String?)?.trim(),
      createdAt: _toDate(data['createdAt']),
      updatedAt: _toDate(data['updatedAt']),
      paymentReference: (data['paymentReference'] as String?)?.trim(),
      rating: _toIntNullable(data['rating']),
      review: (data['review'] as String?)?.trim(),
      ratedAt: _toDate(data['ratedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
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
      'bookingType': bookingType,
      'eventDate': Timestamp.fromDate(eventDate),
      'startTime': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.storageValue,
      'proposalStatus': proposalStatus?.storageValue,
      'proposalMenu': proposalMenu.map((item) => item.toMap()).toList(),
      'proposalGuestCount': proposalGuestCount,
      'proposalDeliveryRequired': proposalDeliveryRequired,
      'proposalDeliveryAddress': proposalDeliveryAddress,
      'proposalDeliveryTime': proposalDeliveryTime != null
          ? Timestamp.fromDate(proposalDeliveryTime!)
          : null,
      'vendorQuoteAmount': vendorQuoteAmount,
      'userCounterAmount': userCounterAmount,
      'agreedAmount': agreedAmount,
      'proposalNotes': proposalNotes,
      'paymentReference': paymentReference,
      'rating': rating,
      'review': review,
      'ratedAt': ratedAt != null ? Timestamp.fromDate(ratedAt!) : null,
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
    String? orderId,
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
    String? bookingType,
    DateTime? eventDate,
    DateTime? startTime,
    DateTime? endTime,
    BookingStatus? status,
    ProposalStatus? proposalStatus,
    List<ProposalMenuItem>? proposalMenu,
    int? proposalGuestCount,
    bool? proposalDeliveryRequired,
    String? proposalDeliveryAddress,
    DateTime? proposalDeliveryTime,
    double? vendorQuoteAmount,
    double? userCounterAmount,
    double? agreedAmount,
    String? proposalNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? paymentReference,
    int? rating,
    String? review,
    DateTime? ratedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
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
      bookingType: bookingType ?? this.bookingType,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      proposalStatus: proposalStatus ?? this.proposalStatus,
      proposalMenu: proposalMenu ?? this.proposalMenu,
      proposalGuestCount: proposalGuestCount ?? this.proposalGuestCount,
      proposalDeliveryRequired:
          proposalDeliveryRequired ?? this.proposalDeliveryRequired,
      proposalDeliveryAddress:
          proposalDeliveryAddress ?? this.proposalDeliveryAddress,
      proposalDeliveryTime:
          proposalDeliveryTime ?? this.proposalDeliveryTime,
      vendorQuoteAmount: vendorQuoteAmount ?? this.vendorQuoteAmount,
      userCounterAmount: userCounterAmount ?? this.userCounterAmount,
      agreedAmount: agreedAmount ?? this.agreedAmount,
      proposalNotes: proposalNotes ?? this.proposalNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paymentReference: paymentReference ?? this.paymentReference,
      rating: rating ?? this.rating,
      review: review ?? this.review,
      ratedAt: ratedAt ?? this.ratedAt,
    );
  }

  bool get awaitingVendor => status == BookingStatus.pending;

  bool get awaitingPayment => status == BookingStatus.accepted;

  bool get hasRating => rating != null && rating! > 0;

  bool get isCateringProposal => bookingType == 'catering';

  bool get hasVendorQuote =>
      proposalStatus == ProposalStatus.vendorQuoted ||
      proposalStatus == ProposalStatus.vendorAccepted;

  bool get hasUserCounter => proposalStatus == ProposalStatus.userCounter;

  Duration? get duration {
    if (startTime == null || endTime == null) return null;
    return endTime!.difference(startTime!);
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int? _toIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _toDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
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

  static List<ProposalMenuItem> _parseProposalMenu(dynamic value) {
    if (value is Iterable) {
      return value
          .map(ProposalMenuItem.fromMap)
          .whereType<ProposalMenuItem>()
          .toList(growable: false);
    }
    return const <ProposalMenuItem>[];
  }
}

class ProposalMenuItem {
  final String name;
  final bool isVeg;

  const ProposalMenuItem({required this.name, required this.isVeg});

  Map<String, dynamic> toMap() => {
        'name': name,
        'isVeg': isVeg,
      };

  static ProposalMenuItem? fromMap(dynamic value) {
    if (value is ProposalMenuItem) return value;
    if (value is Map<String, dynamic>) {
      final name = (value['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      return ProposalMenuItem(
        name: name,
        isVeg: value['isVeg'] == true,
      );
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return ProposalMenuItem(name: trimmed, isVeg: true);
    }
    return null;
  }
}



