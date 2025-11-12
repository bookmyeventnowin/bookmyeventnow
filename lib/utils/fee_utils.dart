const double kCommissionRate = 0.10;
const double kCommissionGstRate = 0.18;
const double kPaymentGatewayRate = 0.02;

class FeeBreakdown {
  const FeeBreakdown({
    required this.base,
    required this.commission,
    required this.gst,
    required this.pgFee,
  });

  final double base;
  final double commission;
  final double gst;
  final double pgFee;

  double get totalWithFees => base + commission + gst + pgFee;
}

FeeBreakdown calculateFeeBreakdown(double amount) {
  final commission = amount * kCommissionRate;
  final gst = commission * kCommissionGstRate;
  final pgFee = amount * kPaymentGatewayRate;
  return FeeBreakdown(
    base: amount,
    commission: commission,
    gst: gst,
    pgFee: pgFee,
  );
}
