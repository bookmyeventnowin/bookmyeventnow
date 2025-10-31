import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'models/booking.dart';
import 'models/category.dart';
import 'models/vendor.dart';
import 'services/booking_repository.dart';
import 'services/vendor_repository.dart';
import 'user_navigation.dart';

class VendorListPage extends StatelessWidget {
  VendorListPage({required this.category, super.key});

  final Category category;
  final BookingRepository _bookingRepository = BookingRepository();
  final VendorRepository _vendorRepository = VendorRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.2,
        foregroundColor: Colors.black87,
        title: Text('Vendors: ${category.name}'),
      ),
      body: StreamBuilder<List<Vendor>>(
        stream: _vendorRepository.streamVendorsForCategory(category: category),
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
          if (vendors.isEmpty) {
            return const _EmptyVendorState();
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: vendors.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _VendorHeader(count: vendors.length);
              }
              final vendor = vendors[index - 1];
              return _VendorCard(
                vendor: vendor,
                onBook: () => startVendorBookingFlow(
                  context: context,
                  vendor: vendor,
                  bookingRepository: _bookingRepository,
                ),
                onViewDetails: () => _openVendorDetails(context, vendor),
              );
            },
          );
        },
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: userNavIndex,
        builder: (_, index, __) => UserBottomNav(currentIndex: index),
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
  });

  final Vendor vendor;
  final VoidCallback onBook;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onViewDetails,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VendorAvatar(imageUrl: vendor.imageUrl),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vendor.type.isNotEmpty ? vendor.type : 'Vendor',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    _VendorFacts(vendor: vendor),
                    if (vendor.occasions.isNotEmpty ||
                        vendor.moreDetails.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      if (vendor.occasions.isNotEmpty)
                        Text(
                          'Occasions: ${vendor.occasions.join(', ')}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      if (vendor.moreDetails.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          vendor.moreDetails,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: onBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
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
        ),
      ),
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
    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundColor: theme.colorScheme.primary,
      child: const Icon(Icons.storefront, size: 28),
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
        right: vendor.pincode.isNotEmpty
            ? _Fact(label: 'Pincode', value: vendor.pincode)
            : null,
      ),
      _FactRow(
        left: vendor.location.isNotEmpty
            ? _Fact(label: 'Location', value: vendor.location)
            : null,
        right: null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          if (row.hasContent) ...[
            _FactRowWidget(row: row),
            const SizedBox(height: 4),
          ],
      ],
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
        Expanded(child: _FactCell(fact: row.left)),
        if (row.left != null && row.right != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|', style: TextStyle(color: Colors.black26)),
          ),
        Expanded(child: _FactCell(fact: row.right)),
      ],
    );
  }
}

class _FactCell extends StatelessWidget {
  const _FactCell({required this.fact});

  final _Fact? fact;

  @override
  Widget build(BuildContext context) {
    if (fact == null) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${fact!.label}: ',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          TextSpan(text: fact!.value),
        ],
      ),
      style: const TextStyle(fontSize: 13, color: Colors.black87),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
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
    _selectedDates.add(_initialDate);
    _startTime = const TimeOfDay(hour: 10, minute: 0);
    _endTime = const TimeOfDay(hour: 13, minute: 0);
  }

  int get _selectedHours {
    final start = DateTime(0, 1, 1, _startTime.hour, _startTime.minute);
    final end = DateTime(0, 1, 1, _endTime.hour, _endTime.minute);
    final diff = end.difference(start);
    if (diff.inMinutes <= 0) return 0;
    return (diff.inMinutes / 60).ceil();
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
      alwaysUse24HourFormat: true,
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
    final perDateTotal = widget.vendor.price * hours;
    final selectionCount = _selectedDates.length;
    final overallTotal = perDateTotal * (selectionCount == 0 ? 1 : selectionCount);
    final durationLabel = '$hours hr${hours == 1 ? '' : 's'}';
    final timeLabel = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book ${widget.vendor.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Select event dates',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final date in _sortedDates)
                InputChip(
                  label: Text(_formatDate(date)),
                  onDeleted: () => _removeDate(date),
                  backgroundColor: const Color(0xFFF1EEFF),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add date'),
                onPressed: _pickDate,
                backgroundColor: const Color(0xFFE8E1FF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_selectedDates.length} date${_selectedDates.length == 1 ? '' : 's'} selected',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
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
                        final adjusted =
                            DateTime(0, 1, 1, _startTime.hour, _startTime.minute)
                                .add(const Duration(hours: 1));
                        _endTime = TimeOfDay(
                          hour: adjusted.hour % 24,
                          minute: adjusted.minute,
                        );
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
                            content: Text('End time must be after start time.'),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Time window',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(timeLabel),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estimated total',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatCurrency(overallTotal)),
                  Text(
                    selectionCount <= 1
                        ? 'for $durationLabel'
                        : '$selectionCount dates x ${_formatCurrency(perDateTotal)} each',
                    style: const TextStyle(
                      color: Colors.black54,
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
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: () {
                if (!_isEndAfterStart(_endTime, _startTime)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('End time must be after start time.'),
                    ),
                  );
                  return;
                }
                if (_selectedDates.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Select at least one event date.'),
                    ),
                  );
                  return;
                }
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
              },
              child: const Text('Confirm booking'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  bool _isEndAfterStart(TimeOfDay end, TimeOfDay start) {
    return end.hour > start.hour ||
        (end.hour == start.hour && end.minute > start.minute);
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.access_time),
          label: Text(value),
          style: OutlinedButton.styleFrom(
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
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.2,
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
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Center(
          child: Text(
            'This vendor has not added photos yet.',
            style: TextStyle(color: Colors.black54),
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
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Text('Image unavailable'),
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
            ),
          ),
          const SizedBox(height: 6),
          Text(
            vendor.type.isNotEmpty ? vendor.type : 'Vendor',
            style: const TextStyle(color: Colors.black54, fontSize: 16),
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
                    style: const TextStyle(color: Colors.black54),
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
              title: Text('Not rated yet'),
              subtitle: Text('Be the first to rate this vendor after booking.'),
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
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            subtitle: Text('${ratings.length} review${ratings.length == 1 ? '' : 's'}'),
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
            style: TextStyle(fontWeight: FontWeight.w600),
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
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              vendor.moreDetails,
              style: const TextStyle(color: Colors.black87),
            ),
            if (vendor.occasions.isNotEmpty) const SizedBox(height: 16),
          ],
          if (vendor.occasions.isNotEmpty) ...[
            const Text(
              'Occasions served',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vendor.occasions
                  .map(
                    (occasion) => Chip(
                      label: Text(occasion),
                      backgroundColor: Colors.indigo.shade50,
                      labelStyle: const TextStyle(color: Colors.indigo),
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
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.indigo),
          ),
        ],
      ),
    );
  }
}
