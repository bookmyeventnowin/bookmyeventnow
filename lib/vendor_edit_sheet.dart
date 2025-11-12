import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'models/category.dart';
import 'models/vendor.dart';

class _DecorationPackageEntry {
  _DecorationPackageEntry({required this.imageUrl, double price = 0})
    : priceController = TextEditingController(
        text: price == 0
            ? ''
            : price % 1 == 0
            ? price.toStringAsFixed(0)
            : price.toStringAsFixed(2),
      );

  String imageUrl;
  final TextEditingController priceController;

  double get price => double.tryParse(priceController.text.trim()) ?? 0;

  void dispose() => priceController.dispose();
}

class _MenuItemEntry {
  _MenuItemEntry({String name = '', this.isVeg = true})
    : nameController = TextEditingController(text: name);

  final TextEditingController nameController;
  bool isVeg;

  String get name => nameController.text.trim();

  void dispose() => nameController.dispose();
}

class VendorEditSheet extends StatefulWidget {
  final Vendor? vendor;
  final List<Category> categories;
  final void Function(Category category, Map<String, dynamic> data) onSubmit;
  final VoidCallback? onDelete;
  final String ownerUid;

  const VendorEditSheet({
    required this.vendor,
    required this.categories,
    required this.onSubmit,
    required this.ownerUid,
    this.onDelete,
    super.key,
  });

  @override
  State<VendorEditSheet> createState() => _VendorEditSheetState();
}

class _VendorEditSheetState extends State<VendorEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _serviceController;
  late final TextEditingController _priceController;
  late final TextEditingController _seatingController;
  late final TextEditingController _parkingController;
  late final TextEditingController _occasionsController;
  late final TextEditingController _moreController;
  late final TextEditingController _locationController;
  late final TextEditingController _areaController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _experienceController;
  late final TextEditingController _languagesController;
  late final TextEditingController _educationController;
  late final TextEditingController _stateController;

  static const int _maxGalleryImages = 6;
  static const List<String> _placeholderImages = [
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1528605248644-14dd04022da1?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1556740749-887f6717d7e4?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1499951360447-b19be8fe80f5?auto=format&fit=crop&w=900&q=80',
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',
  ];
  final List<String> _imageUrls = [];
  final List<_DecorationPackageEntry> _decorationPackages = [];
  final List<_MenuItemEntry> _menuItems = [];
  String _proofUrl = '';

  bool _ac = false;
  Category? _selectedCategory;
  bool _submitting = false;
  bool _uploadingImage = false;
  int _placeholderIndex = 0;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _emailController = TextEditingController(text: vendor?.email ?? '');
    _phoneController = TextEditingController(text: vendor?.phone ?? '');
    _serviceController = TextEditingController(text: vendor?.type ?? '');
    String formatNumber(num? value) {
      if (value == null || value == 0) return '';
      if (value is double && value % 1 == 0) return value.toInt().toString();
      return value.toString();
    }

    _priceController = TextEditingController(text: formatNumber(vendor?.price));
    _seatingController = TextEditingController(
      text: formatNumber(vendor?.capacity),
    );
    _parkingController = TextEditingController(
      text: formatNumber(vendor?.parkingCapacity),
    );
    _occasionsController = TextEditingController(
      text: vendor?.occasions.join(', ') ?? '',
    );
    _moreController = TextEditingController(text: vendor?.moreDetails ?? '');
    _locationController = TextEditingController(text: vendor?.location ?? '');
    _areaController = TextEditingController(text: vendor?.area ?? '');
    _pincodeController = TextEditingController(text: vendor?.pincode ?? '');
    _experienceController = TextEditingController(
      text: vendor?.experience ?? '',
    );
    _languagesController = TextEditingController(text: vendor?.languages ?? '');
    _educationController = TextEditingController(text: vendor?.education ?? '');
    _stateController = TextEditingController(text: vendor?.state ?? '');
    _proofUrl = vendor?.proofUrl ?? '';
    _ac = vendor?.ac ?? false;

    if (vendor != null) {
      if (vendor.galleryImages.isNotEmpty) {
        _imageUrls.addAll(vendor.galleryImages);
      } else if (vendor.imageUrl.isNotEmpty) {
        _imageUrls.add(vendor.imageUrl);
      }
    }

    if (widget.categories.isNotEmpty) {
      _selectedCategory = _resolveInitialCategory(widget.categories, vendor);
    }

    if (vendor != null && vendor.decorationPackages.isNotEmpty) {
      for (final pkg in vendor.decorationPackages) {
        _decorationPackages.add(
          _DecorationPackageEntry(imageUrl: pkg.imageUrl, price: pkg.price),
        );
      }
    }

    if (vendor != null && vendor.menuItems.isNotEmpty) {
      for (final item in vendor.menuItems) {
        _menuItems.add(_MenuItemEntry(name: item.name, isVeg: item.isVeg));
      }
    }
  }

  Category? _resolveInitialCategory(List<Category> categories, Vendor? vendor) {
    if (categories.isEmpty) return null;
    if (vendor == null) return categories.first;
    if (vendor.categoryId.isNotEmpty) {
      for (final category in categories) {
        if (category.id == vendor.categoryId) return category;
      }
    }
    if (vendor.categoryName.isNotEmpty) {
      final target = vendor.categoryName.toLowerCase();
      for (final category in categories) {
        if (category.name.toLowerCase() == target) return category;
      }
    }
    return categories.first;
  }

  @override
  void didUpdateWidget(covariant VendorEditSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categories != oldWidget.categories &&
        widget.categories.isNotEmpty) {
      setState(() {
        _selectedCategory ??= _resolveInitialCategory(
          widget.categories,
          widget.vendor,
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _serviceController.dispose();
    _priceController.dispose();
    _seatingController.dispose();
    _parkingController.dispose();
    _occasionsController.dispose();
    _moreController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _pincodeController.dispose();
    _experienceController.dispose();
    _languagesController.dispose();
    _educationController.dispose();
    _stateController.dispose();
    for (final entry in _decorationPackages) {
      entry.dispose();
    }
    for (final item in _menuItems) {
      item.dispose();
    }
    super.dispose();
  }

  bool get _canAddMoreImages =>
      !_uploadingImage && _imageUrls.length < _maxGalleryImages;

  bool get _isDecoration {
    final name = _selectedCategory?.name.toLowerCase() ?? '';
    return name.contains('decor');
  }

  bool get _isCatering {
    final name = _selectedCategory?.name.toLowerCase() ?? '';
    if (name.contains('cater')) return true;
    final service = _serviceController.text.toLowerCase();
    return service.contains('cater');
  }

  bool get _isHumanResource {
    final name = _selectedCategory?.name.toLowerCase() ?? '';
    if (name.contains('human')) return true;
    final service = _serviceController.text.toLowerCase();
    return service.contains('human');
  }

  Future<void> _pickAndUploadImages() async {
    if (!_canAddMoreImages) return;
    final remaining = _maxGalleryImages - _imageUrls.length;
    final picker = ImagePicker();
    var selections = await picker.pickMultiImage(imageQuality: 85);
    if (selections.isEmpty) {
      final single = await picker.pickImage(
        imageQuality: 85,
        source: ImageSource.gallery,
      );
      if (single != null) {
        selections = [single];
      }
    }
    if (selections.isEmpty) return;

    final allowedSelections = selections.take(remaining).toList();

    setState(() => _uploadingImage = true);
    try {
      for (final selection in allowedSelections) {
        final url = await _uploadImageForSelection(selection);
        if (!mounted) return;
        if (url != null) {
          setState(() => _imageUrls.add(url));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Future<void> _removeImage(String url) async {
    setState(() => _imageUrls.remove(url));
    try {
      final storage = FirebaseStorage.instance;
      await storage.refFromURL(url).delete();
    } catch (_) {
      // ignore storage cleanup errors
    }
  }

  Future<void> _addDecorationPackage() async {
    if (_uploadingImage) return;
    final picker = ImagePicker();
    final selection = await picker.pickImage(
      imageQuality: 85,
      source: ImageSource.gallery,
    );
    if (selection == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _uploadImageForSelection(selection);
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _decorationPackages.add(_DecorationPackageEntry(imageUrl: url));
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _replaceDecorationPackageImage(int index) async {
    if (_uploadingImage) return;
    if (index < 0 || index >= _decorationPackages.length) return;
    final picker = ImagePicker();
    final selection = await picker.pickImage(
      imageQuality: 85,
      source: ImageSource.gallery,
    );
    if (selection == null) return;

    setState(() => _uploadingImage = true);
    try {
      final url = await _uploadImageForSelection(selection);
      if (!mounted) return;
      if (url != null) {
        setState(() => _decorationPackages[index].imageUrl = url);
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  void _addMenuItem() {
    setState(() {
      _menuItems.add(_MenuItemEntry());
    });
  }

  void _removeMenuItem(int index) {
    if (index < 0 || index >= _menuItems.length) return;
    final entry = _menuItems[index];
    entry.dispose();
    setState(() {
      _menuItems.removeAt(index);
    });
  }

  Future<void> _uploadProofDocument() async {
    if (_uploadingImage) return;
    final picker = ImagePicker();
    final selection = await picker.pickImage(
      imageQuality: 85,
      source: ImageSource.gallery,
    );
    if (selection == null) return;
    setState(() => _uploadingImage = true);
    try {
      final url = await _uploadImageForSelection(selection);
      if (!mounted) return;
      if (url != null) {
        setState(() => _proofUrl = url);
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  bool _isStorageUnavailable(FirebaseException error) {
    final message = error.message ?? '';
    return message.contains('Not Found') ||
        error.code == 'retry-limit-exceeded' ||
        error.code == 'unknown';
  }

  String _nextPlaceholderImage() {
    final url =
        _placeholderImages[_placeholderIndex % _placeholderImages.length];
    _placeholderIndex++;
    return url;
  }

  Future<String?> _detectMimeType(XFile selection, File file) async {
    if (selection.mimeType != null && selection.mimeType!.isNotEmpty) {
      return selection.mimeType;
    }
    try {
      final header = await file.openRead(0, 32).fold<List<int>>(<int>[], (
        previous,
        element,
      ) {
        final remaining = 32 - previous.length;
        if (remaining <= 0) return previous;
        if (element.length > remaining) {
          return previous..addAll(element.take(remaining));
        }
        return previous..addAll(element);
      });
      if (header.isEmpty) return null;
      return lookupMimeType(selection.name, headerBytes: header);
    } catch (_) {
      return null;
    }
  }

  String _deriveExtension(String fileName, String mimeType) {
    final dot = fileName.lastIndexOf('.');
    if (dot != -1 && dot < fileName.length - 1) {
      return fileName.substring(dot);
    }
    if (mimeType.contains('/')) {
      final subtype = mimeType.split('/').last;
      return '.${subtype.toLowerCase()}';
    }
    return '.jpg';
  }

  String _sanitizeFileName(String original) {
    final trimmed = original.trim();
    if (trimmed.isEmpty) return 'image';
    final withoutExt = trimmed.replaceAll(RegExp(r'\.[^\.]+$'), '');
    final sanitized = withoutExt.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    if (sanitized.isEmpty) return 'image';
    return sanitized.length > 40 ? sanitized.substring(0, 40) : sanitized;
  }

  Future<String?> _uploadImageForSelection(XFile selection) async {
    final file = File(selection.path);
    if (!await file.exists()) {
      _showSnack('Unable to access selected file ${selection.name}');
      return null;
    }
    final storage = FirebaseStorage.instance;
    try {
      final mimeType = await _detectMimeType(selection, file) ?? 'image/jpeg';
      final extension = _deriveExtension(selection.name, mimeType);
      final sanitizedBase = _sanitizeFileName(selection.name);
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      final objectName =
          '${timestamp}_${_placeholderIndex}_$sanitizedBase$extension';
      final ref = storage
          .ref()
          .child('vendor_images')
          .child(widget.ownerUid)
          .child(objectName);
      final metadata = SettableMetadata(contentType: mimeType);
      await ref.putFile(file, metadata);
      return await ref.getDownloadURL();
    } on FirebaseException catch (error) {
      if (_isStorageUnavailable(error)) {
        _showSnack(
          'Cloud Storage is disabled for this project. Added a sample image instead.',
        );
        return _nextPlaceholderImage();
      }
      _showSnack('Unable to upload image: ${error.message ?? error.code}');
    } catch (error) {
      _showSnack('Unable to upload image: $error');
    }
    return null;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildDecorationPackagesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Decoration packages',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_decorationPackages.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.local_florist_outlined,
                  size: 40,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add images for your decoration themes. Each image can have its own price.',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < _decorationPackages.length; i++)
                _buildDecorationPackageCard(_decorationPackages[i], i),
            ],
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addDecorationPackage,
            icon: _uploadingImage
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Add package'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Packages can include sample images while storage is disabled.',
          style: TextStyle(color: Colors.black45, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMenuItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Menu items',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${_menuItems.length} added',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_menuItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: const Text(
              'Add your signature dishes to help customers understand your catering menu.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < _menuItems.length; i++)
                _buildMenuItemCard(_menuItems[i], i),
            ],
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addMenuItem,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(_MenuItemEntry entry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: entry.nameController,
                  decoration: const InputDecoration(
                    labelText: 'Item name',
                    hintText: 'e.g. Paneer butter masala',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Remove item',
                onPressed: () => _removeMenuItem(index),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Switch(
                value: entry.isVeg,
                onChanged: (value) => setState(() => entry.isVeg = value),
              ),
              const SizedBox(width: 6),
              Text(
                entry.isVeg ? 'Vegetarian' : 'Non-vegetarian',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHumanResourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _experienceController,
                label: 'Experience (years)',
                keyboard: TextInputType.text,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                _priceController,
                label: 'Hourly charge (Rs)',
                keyboard: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _languagesController,
          label: 'Languages',
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _educationController,
          label: 'Education / course',
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          _locationController,
          label: 'Address',
          minLines: 1,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(_areaController, label: 'Area / locality'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                _pincodeController,
                label: 'Pincode',
                keyboard: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(_stateController, label: 'State'),
        const SizedBox(height: 16),
        _buildProofUploadCard(),
      ],
    );
  }

  Widget _buildProofUploadCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload proof (ID / certificate)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (_proofUrl.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Proof uploaded',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: _uploadingImage
                        ? null
                        : () => setState(() => _proofUrl = ''),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove proof',
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploadingImage ? null : _uploadProofDocument,
              icon: _uploadingImage
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_proofUrl.isEmpty ? 'Attach proof' : 'Replace proof'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Upload a clear photo or PDF of your ID / certificate.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorationPackageCard(_DecorationPackageEntry entry, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _replaceDecorationPackageImage(index),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    entry.imageUrl,
                    height: 90,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 90,
                      width: 120,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: const Text(
                    'Change',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextFormField(
              controller: entry.priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Price (Rs)'),
            ),
          ),
          IconButton(
            onPressed: _uploadingImage
                ? null
                : () {
                    setState(() {
                      entry.dispose();
                      _decorationPackages.removeAt(index);
                    });
                  },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildGallerySection() {
    final remaining = _maxGalleryImages - _imageUrls.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Gallery images',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${_imageUrls.length}/$_maxGalleryImages added',
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (_imageUrls.isEmpty)
                Column(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 38,
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No images yet. Upload up to 6 images. If storage is disabled, sample images will be added.',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _imageUrls.map(_buildGalleryThumbnail).toList(),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _canAddMoreImages ? _pickAndUploadImages : null,
                  icon: _uploadingImage
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload_outlined),
                  label: Text(
                    _canAddMoreImages
                        ? 'Upload images'
                        : 'Maximum of $_maxGalleryImages reached',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  remaining > 0
                      ? 'You can add $remaining more image${remaining == 1 ? '' : 's'}.'
                      : 'Remove one to upload another image.',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryThumbnail(String url) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            height: 120,
            width: 160,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              width: 160,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Text('Image unavailable'),
            ),
          ),
        ),
        Positioned(
          top: -10,
          right: -10,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(4),
            ),
            iconSize: 18,
            onPressed: _uploadingImage ? null : () => _removeImage(url),
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vendor != null;
    final isDecoration = _isDecoration;
    final isCatering = _isCatering;
    final isHumanResource = _isHumanResource;
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit vendor details' : 'Create vendor profile',
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
              _buildTextField(
                _nameController,
                label: 'Name',
                validatorMessage: 'Please enter vendor name',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _emailController,
                label: 'Email',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _phoneController,
                label: 'Phone',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(_serviceController, label: 'Service / Offering'),
              const SizedBox(height: 12),
              if (widget.categories.isNotEmpty)
                DropdownButtonFormField<Category>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedCategory = value);
                  },
                )
              else
                const Text(
                  'No categories available. Create categories first.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 12),
              if (isHumanResource) ...[
                _buildHumanResourceSection(),
                const SizedBox(height: 12),
              ] else if (isDecoration) ...[
                _buildDecorationPackagesSection(),
                const SizedBox(height: 12),
              ] else if (isCatering) ...[
                _buildMenuItemsSection(),
                const SizedBox(height: 12),
                _buildGallerySection(),
                const SizedBox(height: 12),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _priceController,
                        label: 'Price per hour (Rs)',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        _seatingController,
                        label: 'Seating capacity',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _parkingController,
                        label: 'Parking capacity',
                        keyboard: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SwitchListTile(
                        value: _ac,
                        onChanged: (value) => setState(() => _ac = value),
                        title: const Text('AC'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildGallerySection(),
                const SizedBox(height: 12),
              ],
              if (!isHumanResource) ...[
                _buildTextField(
                  _occasionsController,
                  label: 'Occasions (comma separated)',
                  minLines: 1,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _moreController,
                  label: 'More details / highlights',
                  minLines: 1,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        _areaController,
                        label: 'Area / locality',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        _pincodeController,
                        label: 'Pincode',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  _locationController,
                  label: 'Location / address',
                ),
                const SizedBox(height: 24),
              ] else
                const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      onPressed: _submitting ? null : widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _submitting || _selectedCategory == null
                        ? null
                        : _submit,
                    child: _submitting
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isEditing ? 'Save changes' : 'Create vendor'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    required String label,
    TextInputType keyboard = TextInputType.text,
    String? validatorMessage,
    int? minLines,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      minLines: minLines,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(labelText: label),
      validator: validatorMessage == null
          ? null
          : (value) => (value == null || value.trim().isEmpty)
                ? validatorMessage
                : null,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) return;
    setState(() => _submitting = true);

    try {
      final occasions = _occasionsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final seating = int.tryParse(_seatingController.text.trim()) ?? 0;
      final parking = int.tryParse(_parkingController.text.trim()) ?? 0;

      final isDecoration = _isDecoration;
      final isCatering = _isCatering;
      final isHumanResource = _isHumanResource;
      final decorationPackages = isDecoration
          ? _decorationPackages
                .where((entry) => entry.imageUrl.isNotEmpty)
                .map(
                  (entry) => {'imageUrl': entry.imageUrl, 'price': entry.price},
                )
                .toList()
          : const <Map<String, dynamic>>[];
      final packageImages = decorationPackages
          .map((pkg) => pkg['imageUrl'] as String)
          .where((url) => url.isNotEmpty)
          .toList();
      final galleryImages = isDecoration
          ? packageImages
          : List<String>.from(_imageUrls);
      final menuItems = isCatering
          ? _menuItems
                .where((entry) => entry.name.isNotEmpty)
                .map((entry) => {'name': entry.name, 'isVeg': entry.isVeg})
                .toList()
          : const <Map<String, dynamic>>[];
      final primaryImage = galleryImages.isNotEmpty ? galleryImages.first : '';
      final suppressPricing = isDecoration || isCatering;
      final suppressVenueMetrics =
          isDecoration || isCatering || isHumanResource;
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'type': _serviceController.text.trim(),
        'service': _serviceController.text.trim(),
        'pricePerHour': suppressPricing ? 0 : price,
        'price': suppressPricing ? 0 : price,
        'seatingCapacity': suppressVenueMetrics ? 0 : seating,
        'capacity': suppressVenueMetrics ? 0 : seating,
        'parkingCapacity': suppressVenueMetrics ? 0 : parking,
        'ac': suppressVenueMetrics ? false : _ac,
        'occasions': isHumanResource ? <String>[] : occasions,
        'occasionsFor': isHumanResource ? '' : occasions.join(', '),
        'more': isHumanResource ? '' : _moreController.text.trim(),
        'moreDetails': isHumanResource ? '' : _moreController.text.trim(),
        'imageUrl': primaryImage,
        'image': primaryImage,
        'galleryImages': galleryImages,
        'images': galleryImages,
        'decorationPackages': decorationPackages,
        'menuItems': menuItems,
        'menu': menuItems,
        'location': _locationController.text.trim(),
        'area': _areaController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'experience': isHumanResource ? _experienceController.text.trim() : '',
        'languages': isHumanResource ? _languagesController.text.trim() : '',
        'education': isHumanResource ? _educationController.text.trim() : '',
        'state': isHumanResource ? _stateController.text.trim() : '',
        'proofUrl': isHumanResource ? _proofUrl : '',
      };

      widget.onSubmit(_selectedCategory!, payload);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
