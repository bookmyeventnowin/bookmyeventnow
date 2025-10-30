import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'booking_payment_page.dart';
import 'models/booking.dart';
import 'models/category.dart';
import 'models/vendor.dart';
import 'services/booking_repository.dart';
import 'services/category_repository.dart';
import 'services/vendor_repository.dart';
import 'user_role_storage.dart';
import 'vendor_edit_sheet.dart';
import 'vendor_list_page.dart';
import 'payment/razorpay_keys.dart';
import 'user_navigation.dart';

class UserHomePage extends StatefulWidget {
  final User user;
  final int initialIndex;
  const UserHomePage({required this.user, this.initialIndex = 0, super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const Color _milkWhite = Color(0xFFF4F1FF);
  final BookingRepository _bookingRepository = BookingRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TextEditingController _searchController = TextEditingController();
  final PageController _carouselController = PageController(
    viewportFraction: 0.85,
  );

  String _searchQuery = '';
  int _carouselIndex = 0;
  late int _currentIndex;
  late final VoidCallback _navListener;

  static const Map<String, String> _categorySlideAssets = {
    'catering': 'assets/catering_slide.png',
    'decoration': 'assets/decoration_slide.png',
    'community hall': 'assets/communityhall_slide.png',
    'communite hall': 'assets/communityhall_slide.png',
    'communityhall': 'assets/communityhall_slide.png',
    'human resource': 'assets/humanresouce_slide.png',
    'humanresource': 'assets/humanresouce_slide.png',
    'human resouce': 'assets/humanresouce_slide.png',
  };

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    userNavIndex.value = _currentIndex;
    _navListener = () {
      if (!mounted) return;
      final next = userNavIndex.value;
      if (next != _currentIndex) {
        setState(() => _currentIndex = next);
      }
    };
    userNavIndex.addListener(_navListener);
  }

  @override
  void dispose() {
    userNavIndex.removeListener(_navListener);
    _searchController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  void _openCategory(Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VendorListPage(category: category)),
    );
  }

  String? _assetForCategory(Category category) {
    final name = category.name.trim().toLowerCase();
    if (_categorySlideAssets.containsKey(name)) {
      return _categorySlideAssets[name];
    }
    // handle names with extra words like "Catering Services"
    for (final entry in _categorySlideAssets.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<void> _signOut() async {
    await UserRoleStorage.instance.clearRole(widget.user.uid);
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.displayName ?? widget.user.email ?? 'Guest';
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'U';
    final photoUrl = widget.user.photoURL;

    return Scaffold(
      backgroundColor: _milkWhite,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<Category>>(
          stream: _categoryRepository.streamCategories(),
          builder: (context, categorySnapshot) {
            final categories = categorySnapshot.data ?? const <Category>[];
            final filteredCategories = _searchQuery.isEmpty
                ? categories
                : categories
                      .where(
                        (category) => category.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();

            if (filteredCategories.isNotEmpty &&
                _carouselIndex >= filteredCategories.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() => _carouselIndex = 0);
                if (_carouselController.hasClients) {
                  _carouselController.jumpToPage(0);
                }
              });
            }

            final categoriesLoading =
                categorySnapshot.connectionState == ConnectionState.waiting;

            return StreamBuilder<List<Booking>>(
              stream: _bookingRepository.streamUserBookings(widget.user.uid),
              builder: (context, bookingSnapshot) {
                final bookings = bookingSnapshot.data ?? const <Booking>[];
                final bookingsLoading =
                    bookingSnapshot.connectionState == ConnectionState.waiting;

                return IndexedStack(
                  index: _currentIndex,
                  children: [
                    _buildHomeTab(filteredCategories, categoriesLoading),
                    _buildBookingsTab(bookings, bookingsLoading),
                    _buildProfileTab(widget.user, initials),
                  ],
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: UserBottomNav(currentIndex: _currentIndex),
    );
  }

  Widget _buildHomeTab(List<Category> categories, bool isLoading) {
    return Container(
      color: _milkWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHeader(),
            const SizedBox(height: 24),
            _buildCategoryCarousel(categories, isLoading),
            const SizedBox(height: 20),
            _buildCategoryGrid(categories, isLoading),
            const SizedBox(height: 32),
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab(List<Booking> bookings, bool isLoading) {
    return Container(
      color: _milkWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserBookingsCard(bookings, isLoading),
            const SizedBox(height: 32),
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(User user, String initials) {
    final displayName = user.displayName ?? user.email ?? 'Guest';
    final email = user.email ?? 'Not available';
    final phone = user.phoneNumber;
    final photoUrl = user.photoURL;

    return Container(
      color: _milkWhite,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _milkWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.black87,
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Account details',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _ProfileDetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: email,
                    ),
                    if (phone != null && phone.isNotEmpty)
                      _ProfileDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: phone,
                      ),
                    _ProfileDetailRow(
                      icon: Icons.badge_outlined,
                      label: 'User ID',
                      value: user.uid,
                      isSelectable: true,
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        onPressed: _signOut,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Card(
      color: _milkWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find services for your next event',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search categories (e.g. Catering, Decoration)',
                filled: true,
                fillColor: const Color(0xFFF1F3F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final suggestion in [
                  'Decoration',
                  'Catering',
                  'Photography',
                  'Music',
                ])
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      _searchController.text = suggestion;
                      setState(() => _searchQuery = suggestion);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCarousel(List<Category> categories, bool isLoading) {
    return Card(
      color: _milkWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          height: 200,
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : categories.isEmpty
              ? const Center(child: Text('No categories available yet.'))
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _carouselController,
                        onPageChanged: (index) =>
                            setState(() => _carouselIndex = index),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final slideAsset = _assetForCategory(category);

                          Widget buildBackground() {
                            if (_isValidUrl(category.imageUrl)) {
                              return Image.network(
                                category.imageUrl,
                                fit: BoxFit.cover,
                              );
                            }
                            if (slideAsset != null) {
                              return Image.asset(slideAsset, fit: BoxFit.cover);
                            }
                            return Container(color: Colors.grey.shade900);
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GestureDetector(
                              onTap: () => _openCategory(category),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Positioned.fill(child: buildBackground()),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                          colors: [
                                            Color.fromARGB(220, 0, 0, 0),
                                            Color.fromARGB(60, 0, 0, 0),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Text(
                                            category.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Tap to explore vendors',
                                            style: TextStyle(
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        categories.length,
                        (index) => Container(
                          width: _carouselIndex == index ? 18 : 8,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _carouselIndex == index
                                ? Colors.indigo
                                : Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<Category> categories, bool isLoading) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select a service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No categories found. Check back soon!'),
              )
            else
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                childAspectRatio: 1.1,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final category in categories)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openCategory(category),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              height: 70,
                              width: 70,
                              child: Builder(
                                builder: (_) {
                                  if (_isValidUrl(category.imageUrl)) {
                                    return Image.network(
                                      category.imageUrl,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  final slideAsset = _assetForCategory(
                                    category,
                                  );
                                  if (slideAsset != null) {
                                    return Image.asset(
                                      slideAsset,
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return Container(
                                    color: Colors.grey.shade900,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.photo,
                                      color: Colors.white70,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBookingsCard(List<Booking> bookings, bool isLoading) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My bookings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (isLoading)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading && bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (bookings.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'You have not made any bookings yet. Start by selecting a category.',
                ),
              )
            else
              Column(
                children: bookings.map((booking) {
                  final statusColor = _bookingStatusColor(booking.status);
                  final total = _formatCurrency(booking.totalAmount);
                  final timeRange = _formatBookingTimeRange(context, booking);
                  final hours = _hoursForBooking(booking);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _milkWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                booking.vendorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Chip(
                              backgroundColor: statusColor.withAlpha(28),
                              label: Text(
                                booking.status.label,
                                style: TextStyle(color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Event date: ${_formatBookingDate(booking.eventDate)}',
                        ),
                        if (timeRange != null)
                          Text(
                            'Time: $timeRange ($hours hr${hours == 1 ? '' : 's'})',
                          ),
                        Text('Estimate: $total'),
                        const SizedBox(height: 12),
                        if (booking.status == BookingStatus.pending)
                          const Text(
                            'Awaiting vendor confirmation',
                            style: TextStyle(color: Colors.black54),
                          )
                        else if (booking.status == BookingStatus.declined)
                          const Text(
                            'Vendor declined this request.',
                            style: TextStyle(color: Colors.redAccent),
                          )
                        else if (booking.status == BookingStatus.accepted) ...[
                          const Text(
                            'Vendor approved your request! Secure the slot with payment.',
                            style: TextStyle(color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton(
                              onPressed: () => _openPaymentPage(booking),
                              child: const Text('Pay now'),
                            ),
                          ),
                        ] else if (booking.status == BookingStatus.paid)
                          Text(
                            booking.paymentReference == null
                                ? 'Payment completed.'
                                : 'Payment reference: ${booking.paymentReference}',
                            style: const TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        Divider(color: Color(0xFFE2DBFF), thickness: 1),
        SizedBox(height: 16),
        Center(
          child: Text(
            'Book MY Event Now',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Color(0xFFB6AED6),
            ),
          ),
        ),
      ],
    );
  }

  Color _bookingStatusColor(BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => Colors.orange,
      BookingStatus.accepted => Colors.indigo,
      BookingStatus.declined => Colors.redAccent,
      BookingStatus.paid => Colors.green,
    };
  }

  int _hoursForBooking(Booking booking) {
    final duration = booking.duration;
    if (duration != null && duration.inHours > 0) {
      return duration.inHours;
    }
    return booking.hoursBooked;
  }

  String? _formatBookingTimeRange(BuildContext context, Booking booking) {
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

  String _formatBookingDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String _formatCurrency(double value) {
    const rupee = '\u20B9';
    if (value == 0) return "${rupee}0";
    if (value >= 100000) {
      final lakhValue = (value / 100000).toStringAsFixed(1);
      return "$rupee${lakhValue}L";
    }
    final formatted = value.toStringAsFixed(
      value.truncateToDouble() == value ? 0 : 2,
    );
    return "$rupee$formatted";
  }

  void _openPaymentPage(Booking booking) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BookingPaymentPage(booking: booking)),
    );
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }
}

class VendorHomePage extends StatefulWidget {
  final User user;
  const VendorHomePage({required this.user, super.key});

  @override
  State<VendorHomePage> createState() => _VendorHomePageState();
}

class _VendorHomePageState extends State<VendorHomePage> {
  final VendorRepository _vendorRepository = VendorRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final BookingRepository _bookingRepository = BookingRepository();
  int _tabIndex = 0;
  bool _processingSubscription = false;
  static const double _annualSubscriptionFee = 500;
  late final Razorpay _razorpay;
  Vendor? _pendingSubscriptionVendor;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSubscriptionPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onSubscriptionPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onSubscriptionExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Category>>(
      stream: _categoryRepository.streamCategories(),
      builder: (context, categorySnapshot) {
        final categories = categorySnapshot.data ?? const <Category>[];
        return StreamBuilder<Vendor?>(
          stream: _vendorRepository.streamVendorForOwner(widget.user.uid),
          builder: (context, vendorSnapshot) {
            final vendor = vendorSnapshot.data;
            return StreamBuilder<List<Booking>>(
              stream: _bookingRepository.streamVendorBookings(widget.user.uid),
              builder: (context, bookingSnapshot) {
                final bookings = bookingSnapshot.data ?? const <Booking>[];
                final pendingBookings = bookings
                    .where((booking) => booking.status == BookingStatus.pending)
                    .length;

                return Scaffold(
                  backgroundColor: const Color(0xFFF6F7FB),
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 0.3,
                    title: const Text('Vendor Home'),
                    actions: [
                      if (pendingBookings > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '$pendingBookings pending',
                              style: TextStyle(color: Colors.orange.shade800),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Sign out',
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          await UserRoleStorage.instance.clearRole(
                            widget.user.uid,
                          );
                          await FirebaseAuth.instance.signOut();
                          await GoogleSignIn().signOut();
                        },
                      ),
                    ],
                  ),
                  floatingActionButton: vendor == null
                      ? FloatingActionButton.extended(
                          onPressed: categories.isEmpty
                              ? null
                              : () => _openVendorSheet(categories: categories),
                          icon: const Icon(Icons.add),
                          label: const Text('Create vendor'),
                        )
                      : null,
                  bottomNavigationBar: vendor == null
                      ? null
                      : BottomNavigationBar(
                          type: BottomNavigationBarType.fixed,
                          currentIndex: _tabIndex,
                          onTap: (index) => setState(() => _tabIndex = index),
                          items: const [
                            BottomNavigationBarItem(
                              icon: Icon(Icons.storefront_outlined),
                              activeIcon: Icon(Icons.storefront),
                              label: 'Home',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.event_note_outlined),
                              activeIcon: Icon(Icons.event_note),
                              label: 'Bookings',
                            ),
                            BottomNavigationBarItem(
                              icon: Icon(Icons.workspace_premium_outlined),
                              activeIcon: Icon(Icons.workspace_premium),
                              label: 'Subscription',
                            ),
                          ],
                        ),
                  body: vendor == null
                      ? _buildEmptyVendorState(categories.isEmpty)
                      : IndexedStack(
                          index: _tabIndex,
                          children: [
                            _buildVendorOverview(
                              vendor: vendor,
                              categories: categories,
                              bookings: bookings,
                              pendingBookings: pendingBookings,
                            ),
                            _buildVendorBookingsView(bookings: bookings),
                            _buildVendorSubscriptionTab(vendor),
                          ],
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openVendorSheet({
    required List<Category> categories,
    Vendor? vendor,
  }) async {
    if (!mounted) return;
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a category before adding a vendor profile.'),
        ),
      );
      return;
    }

    Category? selectedCategory;
    Map<String, dynamic>? payload;
    var deleteRequested = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => VendorEditSheet(
        vendor: vendor,
        categories: categories,
        onSubmit: (category, data) {
          selectedCategory = category;
          payload = data;
        },
        onDelete: vendor == null
            ? null
            : () {
                deleteRequested = true;
                Navigator.of(context).maybePop();
              },
      ),
    );

    if (!mounted) return;

    try {
      if (deleteRequested && vendor != null) {
        await _vendorRepository.deleteVendor(vendor.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendor profile deleted.')),
        );
        return;
      }

      if (selectedCategory == null || payload == null) return;

      final categoryIds = <String>{
        selectedCategory!.id,
        if (vendor != null) ...vendor.categoryIds,
      }..removeWhere((id) => id.isEmpty);

      final categoryNames = <String>{
        selectedCategory!.name,
        if (vendor != null) ...vendor.categoryNames,
      }..removeWhere((name) => name.trim().isEmpty);

      final data = Map<String, dynamic>.from(payload!)
        ..['categoryId'] = selectedCategory!.id
        ..['categoryIds'] = categoryIds.toList()
        ..['category'] = selectedCategory!.name
        ..['categoryName'] = selectedCategory!.name
        ..['categoryNames'] = categoryNames.toList();

      await _vendorRepository.upsertVendor(
        id: vendor?.id,
        ownerUid: widget.user.uid,
        data: data,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            vendor == null
                ? 'Vendor profile created.'
                : 'Vendor profile updated.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update vendor: $error')),
      );
    }
  }

  Widget _buildEmptyVendorState(bool categoriesUnavailable) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              color: Colors.indigo.shade300,
              size: 52,
            ),
            const SizedBox(height: 16),
            const Text(
              'Set up your vendor presence',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              categoriesUnavailable
                  ? 'Categories are still loading. Please try again in a moment.'
                  : 'Tap the "Create vendor" button to add your business details and start receiving bookings.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorOverview({
    required Vendor vendor,
    required List<Category> categories,
    required List<Booking> bookings,
    required int pendingBookings,
  }) {
    final subscriptionActive = vendor.isSubscriptionActive;
    final expiry = vendor.subscriptionExpiresAt;
    final upcoming = bookings
        .where(
          (booking) =>
              booking.status == BookingStatus.accepted ||
              booking.status == BookingStatus.paid,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildVendorSummaryCard(
          vendor: vendor,
          canEdit: subscriptionActive,
          onEdit: () {
            if (!subscriptionActive) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Renew your subscription to update vendor details.',
                  ),
                ),
              );
              return;
            }
            _openVendorSheet(categories: categories, vendor: vendor);
          },
          onManageSubscription: () => setState(() => _tabIndex = 2),
        ),
        if (!subscriptionActive) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Subscription expired',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expiry == null
                        ? 'Activate your annual plan to publish your service to users.'
                        : 'Your plan expired on ${_formatBookingDate(expiry)}. Renew to make your listing visible to users.',
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _tabIndex = 2),
                    icon: const Icon(Icons.workspace_premium_outlined),
                    label: const Text('Manage subscription'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick glance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildVendorStatChip(
                      icon: Icons.hourglass_top_outlined,
                      label: 'Pending',
                      value: pendingBookings.toString(),
                    ),
                    _buildVendorStatChip(
                      icon: Icons.event_available_outlined,
                      label: 'Upcoming',
                      value: upcoming.toString(),
                    ),
                    _buildVendorStatChip(
                      icon: Icons.star_border,
                      label: 'Rating',
                      value: 'N/A',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Review and respond to booking requests from the Bookings tab.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVendorBookingsView({required List<Booking> bookings}) {
    final pending = bookings
        .where((booking) => booking.status == BookingStatus.pending)
        .toList();
    final confirmed = bookings
        .where(
          (booking) =>
              booking.status == BookingStatus.accepted ||
              booking.status == BookingStatus.paid,
        )
        .toList();
    final historical = bookings
        .where((booking) => booking.status == BookingStatus.declined)
        .toList();

    Widget buildSection({
      required String title,
      required List<Booking> items,
      required String emptyMessage,
      bool showActions = false,
    }) {
      if (items.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E3F1)),
              ),
              child: Text(
                emptyMessage,
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...items.map((booking) {
            final statusColor = _bookingStatusColor(booking.status);
            final total = _formatCurrency(booking.totalAmount);
            final timeRange = _formatVendorBookingTimeRange(booking);
            final hours = _hoursForVendorBooking(booking);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              booking.userEmail,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        backgroundColor: statusColor.withAlpha(28),
                        label: Text(
                          booking.status.label,
                          style: TextStyle(color: statusColor),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Event date: ${_formatBookingDate(booking.eventDate)}'),
                if (timeRange != null)
                  Text(
                    'Time: $timeRange ($hours hr${hours == 1 ? '' : 's'})',
                  ),
                Text('Estimated total: $total'),
                  const SizedBox(height: 12),
                  if (showActions)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _handleBookingUpdate(
                              booking,
                              BookingStatus.declined,
                            ),
                            icon: const Icon(Icons.close),
                            label: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _handleBookingUpdate(
                              booking,
                              BookingStatus.accepted,
                            ),
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        buildSection(
          title: 'Pending requests',
          items: pending,
          emptyMessage: 'No booking requests waiting for your response.',
          showActions: true,
        ),
        const SizedBox(height: 24),
        buildSection(
          title: 'Upcoming & confirmed',
          items: confirmed,
          emptyMessage: 'Accepted bookings will appear here.',
        ),
        const SizedBox(height: 24),
        buildSection(
          title: 'Declined requests',
          items: historical,
          emptyMessage: 'Declined bookings will appear here.',
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _subscriptionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubscriptionPaymentSuccess(
    PaymentSuccessResponse response,
  ) async {
    final vendor = _pendingSubscriptionVendor;
    _pendingSubscriptionVendor = null;
    try {
      if (vendor != null) {
        await _vendorRepository.activateSubscription(
          vendorId: vendor.id,
          amount: _annualSubscriptionFee,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription activated. Ref: ${response.paymentId ?? 'TEST'}',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment succeeded but activation failed: $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingSubscription = false);
    }
  }

  void _onSubscriptionPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _processingSubscription = false;
      _pendingSubscriptionVendor = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Subscription payment failed: ${response.message ?? response.code.toString()}',
        ),
      ),
    );
  }

  void _onSubscriptionExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() {
      _processingSubscription = false;
      _pendingSubscriptionVendor = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'External wallet selected: ${response.walletName ?? 'Unknown'}',
        ),
      ),
    );
  }

  Future<void> _handleSubscriptionPayment(Vendor vendor) async {
    if (_processingSubscription) return;
    setState(() {
      _processingSubscription = true;
      _pendingSubscriptionVendor = vendor;
    });

    final options = {
      'key': razorpayKeyId,
      'amount': (_annualSubscriptionFee * 100).round(),
      'currency': 'INR',
      'name': 'BookMyEventNow',
      'description': 'Vendor annual subscription',
      'prefill': {
        'contact': widget.user.phoneNumber ?? '',
        'email': widget.user.email ?? '',
      },
      'notes': {'vendorId': vendor.id},
    };

    try {
      _razorpay.open(options);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _processingSubscription = false;
        _pendingSubscriptionVendor = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start payment: $error')),
      );
    }
  }

  Widget _buildVendorSubscriptionTab(Vendor vendor) {
    final isActive = vendor.isSubscriptionActive;
    final expiry = vendor.subscriptionExpiresAt;
    final paidAt = vendor.subscriptionPaidAt;
    final daysRemaining = expiry != null
        ? expiry.difference(DateTime.now()).inDays
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: isActive
                            ? Colors.green.withAlpha(40)
                            : Colors.redAccent.withAlpha(40),
                        child: Icon(
                          Icons.workspace_premium,
                          color: isActive ? Colors.green : Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isActive
                                  ? 'Annual subscription active'
                                  : 'Subscription inactive',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isActive
                                  ? (expiry != null
                                        ? 'Renews on ${_formatBookingDate(expiry)}${daysRemaining >= 0 ? ' (${daysRemaining.abs()} day${daysRemaining.abs() == 1 ? '' : 's'} left)' : ''}'
                                        : 'Active plan')
                                  : 'Renew your plan to make your listing visible to users.',
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Plan details',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  _subscriptionRow('Plan', 'Annual vendor listing'),
                  _subscriptionRow(
                    'Amount',
                    '${_formatCurrency(_annualSubscriptionFee)} / year',
                  ),
                  _subscriptionRow(
                    'Last payment',
                    paidAt != null
                        ? _formatBookingDate(paidAt)
                        : 'Not yet billed',
                  ),
                  _subscriptionRow('Status', isActive ? 'Active' : 'Inactive'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processingSubscription
                  ? null
                  : () => _handleSubscriptionPayment(vendor),
              icon: _processingSubscription
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open),
              label: Text(
                isActive
                    ? 'Renew for ${_formatCurrency(_annualSubscriptionFee)}'
                    : 'Activate for ${_formatCurrency(_annualSubscriptionFee)}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your subscription keeps your service visible to users. Once a plan expires and is not renewed, your listing is hidden until you reactivate it.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorSummaryCard({
    required Vendor vendor,
    required bool canEdit,
    required VoidCallback onEdit,
    required VoidCallback onManageSubscription,
  }) {
    final expiry = vendor.subscriptionExpiresAt;
    final statusColor = canEdit ? Colors.green : Colors.redAccent;
    final statusLabel = canEdit ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E3F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                backgroundColor: statusColor.withAlpha(28),
                label: Text(
                  'Subscription: $statusLabel',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onManageSubscription,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.indigo.shade100,
                child: const Icon(Icons.storefront, color: Colors.indigo),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vendor.type.isNotEmpty ? vendor.type : 'Vendor',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vendor.location.isNotEmpty
                          ? vendor.location
                          : 'Location not provided',
                    ),
                    if (expiry != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Expires: ${_formatBookingDate(expiry)}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit vendor',
                onPressed: canEdit ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _VendorMetric(
                label: 'Rate / hr',
                value: _formatCurrency(vendor.price),
              ),
              _VendorMetric(
                label: 'Seating',
                value: vendor.capacity == 0 ? 'N/A' : '${vendor.capacity}',
              ),
              _VendorMetric(
                label: 'Parking',
                value: vendor.parkingCapacity == 0
                    ? 'N/A'
                    : '${vendor.parkingCapacity}',
              ),
              _VendorMetric(
                label: 'AC',
                value: vendor.ac ? 'Available' : 'Not available',
              ),
            ],
          ),
          if (vendor.moreDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Highlights',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(vendor.moreDetails),
          ],
          if (vendor.occasions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Occasions served',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: vendor.occasions
                  .map((occasion) => Chip(label: Text(occasion)))
                  .toList(),
            ),
          ],
          if (!canEdit) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Your listing is hidden from users. Renew your subscription to publish updates and receive new bookings.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.indigo),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _handleBookingUpdate(
    Booking booking,
    BookingStatus status,
  ) async {
    try {
      await _bookingRepository.updateStatus(
        bookingId: booking.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking marked as ${status.label.toLowerCase()}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update booking: $error')),
      );
    }
  }

  Color _bookingStatusColor(BookingStatus status) {
    return switch (status) {
      BookingStatus.pending => Colors.orange,
      BookingStatus.accepted => Colors.indigo,
      BookingStatus.declined => Colors.redAccent,
      BookingStatus.paid => Colors.green,
    };
  }

  int _hoursForVendorBooking(Booking booking) {
    final duration = booking.duration;
    if (duration != null && duration.inHours > 0) {
      return duration.inHours;
    }
    return booking.hoursBooked;
  }

  String? _formatVendorBookingTimeRange(Booking booking) {
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

  String _formatBookingDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String _formatCurrency(double value) {
    if (value == 0) return 'Rs 0';
    if (value >= 100000) return 'Rs ${(value / 100000).toStringAsFixed(1)}L';
    return 'Rs ${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2)}';
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isSelectable;

  const _ProfileDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isSelectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = isSelectable ? SelectableText(value) : Text(value);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                textWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VendorMetric extends StatelessWidget {
  final String label;
  final String value;
  const _VendorMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.indigo.withValues(alpha: 0.05),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

