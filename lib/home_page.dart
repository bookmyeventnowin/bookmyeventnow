import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'utils/dialog_utils.dart';
import 'utils/fee_utils.dart';

const Color _bookingAlertPrimary = Color(0xFF3C22C9);
const Color _bookingAlertBackground = Color(0xFFF7F2FF);

class UserHomePage extends StatefulWidget {
  final User user;
  final int initialIndex;
  const UserHomePage({required this.user, this.initialIndex = 0, super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  static const Color _backgroundCream = Color(0xFFFEFAF4);
  static const Color _cardSurface = Colors.white;
  static const int _carouselLoopBase = 10000;
  final BookingRepository _bookingRepository = BookingRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TextEditingController _searchController = TextEditingController();
  final PageController _carouselController = PageController(
    viewportFraction: 0.85,
    initialPage: _carouselLoopBase ~/ 2,
  );
  Timer? _carouselTimer;
  int _carouselItemCount = 0;
  final Set<String> _userAlertedBookingIds = <String>{};
  bool _userAlertDialogOpen = false;

  String _searchQuery = '';
  final ValueNotifier<int> _carouselIndexNotifier = ValueNotifier<int>(0);
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
  static const Map<String, String> _categoryIconAssets = {
    'catering': 'assets/icon/catering_icon.png',
    'communite hall': 'assets/icon/Community Hall_icon.png',
    'community hall': 'assets/icon/Community Hall_icon.png',
    'communityhall': 'assets/icon/Community Hall_icon.png',
    'decoration': 'assets/icon/Decoration_icon.png',
    'human resouce': 'assets/icon/Human Resource_icon.png',
    'human resource': 'assets/icon/Human Resource_icon.png',
    'humanresource': 'assets/icon/Human Resource_icon.png',
  };

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    userNavIndex.value = _currentIndex;
    if (_currentIndex == 0) {
      _startCarouselAutoPlay();
    }
    _navListener = () {
      if (!mounted) return;
      final next = userNavIndex.value;
      if (next != _currentIndex) {
        setState(() => _currentIndex = next);
        if (next == 0) {
          _startCarouselAutoPlay();
        } else {
          _stopCarouselAutoPlay();
        }
      }
    };
    userNavIndex.addListener(_navListener);
  }

  @override
  void dispose() {
    _stopCarouselAutoPlay();
    userNavIndex.removeListener(_navListener);
    _searchController.dispose();
    _carouselController.dispose();
    _carouselIndexNotifier.dispose();
    super.dispose();
  }

  void _startCarouselAutoPlay() {
    if (_currentIndex != 0 || _carouselItemCount <= 1) {
      _stopCarouselAutoPlay();
      return;
    }

    _carouselTimer?.cancel();
    _carouselTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || !_carouselController.hasClients) return;
      if (_carouselItemCount <= 1) return;

      final currentPage =
          _carouselController.page ?? _carouselIndexNotifier.value.toDouble();
      var nextPage = currentPage.floor() + 1;
      final upperBound = _carouselLoopBase - _carouselItemCount;
      if (nextPage >= upperBound) {
        final base = _carouselLoopBase ~/ 2;
        final alignedBase = base - (base % _carouselItemCount);
        _carouselController.jumpToPage(alignedBase);
        _carouselIndexNotifier.value = alignedBase;
        nextPage = alignedBase + 1;
      }

      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopCarouselAutoPlay() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
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

  String? _iconForCategory(Category category) {
    final name = category.name.trim().toLowerCase();
    if (_categoryIconAssets.containsKey(name)) {
      return _categoryIconAssets[name];
    }
    for (final entry in _categoryIconAssets.entries) {
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
      backgroundColor: _backgroundCream,
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
                _carouselIndexNotifier.value >= filteredCategories.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _carouselIndexNotifier.value = 0;
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
                _maybeShowUserBookingAlert(bookings);

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
      color: _backgroundCream,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchHeader(),
            const SizedBox(height: 24),
            _buildCategoryGrid(categories, isLoading),
            const SizedBox(height: 20),
            _buildCategoryCarousel(categories, isLoading),
            const SizedBox(height: 20),
            _buildPromiseCard(),
            const SizedBox(height: 32),
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab(List<Booking> bookings, bool isLoading) {
    return Container(
      color: _backgroundCream,
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

  void _maybeShowUserBookingAlert(List<Booking> bookings) {
    if (_userAlertDialogOpen || bookings.isEmpty) return;
    final actionable = bookings.where(_isUserBookingActionable).toList();
    if (actionable.isEmpty) return;
    final pending = actionable.firstWhere(
      (booking) => !_userAlertedBookingIds.contains(booking.id),
      orElse: () => actionable.first,
    );
    if (_userAlertedBookingIds.contains(pending.id)) return;
    _userAlertedBookingIds.add(pending.id);
    _userAlertDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _userAlertDialogOpen = false;
        return;
      }
      _showBookingAlertCard(
        context: context,
        heading: 'Booking update',
        name: pending.vendorName,
        message: _userBookingAlertMessage(pending),
        onView: () => navigateUserTab(context, 1),
      ).whenComplete(() {
        _userAlertDialogOpen = false;
      });
    });
  }

  bool _isUserBookingActionable(Booking booking) {
    if (booking.status == BookingStatus.accepted) return true;
    if (booking.proposalStatus == ProposalStatus.vendorQuoted) return true;
    if (booking.proposalStatus == ProposalStatus.vendorAccepted) return true;
    return false;
  }

  String _userBookingAlertMessage(Booking booking) {
    final dateLabel = _formatBookingDate(booking.eventDate);
    if (booking.proposalStatus == ProposalStatus.vendorQuoted) {
      final amount = booking.vendorQuoteAmount ?? booking.totalAmount;
      final amountLabel = amount > 0 ? ' (${_formatCurrency(amount)})' : '';
      return 'New quote for $dateLabel$amountLabel. Review and respond.';
    }
    if (booking.proposalStatus == ProposalStatus.vendorAccepted) {
      return 'Proposal accepted for $dateLabel. Complete payment to confirm.';
    }
    if (booking.status == BookingStatus.accepted) {
      return 'Booking approved for $dateLabel. Complete payment to secure your slot.';
    }
    return 'Update available for $dateLabel.';
  }

  Widget _buildProfileTab(User user, String initials) {
    final displayName = user.displayName ?? user.email ?? 'Guest';
    final email = user.email ?? 'Not available';
    final phone = user.phoneNumber;
    final photoUrl = user.photoURL;

    return Container(
      color: _backgroundCream,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: _cardSurface,
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.08),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
                        label: const Text('Log out'),
                        onPressed: _signOut,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildAboutBmeCard(),
            const SizedBox(height: 24),
            _buildHelpSupportCard(),
            const SizedBox(height: 32),
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutBmeCard() {
    const aboutBody =
        "BME Now is India's first all-in-one event services booking app, launched in 2025 to revolutionize how people plan and organize events.\n\n"
        "With BME Now, you can book a wide range of event-related services hassle-free\u2014no more long waits, no middlemen, and no unnecessary dependencies.";
    final highlights = [
      'One-stop booking for weddings, birthdays, corporate events, parties, and more.',
      'Browse and compare top-rated vendors with images and verified reviews.',
      'Smooth, secure Razorpay payments with multiple options.',
      'User-friendly interface with clean navigation.',
      'Transparent pricing, trusted vendors, and instant confirmations.',
    ];

    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'About BME Now',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(aboutBody, style: TextStyle(height: 1.4)),
            const SizedBox(height: 16),
            const Text(
              'Key reasons to choose BME Now:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...highlights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '- ',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Expanded(
                      child: Text(item, style: const TextStyle(height: 1.3)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Whether you are planning a grand wedding or a cozy celebration, BME Now helps you discover and book the right services quickly and confidently — all in one app.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSupportCard() {
    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Help & Support',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text(
              'Reach out to our team for assistance or feedback:',
              style: TextStyle(color: Colors.black87),
            ),
            SizedBox(height: 8),
            SelectableText(
              'Email: bookmyeventnow.in@gmail.com',
              style: TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                hintText: 'Search categories (e.g. Catering, Decoration)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCarousel(List<Category> categories, bool isLoading) {
    if (!isLoading) {
      final nextCount = categories.length;
      final countChanged = _carouselItemCount != nextCount;
      _carouselItemCount = nextCount;

      if (_carouselItemCount <= 1) {
        _stopCarouselAutoPlay();
      } else {
        if (countChanged) {
          final basePage = _carouselLoopBase ~/ 2;
          final alignedPage = basePage - (basePage % _carouselItemCount);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_carouselController.hasClients) {
              _carouselController.jumpToPage(alignedPage);
              _carouselIndexNotifier.value = alignedPage;
            }
          });
        }
        if (countChanged || _carouselTimer == null) {
          _startCarouselAutoPlay();
        }
      }
    } else {
      _carouselItemCount = categories.length;
      if (_carouselItemCount <= 1) {
        _stopCarouselAutoPlay();
      }
    }

    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                      child: Listener(
                        onPointerDown: (_) => _stopCarouselAutoPlay(),
                        onPointerUp: (_) => _startCarouselAutoPlay(),
                        onPointerCancel: (_) => _startCarouselAutoPlay(),
                        child: PageView.builder(
                          controller: _carouselController,
                          onPageChanged: (index) =>
                              _carouselIndexNotifier.value = index,
                          itemBuilder: (context, index) {
                            final displayIndex = categories.isEmpty
                                ? 0
                                : index % categories.length;
                            final category = categories[displayIndex];
                            final slideAsset = _assetForCategory(category);

                            Widget buildBackground() {
                              if (_isValidUrl(category.imageUrl)) {
                                return Image.network(
                                  category.imageUrl,
                                  fit: BoxFit.cover,
                                );
                              }
                              if (slideAsset != null) {
                                return Image.asset(
                                  slideAsset,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(color: Colors.grey.shade900);
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<int>(
                      valueListenable: _carouselIndexNotifier,
                      builder: (context, currentIndex, _) {
                        if (categories.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        final activeIndex = currentIndex % categories.length;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            categories.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              width: activeIndex == index ? 18 : 8,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: activeIndex == index
                                    ? Colors.indigo
                                    : Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<Category> categories, bool isLoading) {
    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                              height: 110,
                              width: 110,
                              child: _buildCategoryIcon(category),
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

  Widget _buildCategoryIcon(Category category) {
    final iconAsset = _iconForCategory(category);
    if (iconAsset != null) {
      return Image.asset(iconAsset, fit: BoxFit.cover);
    }
    if (_isValidUrl(category.imageUrl)) {
      return Image.network(category.imageUrl, fit: BoxFit.cover);
    }
    final slideAsset = _assetForCategory(category);
    if (slideAsset != null) {
      return Image.asset(slideAsset, fit: BoxFit.cover);
    }
    return Container(
      color: Colors.grey.shade900,
      alignment: Alignment.center,
      child: const Icon(Icons.photo, color: Colors.white70),
    );
  }

  Widget _buildPromiseCard() {
    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'BME Now Promise',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  PromiseBullet(text: 'Verified professional vendors'),
                  SizedBox(height: 8),
                  PromiseBullet(text: 'Hassle-free booking experience'),
                  SizedBox(height: 8),
                  PromiseBullet(text: 'Transparent pricing every time'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 84,
              width: 84,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDCD3FF), Color(0xFFE7F5FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(42),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.verified, size: 42, color: Colors.deepPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBookingsCard(List<Booking> bookings, bool isLoading) {
    return Card(
      color: _cardSurface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
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
                  final isCatering = booking.isCateringProposal;
                  final statusWidgets = isCatering
                      ? _buildUserCateringStatusWidgets(booking)
                      : _buildStandardUserBookingStatus(booking);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardSurface,
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
                        if (!isCatering && timeRange != null)
                          Text(
                            'Time: $timeRange ($hours hr${hours == 1 ? '' : 's'})',
                          ),
                        if (isCatering && booking.proposalMenu.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: booking.proposalMenu
                                .map(
                                  (item) => Chip(
                                    avatar: Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: item.isVeg
                                          ? Colors.green
                                          : Colors.redAccent,
                                    ),
                                    label: Text(item.name),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (isCatering && booking.proposalGuestCount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Guests: ${booking.proposalGuestCount}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (isCatering)
                          Text(
                            booking.totalAmount > 0
                                ? 'Current amount: $total'
                                : 'Quote pending',
                          ),
                        if (booking.totalAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _PayoutBreakdown(
                              amount: booking.totalAmount,
                              settlementLabel: 'Estimate amount',
                              formatCurrency: _formatCurrency,
                              onInfoTap: () => showFeeBreakdownDialog(
                                context: context,
                                breakdown: _calculateFees(booking.totalAmount),
                                formatCurrency: _formatCurrency,
                              ),
                            ),
                          ),
                        if (isCatering) ...[
                          if (booking.proposalDeliveryRequired &&
                              (booking.proposalDeliveryAddress ?? '')
                                  .isNotEmpty)
                            Text(
                              'Delivery address: ${booking.proposalDeliveryAddress}',
                            ),
                          if (!booking.proposalDeliveryRequired)
                            const Text('Pickup: you will collect the order'),
                          if (booking.proposalDeliveryTime != null)
                            Text(
                              'Delivery time: ${_formatDeliveryDateTime(context, booking.proposalDeliveryTime!)}',
                            ),
                        ],
                        const SizedBox(height: 12),
                        ...statusWidgets,
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

  List<Widget> _buildStandardUserBookingStatus(Booking booking) {
    switch (booking.status) {
      case BookingStatus.pending:
        return const [
          Text(
            'Awaiting vendor confirmation',
            style: TextStyle(color: Colors.black54),
          ),
        ];
      case BookingStatus.declined:
        return const [
          Text(
            'Vendor declined this request.',
            style: TextStyle(color: Colors.redAccent),
          ),
        ];
      case BookingStatus.accepted:
        return [
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
        ];
      case BookingStatus.paid:
        return _buildPaidUserBookingWidgets(booking);
    }
  }

  List<Widget> _buildPaidUserBookingWidgets(Booking booking) {
    final widgets = <Widget>[];
    if (booking.paymentReference != null) {
      widgets.add(
        Text(
          'Payment reference: ${booking.paymentReference}',
          style: const TextStyle(color: Colors.green),
        ),
      );
    } else {
      widgets.add(
        const Text('Payment completed.', style: TextStyle(color: Colors.green)),
      );
    }
    widgets.add(const SizedBox(height: 8));
    if (booking.rating == null) {
      widgets.add(
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => _promptForRating(booking),
            icon: const Icon(Icons.star_outline),
            label: const Text('Rate experience'),
          ),
        ),
      );
    } else {
      widgets.add(
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 4),
            Text(
              '${booking.rating}/5',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
      if ((booking.review ?? '').isNotEmpty) {
        widgets.add(const SizedBox(height: 4));
        widgets.add(
          Text(booking.review!, style: const TextStyle(color: Colors.black54)),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildUserCateringStatusWidgets(Booking booking) {
    if (booking.status == BookingStatus.paid) {
      return _buildPaidUserBookingWidgets(booking);
    }
    final proposalStatus = booking.proposalStatus;
    final quote = booking.vendorQuoteAmount ?? booking.totalAmount;
    final counter = booking.userCounterAmount;
    final widgets = <Widget>[];
    bool addedPayButton = false;

    switch (proposalStatus) {
      case ProposalStatus.vendorQuoted:
        widgets.add(
          Text(
            'Quote received: ${_formatCurrency(quote)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _acceptCateringQuote(booking),
                child: const Text('Accept quote'),
              ),
              OutlinedButton(
                onPressed: () => _promptCateringCounter(booking),
                child: const Text('Negotiate'),
              ),
            ],
          ),
        );
        break;
      case ProposalStatus.userCounter:
        widgets.add(
          Text(
            'Counter offer sent: ${_formatCurrency(counter ?? 0)}',
            style: const TextStyle(color: Colors.black87),
          ),
        );
        widgets.add(
          const Text(
            'Waiting for the vendor to respond.',
            style: TextStyle(color: Colors.black54),
          ),
        );
        break;
      case ProposalStatus.vendorAccepted:
        widgets.add(
          Text(
            'Vendor accepted your proposal at ${_formatCurrency(booking.totalAmount)}.',
            style: const TextStyle(color: Colors.black87),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _openPaymentPage(booking),
              child: const Text('Pay now'),
            ),
          ),
        );
        addedPayButton = true;
        break;
      case ProposalStatus.vendorDeclined:
        widgets.add(
          const Text(
            'Vendor declined this proposal.',
            style: TextStyle(color: Colors.redAccent),
          ),
        );
        break;
      case ProposalStatus.sent:
      case null:
        widgets.add(
          const Text(
            'Proposal sent. The vendor will review your menu and share a quote.',
            style: TextStyle(color: Colors.black54),
          ),
        );
        break;
    }

    if (!addedPayButton && booking.status == BookingStatus.accepted) {
      widgets.add(
        const Text(
          'Vendor approved your proposal. Complete the payment to confirm.',
          style: TextStyle(color: Colors.black87),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      widgets.add(
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => _openPaymentPage(booking),
            child: const Text('Pay now'),
          ),
        ),
      );
    } else if (booking.status == BookingStatus.declined &&
        proposalStatus != ProposalStatus.vendorDeclined) {
      widgets.add(
        const Text(
          'Vendor declined this request.',
          style: TextStyle(color: Colors.redAccent),
        ),
      );
    }

    return widgets;
  }

  Future<void> _acceptCateringQuote(Booking booking) async {
    try {
      await _bookingRepository.userAcceptQuote(bookingId: booking.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quote accepted for ${booking.vendorName}. You can proceed to payment.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to accept quote: $error')),
        );
      }
    }
  }

  Future<void> _promptCateringCounter(Booking booking) async {
    final controller = TextEditingController(
      text: booking.userCounterAmount?.toStringAsFixed(0) ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _bookingAlertBackground,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Counter offer for ${booking.vendorName}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter your offer (Rs)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _bookingAlertPrimary,
                              side: const BorderSide(
                                color: _bookingAlertPrimary,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              final value = double.parse(controller.text);
                              Navigator.of(dialogContext).pop(value);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _bookingAlertPrimary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Send counter'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    try {
      await _bookingRepository.userCounterQuote(
        bookingId: booking.id,
        amount: result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Counter offer sent to the vendor.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send counter offer: $error')),
        );
      }
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

  String _formatDeliveryDateTime(BuildContext context, DateTime value) {
    final dateLabel = _formatBookingDate(value);
    final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: false,
    );
    return '$dateLabel at $timeLabel';
  }

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

  Future<void> _promptForRating(Booking booking) async {
    final commentController = TextEditingController(text: booking.review ?? '');
    int tempRating = booking.rating ?? 5;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Rate ${booking.vendorName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final filled = index < tempRating;
                      return IconButton(
                        onPressed: () => setState(() => tempRating = index + 1),
                        icon: Icon(
                          filled ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comments (optional)',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'rating': tempRating,
                      'review': commentController.text.trim(),
                    });
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
    commentController.dispose();
    if (result == null) return;

    final selectedRating = result['rating'] as int?;
    final review = result['review'] as String?;
    if (selectedRating == null || selectedRating < 1) return;

    try {
      await _bookingRepository.submitRating(
        bookingId: booking.id,
        rating: selectedRating,
        review: review,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for sharing your feedback!')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to submit rating: $error')),
      );
    }
  }

  bool _isValidUrl(String value) {
    if (value.isEmpty) return false;
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  }
}

class PromiseBullet extends StatelessWidget {
  const PromiseBullet({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '- ',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.black87, height: 1.3),
          ),
        ),
      ],
    );
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
  final Set<String> _vendorAlertedBookingIds = <String>{};
  bool _vendorAlertDialogOpen = false;

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
                _maybeShowVendorBookingAlert(bookings);

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
                        tooltip: 'Log Out',
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

  void _maybeShowVendorBookingAlert(List<Booking> bookings) {
    if (_vendorAlertDialogOpen || bookings.isEmpty) return;
    final actionable = bookings.where(_isVendorBookingActionable).toList();
    if (actionable.isEmpty) return;
    final pending = actionable.firstWhere(
      (booking) => !_vendorAlertedBookingIds.contains(booking.id),
      orElse: () => actionable.first,
    );
    if (_vendorAlertedBookingIds.contains(pending.id)) return;
    _vendorAlertedBookingIds.add(pending.id);
    _vendorAlertDialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _vendorAlertDialogOpen = false;
        return;
      }
      _showBookingAlertCard(
        context: context,
        heading: 'Booking update',
        name: pending.userName.isNotEmpty
            ? pending.userName
            : pending.userEmail,
        message: _vendorBookingAlertMessage(pending),
        onView: () => setState(() => _tabIndex = 1),
      ).whenComplete(() {
        _vendorAlertDialogOpen = false;
      });
    });
  }

  bool _isVendorBookingActionable(Booking booking) {
    if (booking.status == BookingStatus.pending) return true;
    if (booking.proposalStatus == ProposalStatus.sent) return true;
    if (booking.proposalStatus == ProposalStatus.userCounter) return true;
    return false;
  }

  String _vendorBookingAlertMessage(Booking booking) {
    final dateLabel = _formatBookingDate(booking.eventDate);
    if (booking.proposalStatus == ProposalStatus.userCounter) {
      final amount = booking.userCounterAmount ?? 0;
      final amountLabel = amount > 0 ? ' (${_formatCurrency(amount)})' : '';
      return 'Counter offer for $dateLabel$amountLabel. Review and respond.';
    }
    if (booking.proposalStatus == ProposalStatus.sent) {
      return 'New proposal for $dateLabel. Send your quote.';
    }
    return 'Response pending for $dateLabel. Take action to update the customer.';
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
        ownerUid: widget.user.uid,
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

  bool _isDecorationVendor(Vendor vendor) {
    final lowerType = vendor.type.toLowerCase();
    if (lowerType.contains('decor')) return true;
    final names = <String>{
      vendor.categoryName.toLowerCase(),
      ...vendor.categoryNames.map((name) => name.toLowerCase()),
    };
    return names.any((name) => name.contains('decor'));
  }

  bool _isCateringVendor(Vendor vendor) {
    final lowerType = vendor.type.toLowerCase();
    if (lowerType.contains('cater')) return true;
    final names = <String>{
      vendor.categoryName.toLowerCase(),
      ...vendor.categoryNames.map((name) => name.toLowerCase()),
    };
    return names.any((name) => name.contains('cater'));
  }

  bool _isHumanResourceVendor(Vendor vendor) {
    final lowerType = vendor.type.toLowerCase();
    if (lowerType.contains('human')) return true;
    final names = <String>{
      vendor.categoryName.toLowerCase(),
      ...vendor.categoryNames.map((name) => name.toLowerCase()),
    };
    return names.any((name) => name.contains('human'));
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
    final ratedBookings = bookings
        .where((booking) => booking.rating != null)
        .toList();
    final double? averageRating = ratedBookings.isEmpty
        ? null
        : ratedBookings
                  .map((booking) => booking.rating!.toDouble())
                  .reduce((value, element) => value + element) /
              ratedBookings.length;
    final ratingLabel = averageRating == null
        ? 'N/A'
        : '${averageRating.toStringAsFixed(1)}/5 (${ratedBookings.length})';

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
                      icon: averageRating == null
                          ? Icons.star_border
                          : Icons.star,
                      label: 'Rating',
                      value: ratingLabel,
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
            final isCatering = booking.isCateringProposal;
            final cateringWidgets = isCatering
                ? _buildVendorCateringStatusWidgets(booking)
                : const <Widget>[];

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
                  if (!isCatering && timeRange != null)
                    Text(
                      'Time: $timeRange ($hours hr${hours == 1 ? '' : 's'})',
                    ),
                  if (isCatering && booking.proposalMenu.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: booking.proposalMenu
                          .map(
                            (item) => Chip(
                              avatar: Icon(
                                Icons.circle,
                                size: 10,
                                color: item.isVeg
                                    ? Colors.green
                                    : Colors.redAccent,
                              ),
                              label: Text(item.name),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (isCatering && booking.proposalGuestCount != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Guests: ${booking.proposalGuestCount}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (isCatering)
                    Text(
                      booking.totalAmount > 0
                          ? 'Current amount: $total'
                          : 'Awaiting quote',
                    ),
                  if (booking.totalAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _PayoutBreakdown(
                        amount: booking.totalAmount,
                        settlementLabel: 'Your quote',
                        formatCurrency: _formatCurrency,
                        showSubtraction: true,
                        onInfoTap: () => showFeeBreakdownDialog(
                          context: context,
                          breakdown: _calculateFees(booking.totalAmount),
                          formatCurrency: _formatCurrency,
                          includeCommission: false,
                        ),
                      ),
                    ),
                  if (isCatering) ...[
                    if (booking.proposalDeliveryRequired &&
                        (booking.proposalDeliveryAddress ?? '').isNotEmpty)
                      Text(
                        'Delivery address: ${booking.proposalDeliveryAddress}',
                      ),
                    if (!booking.proposalDeliveryRequired)
                      const Text('Pickup arranged'),
                    if (booking.proposalDeliveryTime != null)
                      Text(
                        'Delivery time: ${_formatDeliveryDateTime(context, booking.proposalDeliveryTime!)}',
                      ),
                  ],
                  const SizedBox(height: 12),
                  if (!isCatering && showActions)
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
                    )
                  else if (isCatering)
                    ...cateringWidgets,
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
    final isProcessing =
        _processingSubscription && _pendingSubscriptionVendor?.id == vendor.id;
    final canRenew = !isActive && !isProcessing;

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
              onPressed: canRenew
                  ? () => _handleSubscriptionPayment(vendor)
                  : null,
              icon: isProcessing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isActive ? Icons.lock : Icons.lock_open),
              label: Text(
                isActive
                    ? 'Renew for ${_formatCurrency(_annualSubscriptionFee)}'
                    : 'Activate for ${_formatCurrency(_annualSubscriptionFee)}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
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
          if (_isDecorationVendor(vendor)) ...[
            const SizedBox(height: 16),
            _DecorationPackageCarousel(
              packages: vendor.decorationPackages,
              formatCurrency: _formatCurrency,
            ),
          ] else if (_isCateringVendor(vendor)) ...[
            const SizedBox(height: 16),
            _CateringMenuSection(items: vendor.menuItems),
          ] else if (_isHumanResourceVendor(vendor)) ...[
            const SizedBox(height: 16),
            _HumanResourceInfoSection(
              vendor: vendor,
              formatCurrency: _formatCurrency,
            ),
          ] else ...[
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
          ],
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

  List<Widget> _buildVendorCateringStatusWidgets(Booking booking) {
    final status = booking.proposalStatus;
    final widgets = <Widget>[];
    switch (status) {
      case ProposalStatus.sent:
      case null:
        widgets.add(
          const Text(
            'Customer is waiting for your quote.',
            style: TextStyle(color: Colors.black87),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _promptVendorQuote(booking),
                child: const Text('Send quote'),
              ),
              OutlinedButton(
                onPressed: () => _respondToCateringCounter(booking, false),
                child: const Text('Decline'),
              ),
            ],
          ),
        );
        break;
      case ProposalStatus.vendorQuoted:
        widgets.add(
          Text(
            'Quote sent: ${_formatCurrency(booking.vendorQuoteAmount ?? 0)}',
            style: const TextStyle(color: Colors.black87),
          ),
        );
        widgets.add(
          const Text(
            'Waiting for the customer to respond.',
            style: TextStyle(color: Colors.black54),
          ),
        );
        break;
      case ProposalStatus.userCounter:
        widgets.add(
          Text(
            'Counter offer: ${_formatCurrency(booking.userCounterAmount ?? 0)}',
            style: const TextStyle(color: Colors.black87),
          ),
        );
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _respondToCateringCounter(booking, false),
                child: const Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () => _respondToCateringCounter(booking, true),
                child: const Text('Accept counter'),
              ),
            ],
          ),
        );
        break;
      case ProposalStatus.vendorAccepted:
        widgets.add(
          const Text(
            'Proposal accepted. Awaiting customer payment.',
            style: TextStyle(color: Colors.black54),
          ),
        );
        break;
      case ProposalStatus.vendorDeclined:
        widgets.add(
          const Text(
            'You declined this proposal.',
            style: TextStyle(color: Colors.redAccent),
          ),
        );
        break;
    }
    return widgets;
  }

  Future<void> _promptVendorQuote(Booking booking) async {
    final controller = TextEditingController(
      text: booking.vendorQuoteAmount?.toStringAsFixed(0) ?? '',
    );
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _bookingAlertBackground,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Send quote',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quote amount (Rs)',
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value ?? '');
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid amount';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _bookingAlertPrimary,
                              side: const BorderSide(
                                color: _bookingAlertPrimary,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 10,
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 16),
                          FilledButton(
                            onPressed: () {
                              if (!formKey.currentState!.validate()) return;
                              final value = double.parse(controller.text);
                              Navigator.of(dialogContext).pop(value);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: _bookingAlertPrimary,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Send quote'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (result == null) return;
    try {
      await _bookingRepository.vendorSendQuote(
        bookingId: booking.id,
        amount: result,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote sent to the customer.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to send quote: $error')));
      }
    }
  }

  Future<void> _respondToCateringCounter(Booking booking, bool accept) async {
    try {
      await _bookingRepository.vendorRespondToCounter(
        bookingId: booking.id,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? 'Counter offer accepted.' : 'Proposal declined.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update proposal: $error')),
      );
    }
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

class _CateringMenuSection extends StatelessWidget {
  const _CateringMenuSection({required this.items});

  final List<VendorMenuItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: const Text(
          'Add menu items to highlight your catering dishes.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu items',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: item.isVeg ? Colors.green : Colors.redAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item.isVeg
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      item.isVeg ? 'Veg' : 'Non-veg',
                      style: TextStyle(
                        color: item.isVeg
                            ? Colors.green.shade700
                            : Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecorationPackageCarousel extends StatefulWidget {
  const _DecorationPackageCarousel({
    required this.packages,
    required this.formatCurrency,
  });

  final List<VendorDecorationPackage> packages;
  final String Function(double value) formatCurrency;

  @override
  State<_DecorationPackageCarousel> createState() =>
      _DecorationPackageCarouselState();
}

class _DecorationPackageCarouselState
    extends State<_DecorationPackageCarousel> {
  late final PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.packages.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Add decoration packages to showcase images with prices.',
          style: TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.packages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final package = widget.packages[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        package.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Color.fromARGB(200, 0, 0, 0),
                              Color.fromARGB(10, 0, 0, 0),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            package.price <= 0
                                ? 'Contact for pricing'
                                : 'Package price: ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
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
            widget.packages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 8,
              width: _currentPage == index ? 18 : 8,
              decoration: BoxDecoration(
                color: _currentPage == index ? Colors.black87 : Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
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

class _HumanResourceInfoSection extends StatelessWidget {
  const _HumanResourceInfoSection({
    required this.vendor,
    required this.formatCurrency,
  });

  final Vendor vendor;
  final String Function(double value) formatCurrency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _hrRow(
            'Experience',
            vendor.experience.isEmpty ? 'N/A' : vendor.experience,
          ),
          _hrRow('Hourly charge', formatCurrency(vendor.price)),
          _hrRow(
            'Languages',
            vendor.languages.isEmpty ? 'N/A' : vendor.languages,
          ),
          _hrRow(
            'Education',
            vendor.education.isEmpty ? 'N/A' : vendor.education,
          ),
          _hrRow('Area', vendor.area.isEmpty ? 'N/A' : vendor.area),
          _hrRow('State', vendor.state.isEmpty ? 'N/A' : vendor.state),
          _hrRow(
            'Proof',
            vendor.proofUrl.isEmpty
                ? 'Not uploaded'
                : 'Verified document uploaded',
          ),
        ],
      ),
    );
  }

  Widget _hrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutBreakdown extends StatelessWidget {
  const _PayoutBreakdown({
    required this.amount,
    required this.settlementLabel,
    required this.formatCurrency,
    this.showSubtraction = false,
    this.onInfoTap,
  });

  final double amount;
  final String settlementLabel;
  final String Function(double value) formatCurrency;
  final bool showSubtraction;
  final VoidCallback? onInfoTap;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final fees = _calculateFees(amount);
    final textStyle = TextStyle(
      color: Colors.black.withValues(alpha: 0.75),
      fontSize: 13,
    );

    if (!showSubtraction) {
      return Row(
        children: [
          Expanded(
            child: Text(
              '$settlementLabel: ${formatCurrency(fees.totalWithFees)}',
              style: textStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
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
      );
    }

    final vendorDeductions = fees.gst + fees.pgFee;
    final vendorNet = fees.base - vendorDeductions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$settlementLabel: ${formatCurrency(fees.base)}',
                style: textStyle.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
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
        const SizedBox(height: 4),
        Text(
          'You receive: ${formatCurrency(vendorNet)} '
          '(after GST and payment gateway fees)',
          style: textStyle.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

FeeBreakdown _calculateFees(double amount) => calculateFeeBreakdown(amount);

Future<void> _showBookingAlertCard({
  required BuildContext context,
  required String heading,
  required String name,
  required String message,
  required VoidCallback onView,
}) {
  SystemSound.play(SystemSoundType.alert);
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: _bookingAlertBackground,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                heading,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _bookingAlertPrimary.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _bookingAlertPrimary,
                      side: BorderSide(color: _bookingAlertPrimary),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                    ),
                    child: const Text('Later'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      onView();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _bookingAlertPrimary,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('View booking'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatDeliveryDateTime(BuildContext context, DateTime value) {
  final dateLabel = '${value.day}/${value.month}/${value.year}';
  final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value),
    alwaysUse24HourFormat: false,
  );
  return '$dateLabel at $timeLabel';
}
