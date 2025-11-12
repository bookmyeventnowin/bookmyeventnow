import 'package:flutter/material.dart';

import 'fee_utils.dart';

typedef CurrencyFormatter = String Function(double value);

void showFeeBreakdownDialog({
  required BuildContext context,
  required FeeBreakdown breakdown,
  required CurrencyFormatter formatCurrency,
  bool includeCommission = true,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Taxes & fee breakdown'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (includeCommission)
            _row(
              'Platform commission (10%)',
              breakdown.commission,
              formatCurrency,
            ),
          _row(
            includeCommission ? 'GST on commission (18%)' : 'GST (18%)',
            breakdown.gst,
            formatCurrency,
          ),
          _row('Payment gateway (~2%)', breakdown.pgFee, formatCurrency),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _row(String label, double amount, CurrencyFormatter formatCurrency) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(formatCurrency(amount)),
      ],
    ),
  );
}
