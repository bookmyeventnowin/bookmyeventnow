// test/unit/fee_utils_test.dart
//
// Unit tests for fee calculation utilities.
// Tests commission, GST, PG fee, and total breakdown.
//
// Run: flutter test test/unit/fee_utils_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:bookmyeventnow/utils/fee_utils.dart';

void main() {
  group('FeeBreakdown - calculateFeeBreakdown()', () {
    // ─── Happy path ───────────────────────────────────────────────────────────

    test('calculates correct commission (10%) for ₹1000', () {
      final breakdown = calculateFeeBreakdown(1000.0);
      expect(breakdown.commission, closeTo(100.0, 0.01));
    });

    test('calculates correct GST (18% on commission) for ₹1000', () {
      final breakdown = calculateFeeBreakdown(1000.0);
      // GST = 10% of 1000 * 18% = 100 * 0.18 = 18
      expect(breakdown.gst, closeTo(18.0, 0.01));
    });

    test('calculates correct PG fee (2%) for ₹1000', () {
      final breakdown = calculateFeeBreakdown(1000.0);
      expect(breakdown.pgFee, closeTo(20.0, 0.01));
    });

    test('calculates correct total with fees for ₹1000', () {
      final breakdown = calculateFeeBreakdown(1000.0);
      // base=1000, commission=100, gst=18, pgFee=20 → total=1138
      expect(breakdown.totalWithFees, closeTo(1138.0, 0.01));
    });

    test('base amount is preserved in breakdown', () {
      final breakdown = calculateFeeBreakdown(5000.0);
      expect(breakdown.base, equals(5000.0));
    });

    // ─── Scaling ─────────────────────────────────────────────────────────────

    test('fees scale proportionally for ₹2500', () {
      final breakdown = calculateFeeBreakdown(2500.0);
      expect(breakdown.commission, closeTo(250.0, 0.01));
      expect(breakdown.gst, closeTo(45.0, 0.01));
      expect(breakdown.pgFee, closeTo(50.0, 0.01));
      expect(breakdown.totalWithFees, closeTo(2845.0, 0.01));
    });

    test('fees scale correctly for ₹10000 (large booking)', () {
      final breakdown = calculateFeeBreakdown(10000.0);
      expect(breakdown.commission, closeTo(1000.0, 0.01));
      expect(breakdown.gst, closeTo(180.0, 0.01));
      expect(breakdown.pgFee, closeTo(200.0, 0.01));
      expect(breakdown.totalWithFees, closeTo(11380.0, 0.01));
    });

    // ─── Edge cases ──────────────────────────────────────────────────────────

    test('handles zero amount gracefully', () {
      final breakdown = calculateFeeBreakdown(0.0);
      expect(breakdown.commission, equals(0.0));
      expect(breakdown.gst, equals(0.0));
      expect(breakdown.pgFee, equals(0.0));
      expect(breakdown.totalWithFees, equals(0.0));
    });

    test('handles fractional amounts correctly (₹1499.50)', () {
      final breakdown = calculateFeeBreakdown(1499.50);
      expect(breakdown.totalWithFees, closeTo(1707.43, 0.1));
    });

    test('totalWithFees equals sum of all individual components', () {
      final breakdown = calculateFeeBreakdown(3000.0);
      final expected =
          breakdown.base + breakdown.commission + breakdown.gst + breakdown.pgFee;
      expect(breakdown.totalWithFees, closeTo(expected, 0.001));
    });
  });

  group('FeeBreakdown - rate constants', () {
    test('commission rate is 10%', () {
      expect(kCommissionRate, equals(0.10));
    });

    test('GST rate is 18%', () {
      expect(kCommissionGstRate, equals(0.18));
    });

    test('payment gateway rate is 2%', () {
      expect(kPaymentGatewayRate, equals(0.02));
    });
  });
}
