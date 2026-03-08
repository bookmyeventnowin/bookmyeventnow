// test/helpers/firebase_test_helpers.dart
//
// Shared helpers for setting up Firebase fakes in unit and widget tests.
// Uses fake_cloud_firestore and firebase_auth_mocks.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns a [FakeFirebaseFirestore] pre-seeded with a test vendor.
FakeFirebaseFirestore createFakeFirestore({
  bool seedVendor = false,
  bool seedBooking = false,
}) {
  final firestore = FakeFirebaseFirestore();

  if (seedVendor) {
    firestore.collection('vendors').doc('vendor-001').set({
      'ownerUid': 'vendor-uid-001',
      'name': 'Test Decorator',
      'category': 'Decoration',
      'pricePerHour': 2500.0,
      'description': 'Premium event decoration services',
      'subscriptionStatus': 'active',
      'subscriptionExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 300)),
      ),
      'ratingAverage': 4.5,
      'ratingCount': 10,
      'ratingTotal': 45.0,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  if (seedBooking) {
    firestore.collection('bookings').doc('booking-001').set({
      'userId': 'user-uid-001',
      'userName': 'Test User',
      'userEmail': 'test@example.com',
      'vendorId': 'vendor-001',
      'vendorOwnerUid': 'vendor-uid-001',
      'vendorName': 'Test Decorator',
      'vendorCategory': 'Decoration',
      'pricePerHour': 2500.0,
      'hoursBooked': 3,
      'totalAmount': 7500.0,
      'bookingType': 'standard',
      'status': 'pending',
      'eventDate': Timestamp.fromDate(DateTime(2026, 6, 15)),
      'startTime': Timestamp.fromDate(DateTime(2026, 6, 15, 9, 0)),
      'endTime': Timestamp.fromDate(DateTime(2026, 6, 15, 12, 0)),
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  return firestore;
}

/// A pre-configured [MockFirebaseAuth] with a signed-in user.
MockFirebaseAuth createMockAuth({bool signedIn = false}) {
  final mockUser = MockUser(
    isAnonymous: false,
    uid: 'user-uid-001',
    email: 'test@example.com',
    displayName: 'Test User',
  );
  return MockFirebaseAuth(
    mockUser: mockUser,
    signedIn: signedIn,
  );
}

/// A pre-configured [MockGoogleSignIn].
MockGoogleSignIn createMockGoogleSignIn() => MockGoogleSignIn();
