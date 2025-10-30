import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'models/booking.dart';
import 'user_navigation.dart';
import 'payment/razorpay_keys.dart';
import 'services/booking_repository.dart';

const Color _milkWhite = Color(0xFFF4F1FF);

class BookingPaymentPage extends StatefulWidget {
  final Booking booking;
  const BookingPaymentPage({required this.booking, super.key});

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  final BookingRepository _bookingRepository = BookingRepository();
  late final Razorpay _razorpay;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final total = booking.totalAmount;
    final price = booking.pricePerHour;
    final timeRange = _formatTimeRange(booking);
    return Scaffold(
      backgroundColor: _milkWhite,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: _milkWhite,
        elevation: 0.2,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: _milkWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _summaryRow('Vendor', booking.vendorName),
                    _summaryRow('Category', booking.vendorCategory),
                    _summaryRow('Event date', _formatDate(booking.eventDate)),
                    if (timeRange != null)
                      _summaryRow('Time window', timeRange),
                    _summaryRow(
                      'Duration',
                      '${booking.hoursBooked} hr${booking.hoursBooked == 1 ? '' : 's'}',
                    ),
                    _summaryRow('Rate per hour', _formatCurrency(price)),
                    const Divider(height: 28),
                    _summaryRow(
                      'Amount due',
                      _formatCurrency(total),
                      emphasize: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _processing ? null : _handlePayment,
                icon: _processing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.credit_card_outlined),
                label: Text(
                  _processing ? 'Processing...' : 'Pay with Razorpay (Test)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2ECFF),
                  foregroundColor: Colors.deepPurple,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: userNavIndex,
        builder: (_, index, __) => UserBottomNav(currentIndex: index),
      ),
    );
  }

  Future<void> _handlePayment() async {
    final booking = widget.booking;
    final amount = booking.totalAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This booking does not require a payment amount.'),
        ),
      );
      return;
    }

    setState(() => _processing = true);
    final options = {
      'key': razorpayKeyId,
      'amount': (amount * 100).round(),
      'currency': 'INR',
      'name': 'BookMyEventNow',
      'description': 'Booking payment',
      'prefill': {'contact': booking.userEmail, 'email': booking.userEmail},
      'notes': {'bookingId': booking.id, 'vendorId': booking.vendorId},
    };

    try {
      _razorpay.open(options);
    } catch (error) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start payment: $error')),
      );
    }
  }

  Future<void> _completePayment(String paymentId) async {
    try {
      await _bookingRepository.updateStatus(
        bookingId: widget.booking.id,
        status: BookingStatus.paid,
        paymentReference: paymentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment successful via Razorpay (Test)')),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment captured, but updating booking failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    _completePayment(response.paymentId ?? 'RAZORPAY_TEST_PAYMENT');
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment failed: ${response.message ?? response.code.toString()}',
        ),
      ),
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'Unknown'}',
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool emphasize = false}) {
    final style = emphasize
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
        : const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    if (value == 0) return 'Rs 0';
    if (value >= 100000) {
      final lakhValue = value / 100000;
      return 'Rs ${lakhValue.toStringAsFixed(1)}L';
    }
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return 'Rs $formatted';
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  String? _formatTimeRange(Booking booking) {
    final start = booking.startTime;
    final end = booking.endTime;
    if (start == null || end == null) return null;
    final localizations = MaterialLocalizations.of(context);
    final startLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
      alwaysUse24HourFormat: false,
    );
    final endLabel = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(end),
      alwaysUse24HourFormat: false,
    );
    return '$startLabel - $endLabel';
  }
}
