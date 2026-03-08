// integration_test/vendor_flow_test.dart
//
// Integration tests for Vendor Management flows.
// Tests: vendor profile CRUD, subscription activation, vendor filtering,
// rating stream, and vendor repository logic.
//
// Run:
//   flutter test integration_test/vendor_flow_test.dart \
//     --device-id emulator-5554

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:bookmyeventnow/services/vendor_repository.dart';
import 'package:bookmyeventnow/services/booking_repository.dart';
import 'package:bookmyeventnow/models/category.dart';
import 'package:bookmyeventnow/models/vendor.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _baseVendorData({
  String ownerUid = 'owner-001',
  String name = 'Test Vendor',
  String category = 'Decoration',
  String subscriptionStatus = 'active',
  int daysUntilExpiry = 365,
}) {
  return {
    'ownerUid': ownerUid,
    'name': name,
    'category': category,
    'pricePerHour': 2000.0,
    'description': 'Test vendor description',
    'subscriptionStatus': subscriptionStatus,
    'subscriptionExpiresAt': Timestamp.fromDate(
      DateTime.now().add(Duration(days: daysUntilExpiry)),
    ),
    'ratingAverage': 0.0,
    'ratingCount': 0,
    'ratingTotal': 0.0,
    'createdAt': Timestamp.now(),
    'updatedAt': Timestamp.now(),
  };
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FakeFirebaseFirestore firestore;
  late VendorRepository vendorRepo;
  late BookingRepository bookingRepo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    vendorRepo = VendorRepository(firestore: firestore);
    bookingRepo = BookingRepository(firestore: firestore);
  });

  // ── Vendor CRUD ───────────────────────────────────────────────────────────

  group('[VENDOR] Vendor Profile Creation & Update', () {
    test('BMEN-VND-001 | Creates a new vendor profile in Firestore', () async {
      await vendorRepo.upsertVendor(
        id: null,
        ownerUid: 'owner-001',
        data: {
          'name': 'Royal Decorators',
          'category': 'Decoration',
          'pricePerHour': 3000.0,
          'description': 'Premium event decoration services',
        },
      );

      final snap = await firestore
          .collection('vendors')
          .where('ownerUid', isEqualTo: 'owner-001')
          .get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first.data()['name'], 'Royal Decorators');
    });

    test('BMEN-VND-002 | New vendor defaults to inactive subscription', () async {
      await vendorRepo.upsertVendor(
        id: null,
        ownerUid: 'owner-002',
        data: {
          'name': 'New Vendor',
          'category': 'Catering',
          'pricePerHour': 0.0,
        },
      );
      final snap = await firestore
          .collection('vendors')
          .where('ownerUid', isEqualTo: 'owner-002')
          .get();
      expect(snap.docs.first.data()['subscriptionStatus'], 'inactive');
    });

    test('BMEN-VND-003 | Updates existing vendor profile fields', () async {
      await firestore.collection('vendors').doc('vendor-upd').set(_baseVendorData());
      await vendorRepo.upsertVendor(
        id: 'vendor-upd',
        ownerUid: 'owner-001',
        data: {
          'name': 'Updated Vendor Name',
          'pricePerHour': 3500.0,
        },
      );
      final snap = await firestore.collection('vendors').doc('vendor-upd').get();
      expect(snap.data()!['name'], 'Updated Vendor Name');
      expect(snap.data()!['pricePerHour'], 3500.0);
    });

    test('BMEN-VND-004 | Deletes vendor profile from Firestore', () async {
      await firestore.collection('vendors').doc('vendor-del').set(_baseVendorData());
      await vendorRepo.deleteVendor('vendor-del');
      final snap = await firestore.collection('vendors').doc('vendor-del').get();
      expect(snap.exists, isFalse);
    });

    test('BMEN-VND-005 | ownerUid is always stored on create', () async {
      await vendorRepo.upsertVendor(
        id: null,
        ownerUid: 'uid-owner-xyz',
        data: {'name': 'My Vendor', 'category': 'Decoration'},
      );
      final snap = await firestore
          .collection('vendors')
          .where('ownerUid', isEqualTo: 'uid-owner-xyz')
          .get();
      expect(snap.docs.first.data()['ownerUid'], 'uid-owner-xyz');
    });
  });

  // ── Vendor Streaming ──────────────────────────────────────────────────────

  group('[VENDOR] Vendor Streaming', () {
    test('BMEN-VND-006 | streamVendorForOwner returns correct vendor', () async {
      await firestore
          .collection('vendors')
          .doc('v-stream-001')
          .set(_baseVendorData(ownerUid: 'stream-owner'));

      final stream = vendorRepo.streamVendorForOwner('stream-owner');
      final vendor = await stream.first;

      expect(vendor, isNotNull);
      expect(vendor!.ownerUid, 'stream-owner');
    });

    test('BMEN-VND-007 | streamVendorForOwner returns null when no vendor exists',
        () async {
      final stream = vendorRepo.streamVendorForOwner('no-vendor-owner');
      final vendor = await stream.first;
      expect(vendor, isNull);
    });
  });

  // ── Subscription Management ───────────────────────────────────────────────

  group('[VENDOR] Subscription Activation', () {
    test('BMEN-VND-008 | activateSubscription sets status to active', () async {
      await firestore.collection('vendors').doc('v-sub').set(
        _baseVendorData(subscriptionStatus: 'inactive', daysUntilExpiry: -10),
      );

      await vendorRepo.activateSubscription(
        vendorId: 'v-sub',
        amount: 2999.0,
      );

      final snap = await firestore.collection('vendors').doc('v-sub').get();
      expect(snap.data()!['subscriptionStatus'], 'active');
    });

    test('BMEN-VND-009 | Subscription expires approximately 365 days from now',
        () async {
      await firestore.collection('vendors').doc('v-sub-exp').set(
        _baseVendorData(subscriptionStatus: 'inactive', daysUntilExpiry: -1),
      );

      final before = DateTime.now();
      await vendorRepo.activateSubscription(
        vendorId: 'v-sub-exp',
        amount: 2999.0,
        duration: const Duration(days: 365),
      );
      final after = before.add(const Duration(days: 365));

      final snap = await firestore.collection('vendors').doc('v-sub-exp').get();
      final expiryRaw = snap.data()!['subscriptionExpiresAt'] as Timestamp;
      final expiry = expiryRaw.toDate();

      expect(expiry.isAfter(before), isTrue);
      expect(expiry.isBefore(after.add(const Duration(seconds: 5))), isTrue);
    });

    test('BMEN-VND-010 | Renewing active subscription extends from current expiry',
        () async {
      final futureExpiry = DateTime.now().add(const Duration(days: 100));
      await firestore.collection('vendors').doc('v-renew').set({
        ..._baseVendorData(),
        'subscriptionStatus': 'active',
        'subscriptionExpiresAt': Timestamp.fromDate(futureExpiry),
      });

      await vendorRepo.activateSubscription(
        vendorId: 'v-renew',
        amount: 2999.0,
        duration: const Duration(days: 365),
      );

      final snap = await firestore.collection('vendors').doc('v-renew').get();
      final newExpiry =
          (snap.data()!['subscriptionExpiresAt'] as Timestamp).toDate();

      // Should be ~100 + 365 = 465 days from now
      final expectedMin = DateTime.now().add(const Duration(days: 460));
      expect(newExpiry.isAfter(expectedMin), isTrue);
    });

    test('BMEN-VND-011 | activateSubscription records amount paid', () async {
      await firestore.collection('vendors').doc('v-amt').set(
        _baseVendorData(subscriptionStatus: 'inactive', daysUntilExpiry: -5),
      );
      await vendorRepo.activateSubscription(
        vendorId: 'v-amt',
        amount: 4999.0,
      );
      final snap = await firestore.collection('vendors').doc('v-amt').get();
      expect(snap.data()!['subscriptionAmountLastPaid'], 4999.0);
    });

    test('BMEN-VND-012 | Activating non-existent vendor throws StateError', () async {
      expect(
        () => vendorRepo.activateSubscription(
          vendorId: 'non-existent',
          amount: 2999.0,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ── Vendor Rating Summary ─────────────────────────────────────────────────

  group('[VENDOR] Rating Summary Stream', () {
    test('BMEN-VND-013 | Rating summary is empty when vendor has no bookings',
        () async {
      final summary =
          await bookingRepo.streamVendorRatingSummary('no-bookings-v').first;
      expect(summary.hasRatings, isFalse);
      expect(summary.count, 0);
      expect(summary.average, isNull);
    });

    test('BMEN-VND-014 | Rating summary reflects ratings from bookings', () async {
      final date = DateTime(2027, 1, 10);

      await firestore.collection('vendors').doc('v-rating-sum').set({
        'ratingTotal': 0.0, 'ratingCount': 0, 'ratingAverage': 0.0,
      });

      final id1 = await bookingRepo.createBooking(
        userId: 'u1', userName: 'U1', userEmail: 'u1@e.com',
        vendorId: 'v-rating-sum', vendorOwnerUid: 'o-rs',
        vendorName: 'Rating Sum Vendor', vendorCategory: 'Decoration',
        pricePerHour: 1000.0,
        startTime: DateTime(date.year, date.month, date.day, 9, 0),
        endTime: DateTime(date.year, date.month, date.day, 11, 0),
        eventDate: date,
      );

      await bookingRepo.submitRating(bookingId: id1, rating: 4);

      final summary =
          await bookingRepo.streamVendorRatingSummary('v-rating-sum').first;
      expect(summary.hasRatings, isTrue);
      expect(summary.count, 1);
      expect(summary.average, closeTo(4.0, 0.01));
    });
  });

  // ── Vendor Category Filtering ─────────────────────────────────────────────

  group('[VENDOR] Category-Based Vendor Filtering', () {
    setUp(() async {
      await firestore.collection('vendors').doc('v-dec-1').set(
        _baseVendorData(name: 'Decor A', category: 'Decoration'),
      );
      await firestore.collection('vendors').doc('v-dec-2').set(
        _baseVendorData(name: 'Decor B', category: 'Decoration'),
      );
      await firestore.collection('vendors').doc('v-cat-1').set(
        _baseVendorData(name: 'Caterer A', category: 'Catering'),
      );
      await firestore.collection('vendors').doc('v-inactive').set(
        _baseVendorData(
          name: 'Inactive Vendor',
          category: 'Decoration',
          subscriptionStatus: 'inactive',
        ),
      );
    });

    test('BMEN-VND-015 | Only active vendors are returned in category stream',
        () async {
      final decorCategory = Category(id: 'dec', name: 'Decoration');
      final stream = vendorRepo.streamVendorsForCategory(category: decorCategory);
      final vendors = await stream.first;

      // Should include active decorators but NOT v-inactive
      expect(vendors.every((v) => v.isSubscriptionActive), isTrue);
      final names = vendors.map((v) => v.name).toList();
      expect(names, isNot(contains('Inactive Vendor')));
    });
  });
}
