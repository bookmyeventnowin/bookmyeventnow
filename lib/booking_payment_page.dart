import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'models/booking.dart';
import 'user_navigation.dart';
import 'payment/razorpay_keys.dart';
import 'services/booking_repository.dart';
import 'utils/dialog_utils.dart';
import 'utils/fee_utils.dart';

const Color _backgroundCream = Color(0xFFFEFAF4);
const Color _cardSurface = Colors.white;

class BookingPaymentPage extends StatefulWidget {
  /// Primary booking used for display (vendor, category, etc.).
  ///
  /// When [orderBookings] is provided, this is typically the first booking
  /// in that logical order.
  final Booking booking;

  /// Optional list of bookings that belong to the same logical order.
  /// When provided, the payment amount and summary are calculated from
  /// the combined total of these bookings, and payment completion updates
  /// all of them to `paid`.
  final List<Booking>? orderBookings;

  const BookingPaymentPage({
    required this.booking,
    this.orderBookings,
    super.key,
  });

  @override
  State<BookingPaymentPage> createState() => _BookingPaymentPageState();
}

class _BookingPaymentPageState extends State<BookingPaymentPage> {
  final BookingRepository _bookingRepository = BookingRepository();
  late final Razorpay _razorpay;
  bool _processing = false;

  List<Booking> get _bookings {
    final fromOrder = widget.orderBookings;
    if (fromOrder == null || fromOrder.isEmpty) {
      return <Booking>[widget.booking];
    }
    return fromOrder;
  }

  double get _combinedBaseAmount {
    return _bookings.fold<double>(
      0,
      (sum, booking) => sum + booking.totalAmount,
    );
  }

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
    final bookings = _bookings;
    final primary = bookings.first;
    final feeBreakdown = calculateFeeBreakdown(_combinedBaseAmount);
    final total = feeBreakdown.totalWithFees;
    final itemTotal = feeBreakdown.base;
    final taxesAndFee = feeBreakdown.totalWithFees - feeBreakdown.base;
    final price = primary.pricePerHour;
    final isMultiDate = bookings.length > 1;
    final timeRange = isMultiDate ? null : _formatTimeRange(primary);
    return Scaffold(
      backgroundColor: _backgroundCream,
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: _cardSurface,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: _cardSurface,
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
                    _summaryRow('Vendor', primary.vendorName),
                    _summaryRow('Category', primary.vendorCategory),
                    if (!isMultiDate) ...[
                      _summaryRow(
                        'Event date',
                        _formatDate(primary.eventDate),
                      ),
                      if (timeRange != null)
                        _summaryRow('Time window', timeRange),
                      _summaryRow(
                        'Duration',
                        '${primary.hoursBooked} hr${primary.hoursBooked == 1 ? '' : 's'}',
                      ),
                    ] else ...[
                      _summaryRow(
                        'Event dates',
                        '${bookings.length} slots',
                      ),
                      const SizedBox(height: 8),
                      ...bookings.map((b) {
                        final tr = _formatTimeRange(b);
                        final hrs = b.hoursBooked;
                        final timeLabel =
                            tr != null ? ' | $tr ($hrs hr${hrs == 1 ? '' : 's'})' : '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '- ${_formatDate(b.eventDate)}$timeLabel',
                          ),
                        );
                      }),
                    ],
                    _summaryRow('Rate per hour', _formatCurrency(price)),
                    const Divider(height: 28),
                    const Text(
                      'Payment summary',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _summaryRow('Item total', _formatCurrency(itemTotal)),
                    _summaryRow(
                      'Taxes & fee',
                      _formatCurrency(taxesAndFee),
                      onInfoTap: () => showFeeBreakdownDialog(
                        context: context,
                        breakdown: feeBreakdown,
                        formatCurrency: _formatCurrency,
                      ),
                    ),
                    const Divider(height: 24),
                    _summaryRow(
                      'Amount to pay',
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
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
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
    if (_processing) return;
    final bookings = _bookings;
    final primary = bookings.first;
    final amount = calculateFeeBreakdown(_combinedBaseAmount).totalWithFees;
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
      'description': bookings.length == 1
          ? 'Booking payment'
          : 'Booking payment for ${bookings.length} dates',
      'prefill': {
        'contact': primary.userEmail,
        'email': primary.userEmail,
      },
      'notes': {
        'bookingId': primary.id,
        'vendorId': primary.vendorId,
        if (bookings.length > 1) 'orderSize': bookings.length.toString(),
      },
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
      final bookings = _bookings;
      for (final booking in bookings) {
        await _bookingRepository.updateStatus(
          bookingId: booking.id,
          status: BookingStatus.paid,
          paymentReference: paymentId,
        );
      }
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

  Widget _summaryRow(
    String label,
    String value, {
    bool emphasize = false,
    VoidCallback? onInfoTap,
  }) {
    final style = emphasize
        ? const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)
        : const TextStyle(fontSize: 14, fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Text(label)),
                if (onInfoTap != null)
                  IconButton(
                    onPressed: onInfoTap,
                    icon: const Icon(Icons.info_outline, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    tooltip: 'View fee breakdown',
                  ),
              ],
            ),
          ),
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
