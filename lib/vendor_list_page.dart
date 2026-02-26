import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/booking.dart';
import 'models/category.dart';
import 'models/vendor.dart';
import 'services/booking_repository.dart';
import 'services/vendor_repository.dart';
import 'user_navigation.dart';

const _creamBackground = Color(0xFFFEFAF4);
const _vendorCardBackground = Colors.white;
const _vendorPrimaryText = Color(0xFF111827);
const _vendorSecondaryText = Color(0xFF4B5563);
const _vendorButtonColor = Colors.black;
const _vendorAvatarBackground = Color(0xFFE5E7EB);

const _detailCardColor = Colors.white;
const _detailChipColor = Color(0xFFF5F5F5);
const _detailChipText = Color(0xFF111827);
const _detailMutedText = Color(0xFF6B7280);
const _detailDivider = Color(0xFFE5E7EB);

const _bookingSheetBackground = Color(0xFFFEFAF4);
const _bookingChipColor = Colors.white;
const _bookingChipSelected = Color(0xFFF1F5F9);
const _bookingChipText = Color(0xFF111827);
const _bookingMutedText = Color(0xFF6B7280);
const _bookingBorderColor = Color(0xFFE5E7EB);

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
                onBook: () {
                  if (_isCateringVendor(vendor)) {
                    _openVendorDetails(context, vendor);
                  } else {
                    startVendorBookingFlow(
                      context: context,
                      vendor: vendor,
                      bookingRepository: _bookingRepository,
                    );
                  }
                },
                onViewDetails: () => _openVendorDetails(context, vendor),
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

class CateringProposalInput {
  const CateringProposalInput({required this.menu, required this.guestCount});

  final List<ProposalMenuItem> menu;
  final int guestCount;
}

Future<void> startVendorBookingFlow({
  required BuildContext context,
  required Vendor vendor,
  required BookingRepository bookingRepository,
  CateringProposalInput? cateringProposal,
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

  final isCateringFlow = cateringProposal != null && _isCateringVendor(vendor);
  // Group all slots selected in a single flow under one logical order.
  final orderId =
      '${user.uid}_${vendor.id}_${DateTime.now().millisecondsSinceEpoch}';

  final selection = await showModalBottomSheet<_BookingSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BookingSheet(
      vendor: vendor,
      isCateringProposal: isCateringFlow,
      proposal: cateringProposal,
    ),
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
      if (isCateringFlow) {
        await bookingRepository.createCateringProposal(
          userId: user.uid,
          userName: userName?.isNotEmpty == true
              ? userName!
              : (userEmail ?? 'User'),
          userEmail: userEmail ?? '',
          vendorId: vendor.id,
          vendorOwnerUid: vendor.ownerUid,
          vendorName: vendor.name,
          vendorCategory: vendor.categoryName,
          menu: cateringProposal.menu,
          guestCount: cateringProposal.guestCount,
          startTime: slot.start,
          endTime: slot.end,
          eventDate: slot.eventDate,
          deliveryTime: slot.start,
          deliveryAddress: selection.deliveryAddress ?? '',
          deliveryRequired: selection.deliveryRequired,
          orderId: orderId,
        );
      } else {
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
          orderId: orderId,
        );
      }
    }

    if (context.mounted) {
      final requestCount = selection.slots.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isCateringFlow
                ? (requestCount == 1
                      ? 'Proposal sent! The vendor will respond with a quote.'
                      : '$requestCount proposals sent! The vendor will respond with quotes.')
                : requestCount == 1
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
      color: _vendorCardBackground,
      surfaceTintColor: _vendorCardBackground,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
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
                            if (vendor.ratingCount > 0) ...[
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatVendorRating(vendor),
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
                    icon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                    ),
                    label: const Text(
                      'Book',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _VendorFacts(vendor: vendor),
              if (vendor.occasions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Occasions: ${vendor.occasions.join(', ')}',
                  style: const TextStyle(
                    color: _vendorSecondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatVendorRating(Vendor vendor) {
  final average = vendor.ratingAverage > 0
      ? vendor.ratingAverage
      : (vendor.ratingCount > 0 ? vendor.ratingTotal / vendor.ratingCount : 0);
  if (average <= 0) return 'No ratings yet';
  return '${average.toStringAsFixed(1)} (${vendor.ratingCount})';
}

bool _isDecorationVendor(Vendor vendor) {
  final type = vendor.type.toLowerCase();
  if (type.contains('decor')) return true;
  return vendor.categoryName.toLowerCase().contains('decor') ||
      vendor.categoryNames.any((name) => name.toLowerCase().contains('decor'));
}

bool _isCateringVendor(Vendor vendor) {
  final type = vendor.type.toLowerCase();
  if (type.contains('cater')) return true;
  if (vendor.categoryName.toLowerCase().contains('cater')) return true;
  return vendor.categoryNames.any(
    (name) => name.toLowerCase().contains('cater'),
  );
}

bool _isHumanResourceVendor(Vendor vendor) {
  final type = vendor.type.toLowerCase();
  if (type.contains('human')) return true;
  if (vendor.categoryName.toLowerCase().contains('human')) return true;
  return vendor.categoryNames.any(
    (name) => name.toLowerCase().contains('human'),
  );
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
    final isDecoration = _isDecorationVendor(vendor);
    final isCatering = _isCateringVendor(vendor);
    final isHumanResource = _isHumanResourceVendor(vendor);
    final hidePricing = isDecoration || isCatering || isHumanResource;
    final rows = <_FactRow>[];

    if (isHumanResource) {
      rows.add(
        _FactRow(
          left: _Fact(
            label: 'Experience',
            value: vendor.experience.isEmpty ? 'N/A' : vendor.experience,
          ),
          right: _Fact(label: 'Rate/hr', value: _formatCurrency(vendor.price)),
        ),
      );
      rows.add(
        _FactRow(
          left: vendor.languages.isNotEmpty
              ? _Fact(label: 'Languages', value: vendor.languages)
              : null,
          right: vendor.education.isNotEmpty
              ? _Fact(label: 'Education', value: vendor.education)
              : null,
        ),
      );
      rows.add(
        _FactRow(
          left: vendor.state.isNotEmpty
              ? _Fact(label: 'State', value: vendor.state)
              : null,
          right: vendor.area.isNotEmpty
              ? _Fact(label: 'Area', value: vendor.area)
              : null,
        ),
      );
      rows.add(
        _FactRow(
          left: null,
          right: vendor.proofUrl.isNotEmpty
              ? const _Fact(label: 'Proof', value: 'Verified')
              : null,
        ),
      );
    } else if (!hidePricing) {
      rows.add(
        _FactRow(
          left: _Fact(label: 'Price/hr', value: _formatCurrency(vendor.price)),
          right: vendor.capacity > 0
              ? _Fact(label: 'Seating', value: '${vendor.capacity}')
              : null,
        ),
      );
      rows.add(
        _FactRow(
          left: vendor.parkingCapacity > 0
              ? _Fact(label: 'Parking', value: '${vendor.parkingCapacity}')
              : null,
          right: _Fact(label: 'AC', value: vendor.ac ? 'Yes' : 'No'),
        ),
      );
    } else if (isDecoration && vendor.decorationPackages.isNotEmpty) {
      rows.add(
        _FactRow(
          left: _Fact(
            label: 'Packages',
            value: '${vendor.decorationPackages.length}',
          ),
        ),
      );
    }

    if (isCatering && vendor.menuItems.isNotEmpty) {
      rows.add(
        _FactRow(
          left: _Fact(
            label: 'Menu items',
            value: '${vendor.menuItems.length} items',
          ),
        ),
      );
    }

    if (!isHumanResource) {
      rows.add(
        _FactRow(
          left: vendor.area.isNotEmpty
              ? _Fact(label: 'Area', value: vendor.area)
              : null,
        ),
      );
      rows.add(
        _FactRow(
          left: vendor.location.isNotEmpty
              ? _Fact(label: 'Location', value: vendor.location)
              : null,
        ),
      );
    }

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
          child: _FactCell(fact: row.left, alignment: Alignment.centerLeft),
        ),
        if (row.left != null && row.right != null)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('|', style: TextStyle(color: Colors.black26)),
          ),
        Expanded(
          child: _FactCell(fact: row.right, alignment: Alignment.centerRight),
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
  const _BookingSelection({
    required this.slots,
    this.deliveryAddress,
    this.deliveryRequired = false,
  });

  final List<_BookingSlot> slots;
  final String? deliveryAddress;
  final bool deliveryRequired;

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
  const _BookingSheet({
    required this.vendor,
    this.isCateringProposal = false,
    this.proposal,
  });

  final Vendor vendor;
  final bool isCateringProposal;
  final CateringProposalInput? proposal;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late DateTime _initialDate;
  final Set<DateTime> _selectedDates = <DateTime>{};
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  bool _deliveryRequired = true;

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

  @override
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
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
    final dates = _selectedDates.toList()..sort((a, b) => a.compareTo(b));
    return dates;
  }

  String _formatTime(TimeOfDay time) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time, alwaysUse24HourFormat: false);
  }

  String _formatDate(DateTime date) {
    return _formatEventDate(date);
  }

  DateTime _merge(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
        SnackBar(content: Text('${_formatDate(normalized)} already selected.')),
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
    final isCatering = widget.isCateringProposal;
    final proposalMenu = widget.proposal?.menu ?? const <ProposalMenuItem>[];
    final proposalGuestCount = widget.proposal?.guestCount;
    final hours = _selectedHours <= 0 ? 1 : _selectedHours;
    final selectionCount = _selectedDates.length;
    final perDateTotal = isCatering ? 0.0 : widget.vendor.price * hours;
    final overallTotal = isCatering
        ? 0.0
        : selectionCount == 0
        ? 0.0
        : perDateTotal * selectionCount;
    final durationLabel = '$hours ${hours == 1 ? 'hour' : 'hours'}';
    final timeLabel = '${_formatTime(_startTime)} - ${_formatTime(_endTime)}';
    final datesSelectedLabel = selectionCount == 0
        ? 'No dates selected. Tap "Add date" to get started.'
        : '$selectionCount date${selectionCount == 1 ? '' : 's'} selected';
    final canConfirm =
        selectionCount > 0 && _isEndAfterStart(_endTime, _startTime);
    final confirmLabel = isCatering ? 'Send proposal' : 'Confirm booking';
    final proposalChips = proposalMenu
        .map(
          (item) => Chip(
            avatar: Icon(
              Icons.circle,
              size: 10,
              color: item.isVeg ? Colors.green : Colors.redAccent,
            ),
            label: Text(item.name),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        )
        .toList(growable: false);

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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isCatering
                              ? 'Send proposal to ${widget.vendor.name}'
                              : 'Book ${widget.vendor.name}',
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
                  if (isCatering && proposalChips.isNotEmpty) ...[
                    const Text(
                      'Selected dishes',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _bookingChipText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: proposalChips),
                    if (proposalGuestCount != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Guests: $proposalGuestCount',
                        style: const TextStyle(
                          color: _bookingMutedText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
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
                        avatar: const Icon(
                          Icons.add,
                          size: 18,
                          color: _bookingChipText,
                        ),
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
                  if (isCatering) ...[
                    _TimeField(
                      label: 'Delivery time',
                      value: _formatTime(_startTime),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                          helpText: 'Select delivery time',
                          initialEntryMode: TimePickerEntryMode.dial,
                          builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(alwaysUse24HourFormat: true),
                            child: child ?? const SizedBox.shrink(),
                          ),
                        );
                        if (picked == null) return;
                        setState(() {
                          _startTime = picked;
                          final nextMinutes = (_minutesOf(_startTime) + 60)
                              .clamp(0, (24 * 60) - 1);
                          _endTime = _timeFromMinutes(nextMinutes);
                        });
                      },
                    ),
                    const SizedBox(height: 18),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Catering delivery'),
                      subtitle: const Text(
                        'Toggle off if you plan to pick up the order.',
                      ),
                      value: _deliveryRequired,
                      onChanged: (value) =>
                          setState(() => _deliveryRequired = value),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _deliveryAddressController,
                      enabled: _deliveryRequired,
                      maxLines: 2,
                      keyboardType: TextInputType.streetAddress,
                      decoration: const InputDecoration(
                        labelText: 'Delivery address',
                        hintText: 'Where should the food be delivered?',
                      ),
                    ),
                  ] else
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
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
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
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: true),
                                  child: child ?? const SizedBox.shrink(),
                                ),
                              );
                              if (picked == null) return;
                              final normalized = picked;
                              if (!_isEndAfterStart(normalized, _startTime)) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'End time must be after start time.',
                                      ),
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
                  if (isCatering) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Delivery time',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _bookingChipText,
                          ),
                        ),
                        Text(
                          _formatTime(_startTime),
                          style: const TextStyle(color: _bookingMutedText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _bookingBorderColor),
                      ),
                      child: const Text(
                        'We will notify you once the vendor reviews your menu and shares a quote.',
                        style: TextStyle(color: _bookingMutedText),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
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
                  ],
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
                              if (isCatering) {
                                final trimmedAddress =
                                    _deliveryAddressController.text.trim();
                                if (_deliveryRequired &&
                                    trimmedAddress.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please provide a delivery address or turn off delivery.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                              }
                              final slots = _sortedDates
                                  .map(
                                    (date) => _BookingSlot(
                                      start: _merge(date, _startTime),
                                      end: _merge(date, _endTime),
                                    ),
                                  )
                                  .toList();
                              final address = _deliveryAddressController.text
                                  .trim();
                              Navigator.of(context).maybePop(
                                _BookingSelection(
                                  slots: slots,
                                  deliveryAddress: isCatering
                                      ? (_deliveryRequired ? address : '')
                                      : null,
                                  deliveryRequired: isCatering
                                      ? _deliveryRequired
                                      : false,
                                ),
                              );
                            }
                          : null,
                      child: Text(confirmLabel),
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
  final Set<int> _selectedMenuItems = <int>{};
  final TextEditingController _guestCountController = TextEditingController();

  Vendor get vendor => widget.vendor;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();
    _guestCountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _galleryController.dispose();
    _guestCountController.dispose();
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
          if (_isCateringVendor(vendor) && vendor.menuItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildMenuCard(),
            ),
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
        child: Builder(
          builder: (context) {
            final isCatering = _isCateringVendor(vendor);
            final guestCount = _guestCount();
            final hasMenu = _selectedMenuItems.isNotEmpty;
            final canSendProposal = hasMenu && guestCount != null;
            final onPressed = isCatering
                ? (canSendProposal ? _handleSendProposal : null)
                : () => startVendorBookingFlow(
                    context: context,
                    vendor: vendor,
                    bookingRepository: widget.bookingRepository,
                  );
            return ElevatedButton.icon(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.black12,
                disabledForegroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: Icon(
                isCatering
                    ? Icons.send_outlined
                    : Icons.event_available_outlined,
              ),
              label: Text(isCatering ? 'Send proposal' : 'Book Now'),
            );
          },
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
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildRatingCard() {
    return StreamBuilder<List<Booking>>(
      stream: widget.bookingRepository.streamVendorBookings(vendor.ownerUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          if (error is FirebaseException && error.code == 'permission-denied') {
            return const _InfoCard(
              child: ListTile(
                leading: Icon(Icons.star_border, color: Colors.black54),
                title: Text(
                  'Ratings unavailable',
                  style: TextStyle(
                    color: _vendorPrimaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'This vendor has chosen to keep ratings private.',
                  style: TextStyle(color: _detailMutedText),
                ),
              ),
            );
          }
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

        final total = ratings.fold<int>(
          0,
          (accumulator, booking) => accumulator + booking.rating!,
        );
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

  Future<void> _handleSendProposal() async {
    final menu = _selectedProposalItems();
    if (menu.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one menu item.')),
      );
      return;
    }
    final guestCount = _guestCount();
    if (guestCount == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid guest count.')),
      );
      return;
    }
    await startVendorBookingFlow(
      context: context,
      vendor: vendor,
      bookingRepository: widget.bookingRepository,
      cateringProposal: CateringProposalInput(
        menu: menu,
        guestCount: guestCount,
      ),
    );
  }

  int? _guestCount() {
    final raw = _guestCountController.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  List<ProposalMenuItem> _selectedProposalItems() {
    if (_selectedMenuItems.isEmpty) return const <ProposalMenuItem>[];
    return _selectedMenuItems
        .map((index) => vendor.menuItems[index])
        .map((item) => ProposalMenuItem(name: item.name, isVeg: item.isVeg))
        .toList(growable: false);
  }

  Widget _buildMenuCard() {
    final menuItems = vendor.menuItems;
    final chips = <Widget>[];
    for (var i = 0; i < menuItems.length; i++) {
      final item = menuItems[i];
      final isSelected = _selectedMenuItems.contains(i);
      final accent = item.isVeg ? Colors.green : Colors.redAccent;
      chips.add(
        FilterChip(
          showCheckmark: false,
          avatar: Icon(Icons.circle, color: accent, size: 12),
          label: Text(item.name),
          labelStyle: TextStyle(
            color: _vendorPrimaryText,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedMenuItems.add(i);
              } else {
                _selectedMenuItems.remove(i);
              }
            });
          },
          selectedColor: accent.withValues(alpha: 0.18),
          backgroundColor: Colors.grey.shade100,
          side: BorderSide(color: isSelected ? accent : Colors.transparent),
          pressElevation: 0,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    final selectedIndices = _selectedMenuItems.toList()..sort();
    final selectedChips = selectedIndices.map((index) {
      final item = menuItems[index];
      final accent = item.isVeg ? Colors.green : Colors.redAccent;
      return InputChip(
        avatar: Icon(Icons.circle, size: 12, color: accent),
        label: Text(item.name),
        onDeleted: () => setState(() => _selectedMenuItems.remove(index)),
        deleteIconColor: Colors.black54,
        backgroundColor: Colors.white,
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }).toList();

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu highlights',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _vendorPrimaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: chips),
          if (selectedChips.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Your menu (${selectedChips.length} item${selectedChips.length == 1 ? '' : 's'})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _vendorPrimaryText,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: selectedChips),
            const SizedBox(height: 8),
            const Text(
              'Tap chips to add or remove dishes before you book this vendor.',
              style: TextStyle(fontSize: 12, color: _detailMutedText),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _guestCountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Guest count',
              hintText: 'How many guests are you hosting?',
              helperText: 'Vendors use this to estimate pricing.',
              helperStyle: const TextStyle(fontSize: 12),
            ),
          ),
          if (_guestCountController.text.isNotEmpty && _guestCount() == null)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Enter a valid number greater than zero.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
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
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
