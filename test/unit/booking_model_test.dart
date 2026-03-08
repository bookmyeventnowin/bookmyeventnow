// test/unit/booking_model_test.dart
//
// Unit tests for the Booking model — parsing, computed properties,
// enum conversions, and copyWith behaviour.
//
// Run: flutter test test/unit/booking_model_test.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyeventnow/models/booking.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseBookingData({
  String status = 'pending',
  String bookingType = 'standard',
  Map<String, dynamic> overrides = const {},
}) {
  return {
    'orderId': 'order-001',
    'userId': 'user-001',
    'userName': 'Raj Kumar',
    'userEmail': 'raj@example.com',
    'vendorId': 'vendor-001',
    'vendorOwnerUid': 'owner-001',
    'vendorName': 'Dream Decorators',
    'vendorCategory': 'Decoration',
    'pricePerHour': 1500.0,
    'hoursBooked': 4,
    'totalAmount': 6000.0,
    'bookingType': bookingType,
    'status': status,
    'eventDate': Timestamp.fromDate(DateTime(2026, 8, 10)),
    'startTime': Timestamp.fromDate(DateTime(2026, 8, 10, 10, 0)),
    'endTime': Timestamp.fromDate(DateTime(2026, 8, 10, 14, 0)),
    'createdAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    'updatedAt': Timestamp.fromDate(DateTime(2026, 3, 1)),
    ...overrides,
  };
}

Future<Booking> _firestoreBooking(
  FakeFirebaseFirestore firestore,
  Map<String, dynamic> data,
) async {
  final ref = await firestore.collection('bookings').add(data);
  final snap = await ref.get();
  return Booking.fromFirestore(snap);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  // ── Booking model: field parsing ──────────────────────────────────────────

  group('Booking.fromFirestore - field parsing', () {
    test('parses all core fields correctly', () async {
      final booking = await _firestoreBooking(firestore, _baseBookingData());
      expect(booking.userId, 'user-001');
      expect(booking.userName, 'Raj Kumar');
      expect(booking.userEmail, 'raj@example.com');
      expect(booking.vendorId, 'vendor-001');
      expect(booking.vendorName, 'Dream Decorators');
      expect(booking.vendorCategory, 'Decoration');
      expect(booking.pricePerHour, 1500.0);
      expect(booking.hoursBooked, 4);
      expect(booking.totalAmount, 6000.0);
    });

    test('parses eventDate from Timestamp', () async {
      final booking = await _firestoreBooking(firestore, _baseBookingData());
      expect(booking.eventDate, DateTime(2026, 8, 10));
    });

    test('parses startTime and endTime from Timestamps', () async {
      final booking = await _firestoreBooking(firestore, _baseBookingData());
      expect(booking.startTime, DateTime(2026, 8, 10, 10, 0));
      expect(booking.endTime, DateTime(2026, 8, 10, 14, 0));
    });

    test('duration is 4 hours when startTime and endTime are set', () async {
      final booking = await _firestoreBooking(firestore, _baseBookingData());
      expect(booking.duration, const Duration(hours: 4));
    });

    test('handles missing optional fields gracefully', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(overrides: {
          'rating': null,
          'review': null,
          'paymentReference': null,
        }),
      );
      expect(booking.rating, isNull);
      expect(booking.review, isNull);
      expect(booking.paymentReference, isNull);
    });

    test('trims whitespace from string fields', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(overrides: {
          'userName': '  Raj Kumar  ',
          'userEmail': ' raj@example.com ',
        }),
      );
      expect(booking.userName, 'Raj Kumar');
      expect(booking.userEmail, 'raj@example.com');
    });
  });

  // ── BookingStatus enum ────────────────────────────────────────────────────

  group('BookingStatus', () {
    test('fromStorage returns pending for unknown values', () {
      expect(BookingStatusDisplay.fromStorage('unknown'), BookingStatus.pending);
      expect(BookingStatusDisplay.fromStorage(null), BookingStatus.pending);
    });

    test('fromStorage maps all known statuses correctly', () {
      expect(BookingStatusDisplay.fromStorage('accepted'), BookingStatus.accepted);
      expect(BookingStatusDisplay.fromStorage('declined'), BookingStatus.declined);
      expect(BookingStatusDisplay.fromStorage('paid'), BookingStatus.paid);
      expect(BookingStatusDisplay.fromStorage('pending'), BookingStatus.pending);
    });

    test('storageValue returns correct string for each status', () {
      expect(BookingStatus.pending.storageValue, 'pending');
      expect(BookingStatus.accepted.storageValue, 'accepted');
      expect(BookingStatus.declined.storageValue, 'declined');
      expect(BookingStatus.paid.storageValue, 'paid');
    });

    test('label returns human-readable string', () {
      expect(BookingStatus.pending.label, 'Pending');
      expect(BookingStatus.paid.label, 'Paid');
    });
  });

  // ── ProposalStatus enum ───────────────────────────────────────────────────

  group('ProposalStatus', () {
    test('fromStorage returns correct status for all values', () {
      expect(ProposalStatusDisplay.fromStorage('sent'), ProposalStatus.sent);
      expect(ProposalStatusDisplay.fromStorage('vendorQuoted'), ProposalStatus.vendorQuoted);
      expect(ProposalStatusDisplay.fromStorage('userCounter'), ProposalStatus.userCounter);
      expect(ProposalStatusDisplay.fromStorage('vendorAccepted'), ProposalStatus.vendorAccepted);
      expect(ProposalStatusDisplay.fromStorage('vendorDeclined'), ProposalStatus.vendorDeclined);
    });

    test('fromStorage returns null for unknown values', () {
      expect(ProposalStatusDisplay.fromStorage('invalid'), isNull);
      expect(ProposalStatusDisplay.fromStorage(null), isNull);
    });

    test('label returns human-readable text', () {
      expect(ProposalStatus.sent.label, 'Proposal sent');
      expect(ProposalStatus.vendorQuoted.label, 'Quote received');
      expect(ProposalStatus.userCounter.label, 'Counter offer sent');
      expect(ProposalStatus.vendorAccepted.label, 'Quote accepted');
      expect(ProposalStatus.vendorDeclined.label, 'Proposal declined');
    });
  });

  // ── Booking computed properties ───────────────────────────────────────────

  group('Booking computed properties', () {
    test('awaitingVendor is true when status is pending', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(status: 'pending'),
      );
      expect(booking.awaitingVendor, isTrue);
    });

    test('awaitingPayment is true when status is accepted', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(status: 'accepted'),
      );
      expect(booking.awaitingPayment, isTrue);
    });

    test('hasRating is false when rating is null', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(overrides: {'rating': null}),
      );
      expect(booking.hasRating, isFalse);
    });

    test('hasRating is false when rating is 0', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(overrides: {'rating': 0}),
      );
      expect(booking.hasRating, isFalse);
    });

    test('hasRating is true when rating is 5', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(overrides: {'rating': 5}),
      );
      expect(booking.hasRating, isTrue);
    });

    test('isCateringProposal is true when bookingType is catering', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(bookingType: 'catering'),
      );
      expect(booking.isCateringProposal, isTrue);
    });

    test('isCateringProposal is false for standard bookings', () async {
      final booking = await _firestoreBooking(
        firestore,
        _baseBookingData(bookingType: 'standard'),
      );
      expect(booking.isCateringProposal, isFalse);
    });
  });

  // ── Booking.copyWith ──────────────────────────────────────────────────────

  group('Booking.copyWith', () {
    test('copyWith updates only the specified field', () async {
      final original = await _firestoreBooking(firestore, _baseBookingData());
      final updated = original.copyWith(status: BookingStatus.paid);
      expect(updated.status, BookingStatus.paid);
      expect(updated.userId, original.userId);
      expect(updated.vendorId, original.vendorId);
      expect(updated.totalAmount, original.totalAmount);
    });

    test('copyWith with rating updates rating and preserves other fields', () async {
      final original = await _firestoreBooking(firestore, _baseBookingData());
      final rated = original.copyWith(rating: 4, review: 'Great service!');
      expect(rated.rating, 4);
      expect(rated.review, 'Great service!');
      expect(rated.hasRating, isTrue);
      expect(rated.vendorName, original.vendorName);
    });
  });

  // ── ProposalMenuItem ──────────────────────────────────────────────────────

  group('ProposalMenuItem', () {
    test('fromMap creates item from valid map', () {
      final item = ProposalMenuItem.fromMap({'name': 'Biryani', 'isVeg': false});
      expect(item, isNotNull);
      expect(item!.name, 'Biryani');
      expect(item.isVeg, isFalse);
    });

    test('fromMap returns null for empty name', () {
      final item = ProposalMenuItem.fromMap({'name': '', 'isVeg': true});
      expect(item, isNull);
    });

    test('fromMap creates veg item from string', () {
      final item = ProposalMenuItem.fromMap('Paneer Tikka');
      expect(item, isNotNull);
      expect(item!.name, 'Paneer Tikka');
      expect(item.isVeg, isTrue);
    });

    test('toMap serializes correctly', () {
      const item = ProposalMenuItem(name: 'Chicken Curry', isVeg: false);
      final map = item.toMap();
      expect(map['name'], 'Chicken Curry');
      expect(map['isVeg'], isFalse);
    });
  });
}
