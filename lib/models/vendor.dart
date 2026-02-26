import 'package:cloud_firestore/cloud_firestore.dart';

import 'category.dart';

class Vendor {
  final String id;
  final String ownerUid;
  final String name;
  final String email;
  final String phone;
  final String type;
  final double price;
  final int capacity;
  final int parkingCapacity;
  final bool ac;
  final List<String> occasions;
  final String moreDetails;
  final String imageUrl;
  final List<String> galleryImages;
  final List<VendorDecorationPackage> decorationPackages;
  final List<VendorMenuItem> menuItems;
  final String categoryId;
  final List<String> categoryIds;
  final String categoryName;
  final List<String> categoryNames;
  final String location;
  final String area;
  final String pincode;
  final String experience;
  final String languages;
  final String education;
  final String state;
  final String proofUrl;
  final double ratingAverage;
  final int ratingCount;
  final double ratingTotal;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? subscriptionPaidAt;
  final DateTime? subscriptionExpiresAt;
  final String subscriptionStatus;
  final double subscriptionAmountLastPaid;

  const Vendor({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    required this.price,
    required this.capacity,
    required this.parkingCapacity,
    required this.ac,
    required this.occasions,
    required this.moreDetails,
    required this.imageUrl,
    required this.galleryImages,
    required this.decorationPackages,
    required this.menuItems,
    required this.categoryId,
    required this.categoryIds,
    required this.categoryName,
    required this.categoryNames,
    required this.location,
    required this.area,
    required this.pincode,
    required this.experience,
    required this.languages,
    required this.education,
    required this.state,
    required this.proofUrl,
    required this.ratingAverage,
    required this.ratingCount,
    required this.ratingTotal,
    required this.createdAt,
    required this.updatedAt,
    required this.subscriptionPaidAt,
    required this.subscriptionExpiresAt,
    required this.subscriptionStatus,
    required this.subscriptionAmountLastPaid,
  });

  factory Vendor.fromFirestore(Map<String, dynamic> data, String id) {
    final occasions = <String>[];
    final rawOccasions = data['occasions'] ?? data['occasionsFor'];
    if (rawOccasions is Iterable) {
      occasions.addAll(rawOccasions.map((e) => e.toString()));
    } else if (rawOccasions is String) {
      occasions.addAll(
        rawOccasions.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }

    final primaryCategoryId = (data['categoryId'] as String?)?.trim() ?? '';
    final categoryIds = <String>[];
    if (primaryCategoryId.isNotEmpty) categoryIds.add(primaryCategoryId);
    final rawCategoryIds = data['categoryIds'];
    if (rawCategoryIds is Iterable) {
      categoryIds.addAll(
        rawCategoryIds
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final primaryCategoryName =
        (data['categoryName'] as String?)?.trim() ??
        (data['category'] as String?)?.trim() ??
        '';
    final categoryNames = <String>[];
    if (primaryCategoryName.isNotEmpty) categoryNames.add(primaryCategoryName);
    final rawCategoryNames = data['categoryNames'];
    if (rawCategoryNames is Iterable) {
      categoryNames.addAll(
        rawCategoryNames
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty),
      );
    }

    final galleryImages = <String>[];
    void addGalleryItem(dynamic value) {
      if (value == null) return;
      final trimmed = value.toString().trim();
      if (trimmed.isEmpty) return;
      if (!galleryImages.contains(trimmed)) {
        galleryImages.add(trimmed);
      }
    }

    final rawGallery = data['galleryImages'] ?? data['gallery'];
    if (rawGallery is Iterable) {
      for (final item in rawGallery) {
        addGalleryItem(item);
      }
    }
    final rawImages = data['images'];
    if (rawImages is Iterable) {
      for (final item in rawImages) {
        addGalleryItem(item);
      }
    }

    final menuItems = <VendorMenuItem>[];
    final rawMenu = data['menuItems'] ?? data['menu'];
    if (rawMenu is Iterable) {
      for (final item in rawMenu) {
        final menuItem = VendorMenuItem.fromMap(item);
        if (menuItem != null && menuItem.name.isNotEmpty) {
          menuItems.add(menuItem);
        }
      }
    }

    double parsePrice() {
      final priceCandidates = [
        data['price'],
        data['pricePerHour'],
        data['price_per_hour'],
        data['basePrice'],
      ];
      for (final candidate in priceCandidates) {
        if (candidate is num) return candidate.toDouble();
        final parsed = double.tryParse('$candidate');
        if (parsed != null) return parsed;
      }
      return 0;
    }

    int parseCapacity() {
      final capacityCandidates = [
        data['capacity'],
        data['seatingCapacity'],
        data['capacityMax'],
      ];
      for (final candidate in capacityCandidates) {
        if (candidate is num) return candidate.toInt();
        final parsed = int.tryParse('$candidate');
        if (parsed != null) return parsed;
      }
      return 0;
    }

    int parseParking() {
      final parkingCandidates = [data['parkingCapacity'], data['parking']];
      for (final candidate in parkingCandidates) {
        if (candidate is num) return candidate.toInt();
        final parsed = int.tryParse('$candidate');
        if (parsed != null) return parsed;
      }
      return 0;
    }

    DateTime? parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final decorationPackages = <VendorDecorationPackage>[];
    final rawPackages = data['decorationPackages'];
    if (rawPackages is Iterable) {
      for (final item in rawPackages) {
        final pkg = VendorDecorationPackage.fromMap(item);
        if (pkg != null) {
          decorationPackages.add(pkg);
          if (pkg.imageUrl.isNotEmpty) {
            addGalleryItem(pkg.imageUrl);
          }
        }
      }
    }

    return Vendor(
      id: id,
      ownerUid: (data['ownerUid'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? 'Vendor',
      email: (data['email'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      type:
          (data['type'] as String?)?.trim() ??
          (data['service'] as String?)?.trim() ??
          '',
      price: parsePrice(),
      capacity: parseCapacity(),
      parkingCapacity: parseParking(),
      ac:
          data['ac'] == true ||
          data['isAC'] == true ||
          (data['ac'] is String &&
              (data['ac'] as String).toLowerCase() == 'yes'),
      occasions: occasions,
      moreDetails:
          (data['more'] as String?)?.trim() ??
          (data['moreDetails'] as String?)?.trim() ??
          '',
      imageUrl: (() {
        final inlineImage =
            (data['image'] as String?)?.trim() ??
            (data['imageUrl'] as String?)?.trim() ??
            '';
        if (inlineImage.isNotEmpty) {
          addGalleryItem(inlineImage);
          return inlineImage;
        }
        if (galleryImages.isNotEmpty) {
          return galleryImages.first;
        }
        return '';
      })(),
      galleryImages: List.unmodifiable(galleryImages),
      decorationPackages: List.unmodifiable(decorationPackages),
      menuItems: List.unmodifiable(menuItems),
      categoryId: primaryCategoryId,
      categoryIds: categoryIds.toSet().toList(),
      categoryName: primaryCategoryName,
      categoryNames: categoryNames.toSet().toList(),
      location:
          (data['location'] as String?)?.trim() ??
          (data['address'] as String?)?.trim() ??
          '',
      area: (data['area'] as String?)?.trim() ?? '',
      pincode: _normalizePincode(data['pincode']),
      experience: (data['experience'] as String?)?.trim() ?? '',
      languages: (data['languages'] as String?)?.trim() ?? '',
      education:
          (data['education'] as String?)?.trim() ??
          (data['educationCourse'] as String?)?.trim() ??
          '',
      state: (data['state'] as String?)?.trim() ?? '',
      proofUrl:
          (data['proofUrl'] as String?)?.trim() ??
          (data['proof'] as String?)?.trim() ??
          '',
      ratingAverage:
          data['ratingAverage'] is num ? (data['ratingAverage'] as num).toDouble() : 0,
      ratingCount: data['ratingCount'] is num ? (data['ratingCount'] as num).toInt() : 0,
      ratingTotal:
          data['ratingTotal'] is num ? (data['ratingTotal'] as num).toDouble() : 0,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
      subscriptionPaidAt: parseTimestamp(data['subscriptionPaidAt']),
      subscriptionExpiresAt: parseTimestamp(data['subscriptionExpiresAt']),
      subscriptionStatus:
          (data['subscriptionStatus'] as String?)?.trim().toLowerCase() ??
          'inactive',
      subscriptionAmountLastPaid: _toDouble(data['subscriptionAmountLastPaid']),
    );
  }

  Map<String, dynamic> toFirestorePayload(
    Category category,
    Map<String, dynamic> overrides,
  ) {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'service': type,
      'type': type,
      'category': category.name,
      'categoryName': category.name,
      'categoryNames': {category.name, ...categoryNames}.toList(),
      'categoryId': category.id,
      'categoryIds': {
        category.id,
        ...categoryIds,
      }.where((id) => id.isNotEmpty).toList(),
      'pricePerHour': price,
      'price': price,
      'seatingCapacity': capacity,
      'capacity': capacity,
      'parkingCapacity': parkingCapacity,
      'ac': ac,
      'occasionsFor': occasions.join(', '),
      'occasions': occasions,
      'more': moreDetails,
      'imageUrl': imageUrl,
      'image': imageUrl,
      'galleryImages': galleryImages,
      'images': galleryImages,
      'decorationPackages': decorationPackages
          .map((pkg) => pkg.toMap())
          .toList(),
      'menuItems': menuItems.map((item) => item.toMap()).toList(),
      'menu': menuItems.map((item) => item.toMap()).toList(),
      'location': location,
      'area': area,
      'pincode': pincode,
      'experience': experience,
      'languages': languages,
      'education': education,
      'state': state,
      'proofUrl': proofUrl,
      'ratingAverage': ratingAverage,
      'ratingCount': ratingCount,
      'ratingTotal': ratingTotal,
      'subscriptionPaidAt': subscriptionPaidAt != null
          ? Timestamp.fromDate(subscriptionPaidAt!)
          : null,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionAmountLastPaid': subscriptionAmountLastPaid,
      ...overrides,
    };
  }

  bool get isSubscriptionActive {
    if (subscriptionStatus != 'active') {
      return false;
    }
    if (subscriptionExpiresAt == null) {
      return false;
    }
    return subscriptionExpiresAt!.isAfter(DateTime.now());
  }

  bool matchesCategory(Category category) {
    if (category.id.isNotEmpty) {
      if (categoryId == category.id) return true;
      if (categoryIds.any((id) => id == category.id)) return true;
    }
    if (category.name.isNotEmpty) {
      final target = category.name.toLowerCase();
      if (categoryName.toLowerCase() == target) {
        return true;
      }
      if (categoryNames.any((name) => name.toLowerCase() == target)) {
        return true;
      }
    }
    return false;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static String _normalizePincode(dynamic value) {
    if (value == null) return '';
    if (value is num) return value.toInt().toString();
    return value.toString().trim();
  }
}

class VendorDecorationPackage {
  final String imageUrl;
  final double price;
  const VendorDecorationPackage({required this.imageUrl, required this.price});

  factory VendorDecorationPackage.fromJson(Map<String, dynamic> json) {
    return VendorDecorationPackage(
      imageUrl: (json['imageUrl'] as String?)?.trim() ?? '',
      price: Vendor._toDouble(json['price']),
    );
  }

  Map<String, dynamic> toMap() => {'imageUrl': imageUrl, 'price': price};

  static VendorDecorationPackage? fromMap(dynamic data) {
    if (data is VendorDecorationPackage) return data;
    if (data is Map<String, dynamic>) {
      final imageUrl = (data['imageUrl'] as String?)?.trim();
      if (imageUrl == null) return null;
      return VendorDecorationPackage.fromJson(data);
    }
    return null;
  }
}

class VendorMenuItem {
  final String name;
  final bool isVeg;

  const VendorMenuItem({required this.name, required this.isVeg});

  factory VendorMenuItem.fromJson(Map<String, dynamic> json) {
    return VendorMenuItem(
      name: (json['name'] as String?)?.trim() ?? '',
      isVeg: json['isVeg'] == true,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'isVeg': isVeg};

  static VendorMenuItem? fromMap(dynamic data) {
    if (data is VendorMenuItem) return data;
    if (data is Map<String, dynamic>) {
      final name = (data['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      return VendorMenuItem.fromJson(data);
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      return VendorMenuItem(name: trimmed, isVeg: true);
    }
    return null;
  }
}
