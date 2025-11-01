import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/booking.dart';
import 'models/category.dart';
import 'models/vendor.dart';
import 'services/booking_repository.dart';
import 'services/vendor_repository.dart';
import 'user_navigation.dart';

const _creamBackground = Color(0xFFFEFBE7);
const _vendorCardBackground = Color(0xFFE4EDD5);
const _vendorPrimaryText = Color(0xFF0E3A28);
const _vendorSecondaryText = Color(0xFF1A4A33);
const _vendorButtonColor = Color(0xFF0F5B33);
const _vendorAvatarBackground = Color(0xFF0C4227);

const _detailCardColor = Color(0xFFF6EFD9);
const _detailChipColor = Color(0xFFE4EDD5);
const _detailChipText = Color(0xFF1D4B2B);
const _detailMutedText = Color(0xFF4B624B);
const _detailDivider = Color(0xFFE0D7BF);

const _bookingSheetBackground = Color(0xFFF5EBD5);
const _bookingChipColor = Color(0xFFE8F0DA);
const _bookingChipSelected = Color(0xFFD3E1C0);
const _bookingChipText = Color(0xFF1D4B2B);
const _bookingMutedText = Color(0xFF5B7053);
const _bookingBorderColor = Color(0xFFD6CCB5);

class VendorListPage extends StatefulWidget {
  const VendorListPage({required this.category, super.key});

  final Category category;

  @override
  State<VendorListPage> createState() => _VendorListPageState();
}

class _VendorListPageState extends State<VendorListPage> {
  final BookingRepository _bookingRepository = BookingRepository();
  final VendorRepository _vendorRepository = VendorRepository();
  final TextEditingController _filterController = TextEditingController();
  final FocusNode _filterFocusNode = FocusNode();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    _filterFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = widget.category.name;
    return Scaffold(
      backgroundColor: _creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text('Vendors: $heading'),
      ),
      body: StreamBuilder<List<Vendor>>(
        stream: _vendorRepository.streamVendorsForCategory(
          category: widget.category,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Unable to load vendors. ${snapshot.error}',
            );
          }

          final vendors = snapshot.data ?? const <Vendor>[];
          final filtered = _applyFilter(vendors);

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: filtered.length + 2,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VendorHeader(count: vendors.length),
                    const SizedBox(height: 16),
                    _buildFilterField(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              if (index == filtered.length + 1) {
                if (vendors.isEmpty) return const _EmptyVendorState();
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: _ErrorState(
                      message:
                          'No vendors match your area or pincode filter. Try clearing the search.',
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              final vendor = filtered[index - 1];
              return _VendorCard(
                vendor: vendor,
                onBook: () => startVendorBookingFlow(
                  context: context,
                  vendor: vendor,
                  bookingRepository: _bookingRepository,
                ),
                onViewDetails: () => _openVendorDetails(context, vendor),
                ratingStream:
                    _bookingRepository.streamVendorRatingSummary(vendor.id),
              );
            },
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: userNavIndex,
        builder: (_, index, __) => UserBottomNav(
          currentIndex: index,
          onNavigate: (next) {
            userNavIndex.value = next;
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              navigateUserTab(context, next);
            }
          },
        ),
      ),
    );
  }

  List<Vendor> _applyFilter(List<Vendor> vendors) {
    final query = _filterQuery.trim().toLowerCase();
    if (query.isEmpty) return vendors;
    return vendors.where((vendor) {
      final pin = vendor.pincode.toLowerCase();
      final area = vendor.area.toLowerCase();
      return pin.contains(query) || area.contains(query);
    }).toList();
  }

  Widget _buildFilterField() {
    return TextField(
      controller: _filterController,
      focusNode: _filterFocusNode,
      onChanged: (value) => setState(() => _filterQuery = value),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _filterQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear filter',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _filterController.clear();
                  setState(() => _filterQuery = '');
                  _filterFocusNode.requestFocus();
                },
              ),
        hintText: 'Filter vendors by area or pincode',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  void _openVendorDetails(BuildContext context, Vendor vendor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VendorDetailPage(
          vendor: vendor,
          bookingRepository: _bookingRepository,
        ),
      ),
    );
  }
}

Future<void> startVendorBookingFlow({
  required BuildContext context,
  required Vendor vendor,
  required BookingRepository bookingRepository,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to make a booking.')),
      );
    }
    return;
  }

  final selection = await showModalBottomSheet<_BookingSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookingSheet(vendor: vendor),
  );
  if (selection == null) return;

  final userName = user.displayName?.trim();
  final userEmail = user.email?.trim();

  try {
    for (final slot in selection.slots) {
      final hasConflict = await bookingRepository.hasVendorBookingConflict(
        vendorId: vendor.id,
        eventDate: slot.eventDate,
        userId: user.uid,
      );
      if (hasConflict) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sorry! ${_formatEventDate(slot.eventDate)} is already booked. Please try other dates.',
              ),
            ),
          );
        }
        return;
      }
    }

    for (final slot in selection.slots) {
      await bookingRepository.createBooking(
        userId: user.uid,
        userName: userName?.isNotEmpty == true
            ? userName!
            : (userEmail ?? 'User'),
        userEmail: userEmail ?? '',
        vendorId: vendor.id,
        vendorOwnerUid: vendor.ownerUid,
        vendorName: vendor.name,
        vendorCategory: vendor.categoryName,
        pricePerHour: vendor.price,
        startTime: slot.start,
        endTime: slot.end,
        eventDate: slot.eventDate,
      );
    }

    if (context.mounted) {
      final requestCount = selection.slots.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestCount == 1
                ? 'Booking request sent! We will notify you once the vendor responds.'
                : '$requestCount booking requests sent! We will notify you once the vendor responds.',
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to place booking: $error')),
      );
    }
  }
}

class _VendorHeader extends StatelessWidget {
  const _VendorHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Our Providers',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '($count) vendor${count == 1 ? '' : 's'} available',
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  const _VendorCard({
    required this.vendor,
    required this.onBook,
    required this.onViewDetails,
    required this.ratingStream,
  });

  final Vendor vendor;
  final VoidCallback onBook;
  final VoidCallback onViewDetails;
  final Stream<RatingSummary> ratingStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RatingSummary>(
      stream: ratingStream,
      initialData: RatingSummary.empty,
      builder: (context, snapshot) {
        final ratingSummary = snapshot.data ?? RatingSummary.empty;
        return Card(
          color: _vendorCardBackground,
          surfaceTintColor: _vendorCardBackground,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onViewDetails,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _VendorAvatar(imageUrl: vendor.imageUrl),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vendor.name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _vendorPrimaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vendor.type.isNotEmpty ? vendor.type : 'Vendor',
                              style: const TextStyle(
                                color: _vendorSecondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (ratingSummary.hasRatings) ...[
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ratingSummary.average!.toStringAsFixed(1)} (${ratingSummary.count})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _vendorPrimaryText,
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.star_border,
                                    size: 16,
                                    color: _vendorSecondaryText,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'No ratings yet',
                                    style: TextStyle(
                                      color: _vendorSecondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: onBook,
                        style: FilledButton.styleFrom(
                          backgroundColor: _vendorButtonColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.event_available_outlined),
                        label: const Text('Book'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _VendorFacts(vendor: vendor),
                  if (vendor.occasions.isNotEmpty ||
                      vendor.moreDetails.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (vendor.occasions.isNotEmpty)
                      Text(
                        'Occasions: ${vendor.occasions.join(', ')}',
                        style: const TextStyle(
                          color: _vendorSecondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (vendor.moreDetails.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        vendor.moreDetails,
                        style: const TextStyle(
                          color: _vendorSecondaryText,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VendorAvatar extends StatelessWidget {
  const _VendorAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isValidUrl(imageUrl)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.network(
          imageUrl,
          height: 56,
          width: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(theme),
          loadingBuilder: (_, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const SizedBox(
              height: 56,
              width: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      );
    }
    return _fallback(theme);
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: _vendorAvatarBackground,
        borderRadius: BorderRadius.circular(28),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.storefront, size: 28, color: Colors.white),
    );
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }
}

class _VendorFacts extends StatelessWidget {
  const _VendorFacts({required this.vendor});

  final Vendor vendor;

  @override
  Widget build(BuildContext context) {
    final rows = <_FactRow>[
      _FactRow(
        left: _Fact(
          label: 'Price/hr',
          value: _formatCurrency(vendor.price),
        ),
        right: vendor.capacity > 0
            ? _Fact(label: 'Seating', value: '${vendor.capacity}')
            : null,
      ),
      _FactRow(
        left: vendor.parkingCapacity > 0
            ? _Fact(label: 'Parking', value: '${vendor.parkingCapacity}')
            : null,
        right: _Fact(label: 'AC', value: vendor.ac ? 'Yes' : 'No'),
      ),
      _FactRow(
        left: vendor.area.isNotEmpty
            ? _Fact(label: 'Area', value: vendor.area)
            : null,
        right: null,
      ),
      _FactRow(
        left: vendor.location.isNotEmpty
            ? _Fact(label: 'Location', value: vendor.location)
            : null,
        right: null,
      ),
    ];

    final children = <Widget>[];
    for (final row in rows) {
      if (!row.hasContent) continue;
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 4));
      }
      children.add(_FactRowWidget(row: row));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _Fact {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
}

class _FactRow {
  const _FactRow({this.left, this.right});
  final _Fact? left;
  final _Fact? right;

  bool get hasContent => left != null || right != null;
}

class _FactRowWidget extends StatelessWidget {
  const _FactRowWidget({required this.row});

  final _FactRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _FactCell(
            fact: row.left,
            alignment: Alignment.centerLeft,
          ),
        ),
        if (row.left != null && row.right != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|', style: TextStyle(color: Colors.black26)),
          ),
        Expanded(
          child: _FactCell(
            fact: row.right,
            alignment: Alignment.centerRight,
          ),
        ),
      ],
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact, this.alignment = Alignment.centerLeft});

  final _Fact? fact;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (fact == null) return const SizedBox.shrink();
    return Align(
      alignment: alignment,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${fact!.label}: ',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _vendorPrimaryText,
              ),
            ),
            TextSpan(text: fact!.value),
          ],
        ),
        style: const TextStyle(
          fontSize: 13,
          color: _vendorSecondaryText,
          height: 1.3,
        ),
      ),
    );
  }
}

String _formatCurrency(double value) {
  if (value == 0) return 'Rs 0';
  if (value >= 100000) {
    return 'Rs ${(value / 100000).toStringAsFixed(1)}L';
  }
  final precision = value.truncateToDouble() == value ? 0 : 2;
  return 'Rs ${value.toStringAsFixed(precision)}';
}

String _formatEventDate(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

class _BookingSelection {
  const _BookingSelection({required this.slots});

  final List<_BookingSlot> slots;

  int get count => slots.length;
  int get hoursPerSlot => slots.isEmpty ? 0 : slots.first.hours;
  double totalEstimate(double pricePerHour) =>
      pricePerHour * hoursPerSlot * count;
}

class _BookingSlot {
  const _BookingSlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  int get hours => end.difference(start).inHours.clamp(1, 24);
  DateTime get eventDate => DateTime(start.year, start.month, start.day);
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.vendor});

  final Vendor vendor;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late DateTime _initialDate;
  final Set<DateTime> _selectedDates = <DateTime>{};
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _initialDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));
    _startTime = const TimeOfDay(hour: 10, minute: 0);
    _endTime = const TimeOfDay(hour: 11, minute: 0);
  }

  int get _selectedHours {
    final startMinutes = _minutesOf(_startTime);
    final endMinutes = _minutesOf(_endTime);
    final rawDiff = endMinutes - startMinutes;
    if (rawDiff <= 0) return 0;
    final diffMinutes = rawDiff > 24 * 60 ? 24 * 60 : rawDiff;
    final hours = (diffMinutes / 60).ceil();
    return hours.clamp(1, 24);
  }

  List<DateTime> get _sortedDates {
    final dates = _selectedDates.toList()
      ..sort((a, b) => a.compareTo(b));
    return dates;
  }

  String _formatTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      time,
      alwaysUse24HourFormat: false,
    );
  }

  String _formatDate(DateTime date) {
    return _formatEventDate(date);
  }

  DateTime _merge(DateTime date, TimeOfDay time) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select booking date',
    );
    if (picked == null) return;
    final normalized = DateTime(picked.year, picked.month, picked.day);
    if (_selectedDates.contains(normalized)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_formatDate(normalized)} already selected.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _initialDate = normalized;
      _selectedDates.add(normalized);
    });
  }

  void _removeDate(DateTime date) {
    if (_selectedDates.length == 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one event date for the booking.'),
        ),
      );
      return;
    }
    setState(() {
      _selectedDates.remove(date);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hours = _selectedHours <= 0 ? 1 : _selectedHours;
    final selectionCount = _selectedDates.length;
    final perDateTotal = widget.vendor.price * hours;
    final overallTotal =
        selectionCount == 0 ? 0.0 : perDateTotal * selectionCount;
    final durationLabel = '$hours ${hours == 1 ? 'hour' : 'hours'}';
    final timeLabel = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';
    final datesSelectedLabel = selectionCount == 0
        ? 'No dates selected. Tap "Add date" to get started.'
        : '$selectionCount date${selectionCount == 1 ? '' : 's'} selected';
    final canConfirm =
        selectionCount > 0 && _isEndAfterStart(_endTime, _startTime);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: _bookingSheetBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _bookingBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Book ${widget.vendor.name}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _vendorPrimaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _bookingMutedText),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select event dates',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _bookingChipText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final date in _sortedDates)
                        FilterChip(
                          label: Text(
                            _formatDate(date),
                            style: const TextStyle(
                              color: _bookingChipText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: true,
                          backgroundColor: _bookingChipColor,
                          selectedColor: _bookingChipSelected,
                          checkmarkColor: _bookingChipText,
                          side: const BorderSide(color: _bookingBorderColor),
                          onSelected: (_) => _removeDate(date),
                          deleteIcon: const Icon(
                            Icons.close,
                            size: 16,
                            color: _bookingMutedText,
                          ),
                          onDeleted: () => _removeDate(date),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18, color: _bookingChipText),
                        label: const Text(
                          'Add date',
                          style: TextStyle(
                            color: _bookingChipText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _pickDate,
                        backgroundColor: _bookingChipColor,
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: _bookingBorderColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedDates.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No event dates chosen yet. Add at least one date to continue.',
                      style: TextStyle(color: _bookingMutedText),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    datesSelectedLabel,
                    style: const TextStyle(
                      color: _bookingMutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label: 'Start time',
                          value: _formatTime(_startTime),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                              helpText: 'Select start time',
                              initialEntryMode: TimePickerEntryMode.dial,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child ?? const SizedBox.shrink(),
                              ),
                            );
                            if (picked == null) return;
                            final normalized = picked;
                            setState(() {
                              _startTime = normalized;
                              if (!_isEndAfterStart(_endTime, _startTime)) {
                                int nextMinutes = _minutesOf(_startTime) + 60;
                                if (nextMinutes >= 24 * 60) {
                                  nextMinutes = (24 * 60) - 1;
                                }
                                _endTime = _timeFromMinutes(nextMinutes);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label: 'End time',
                          value: _formatTime(_endTime),
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _endTime,
                              helpText: 'Select end time',
                              initialEntryMode: TimePickerEntryMode.dial,
                              builder: (context, child) => MediaQuery(
                                data: MediaQuery.of(context)
                                    .copyWith(alwaysUse24HourFormat: true),
                                child: child ?? const SizedBox.shrink(),
                              ),
                            );
                            if (picked == null) return;
                            final normalized = picked;
                            if (!_isEndAfterStart(normalized, _startTime)) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('End time must be after start time.'),
                                  ),
                                );
                              }
                              return;
                            }
                            setState(() => _endTime = normalized);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Time window',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _bookingChipText,
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: const TextStyle(color: _bookingMutedText),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Estimated total',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _bookingChipText,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatCurrency(overallTotal),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _vendorPrimaryText,
                            ),
                          ),
                          Text(
                            selectionCount <= 1
                                ? 'for $durationLabel'
                                : '$selectionCount dates x ${_formatCurrency(perDateTotal)} each',
                            style: const TextStyle(
                              color: _bookingMutedText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _vendorButtonColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _bookingBorderColor,
                        disabledForegroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: canConfirm
                          ? () {
                              final slots = _sortedDates
                                  .map(
                                    (date) => _BookingSlot(
                                      start: _merge(date, _startTime),
                                      end: _merge(date, _endTime),
                                    ),
                                  )
                                  .toList();
                              Navigator.of(context).maybePop(
                                _BookingSelection(slots: slots),
                              );
                            }
                          : null,
                      child: const Text('Confirm booking'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isEndAfterStart(TimeOfDay end, TimeOfDay start) {
    return _minutesOf(end) > _minutesOf(start);
  }

  int _minutesOf(TimeOfDay time) => time.hour * 60 + time.minute;

  TimeOfDay _timeFromMinutes(int minutes) {
    var clamped = minutes;
    if (clamped < 0) clamped = 0;
    if (clamped >= 24 * 60) clamped = (24 * 60) - 1;
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: _bookingChipText,
          ),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.access_time, color: _bookingChipText),
          label: Text(
            value,
            style: const TextStyle(
              color: _vendorPrimaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.9),
            foregroundColor: _bookingChipText,
            side: const BorderSide(color: _bookingBorderColor),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyVendorState extends StatelessWidget {
  const _EmptyVendorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 48,
            color: Colors.indigo.shade200,
          ),
          const SizedBox(height: 12),
          const Text(
            'Vendors on the way',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'We are curating partners for this category. Please check back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({
    super.key,
    required this.vendor,
    required this.bookingRepository,
  });

  final Vendor vendor;
  final BookingRepository bookingRepository;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  late final PageController _galleryController;
  int _currentImageIndex = 0;

  Vendor get vendor => widget.vendor;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
  }

  @override
  void dispose() {
    _galleryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = vendor.galleryImages;
    return Scaffold(
      backgroundColor: _creamBackground,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(vendor.name),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _buildGallery(images),
          const SizedBox(height: 20),
          _buildOverviewCard(),
          const SizedBox(height: 20),
          _buildRatingCard(),
          const SizedBox(height: 20),
          _buildFactsCard(),
          if (vendor.occasions.isNotEmpty || vendor.moreDetails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildDetailsCard(),
            ),
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildThumbnailStrip(images),
            ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ElevatedButton.icon(
          onPressed: () => startVendorBookingFlow(
            context: context,
            vendor: vendor,
            bookingRepository: widget.bookingRepository,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Book Now'),
        ),
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: _detailCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _detailDivider),
        ),
        child: const Center(
          child: Text(
            'This vendor has not added photos yet.',
            style: TextStyle(
              color: _detailMutedText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: PageView.builder(
              controller: _galleryController,
              itemCount: images.length,
              onPageChanged: (index) => setState(() {
                _currentImageIndex = index;
              }),
              itemBuilder: (_, index) {
                final imageUrl = images[index];
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _detailCardColor,
                    alignment: Alignment.center,
                    child: const Text(
                      'Image unavailable',
                      style: TextStyle(color: _detailMutedText),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: _currentImageIndex == index ? 18 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _currentImageIndex == index
                      ? Colors.black87
                      : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThumbnailStrip(List<String> images) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) {
          final url = images[index];
          final isSelected = index == _currentImageIndex;
          return GestureDetector(
            onTap: () => _galleryController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            ),
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.black87 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: images.length,
      ),
    );
  }

  Widget _buildOverviewCard() {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            vendor.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _vendorPrimaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vendor.type.isNotEmpty ? vendor.type : 'Vendor',
            style: const TextStyle(
              color: _detailMutedText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (vendor.area.isNotEmpty)
                _InfoChip(
                  icon: Icons.map_outlined,
                  label: vendor.area,
                ),
              if (vendor.pincode.isNotEmpty)
                _InfoChip(
                  icon: Icons.pin_drop_outlined,
                  label: 'Pincode ${vendor.pincode}',
                ),
              if (vendor.location.isNotEmpty)
                _InfoChip(
                  icon: Icons.location_city_outlined,
                  label: vendor.location,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return StreamBuilder<List<Booking>>(
      stream:
          widget.bookingRepository.streamVendorBookings(vendor.ownerUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InfoCard(
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Unable to load ratings: ${snapshot.error}',
                    style: const TextStyle(color: _detailMutedText),
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const _InfoCard(
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final bookings = snapshot.data ?? const <Booking>[];
        final ratings = bookings
            .where(
              (booking) =>
                  booking.vendorId == vendor.id &&
                  booking.rating != null &&
                  booking.rating! > 0,
            )
            .toList();

        if (ratings.isEmpty) {
          return const _InfoCard(
            child: ListTile(
              leading: Icon(Icons.star_border, color: Colors.black54),
              title: Text(
                'Not rated yet',
                style: TextStyle(
                  color: _vendorPrimaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Be the first to rate this vendor after booking.',
                style: TextStyle(color: _detailMutedText),
              ),
            ),
          );
        }

        final total = ratings.fold<int>(0, (sum, booking) => sum + booking.rating!);
        final average = total / ratings.length;

        return _InfoCard(
          child: ListTile(
            leading: const Icon(Icons.star, color: Colors.amber, size: 30),
            title: Text(
              '${average.toStringAsFixed(1)} / 5',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: _vendorPrimaryText,
              ),
            ),
            subtitle: Text(
              '${ratings.length} review${ratings.length == 1 ? '' : 's'}',
              style: const TextStyle(color: _detailMutedText),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFactsCard() {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'At a glance',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _vendorPrimaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _VendorFacts(vendor: vendor),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (vendor.moreDetails.isNotEmpty) ...[
            const Text(
              'Highlights',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _vendorPrimaryText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              vendor.moreDetails,
              style: const TextStyle(color: _detailMutedText),
            ),
            if (vendor.occasions.isNotEmpty) const SizedBox(height: 16),
          ],
          if (vendor.occasions.isNotEmpty) ...[
            const Text(
              'Occasions served',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _vendorPrimaryText,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vendor.occasions
                  .map(
                    (occasion) => Chip(
                      label: Text(occasion),
                      backgroundColor: _detailChipColor,
                      labelStyle: const TextStyle(
                        color: _detailChipText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _detailCardColor,
      surfaceTintColor: _detailCardColor,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _detailChipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _detailChipText),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _detailChipText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
