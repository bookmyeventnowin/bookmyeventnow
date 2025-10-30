import 'package:flutter/material.dart';

import 'models/category.dart';
import 'models/vendor.dart';

class VendorEditSheet extends StatefulWidget {
  final Vendor? vendor;
  final List<Category> categories;
  final void Function(Category category, Map<String, dynamic> data) onSubmit;
  final VoidCallback? onDelete;

  const VendorEditSheet({
    required this.vendor,
    required this.categories,
    required this.onSubmit,
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
  late final TextEditingController _imageController;
  late final TextEditingController _locationController;

  bool _ac = false;
  Category? _selectedCategory;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final vendor = widget.vendor;
    _nameController = TextEditingController(text: vendor?.name ?? '');
    _emailController = TextEditingController(text: vendor?.email ?? '');
    _phoneController = TextEditingController(text: vendor?.phone ?? '');
    _serviceController = TextEditingController(text: vendor?.type ?? '');
    _priceController = TextEditingController(text: vendor?.price == 0 ? '' : vendor!.price.toString());
    _seatingController = TextEditingController(text: vendor?.capacity == 0 ? '' : vendor!.capacity.toString());
    _parkingController =
        TextEditingController(text: vendor?.parkingCapacity == 0 ? '' : vendor!.parkingCapacity.toString());
    _occasionsController = TextEditingController(text: vendor?.occasions.join(', ') ?? '');
    _moreController = TextEditingController(text: vendor?.moreDetails ?? '');
    _imageController = TextEditingController(text: vendor?.imageUrl ?? '');
    _locationController = TextEditingController(text: vendor?.location ?? '');
    _ac = vendor?.ac ?? false;

    if (widget.categories.isNotEmpty) {
      _selectedCategory = _resolveInitialCategory(widget.categories, vendor);
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
    if (widget.categories != oldWidget.categories && widget.categories.isNotEmpty) {
      setState(() {
        _selectedCategory ??= _resolveInitialCategory(widget.categories, widget.vendor);
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
    _imageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.vendor != null;
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
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(_nameController, label: 'Name', validatorMessage: 'Please enter vendor name'),
              const SizedBox(height: 12),
              _buildTextField(_emailController, label: 'Email', keyboard: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField(_phoneController, label: 'Phone', keyboard: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField(_serviceController, label: 'Service / Offering'),
              const SizedBox(height: 12),
              if (widget.categories.isNotEmpty)
                DropdownButtonFormField<Category>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categories
                      .map((category) => DropdownMenuItem(value: category, child: Text(category.name)))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCategory = value),
                )
              else
                const Text(
                  'No categories available. Create categories first.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      _priceController,
                      label: 'Price per hour (₹)',
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
                      title: const Text('Air conditioning'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              _buildTextField(_imageController, label: 'Image URL'),
              const SizedBox(height: 12),
              _buildTextField(_locationController, label: 'Location / address'),
              const SizedBox(height: 24),
              Row(
                children: [
                  if (widget.onDelete != null)
                    TextButton.icon(
                      onPressed: _submitting ? null : widget.onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _submitting || _selectedCategory == null ? null : _submit,
                    child: _submitting
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
          : (value) => (value == null || value.trim().isEmpty) ? validatorMessage : null,
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

      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'type': _serviceController.text.trim(),
        'service': _serviceController.text.trim(),
        'pricePerHour': price,
        'price': price,
        'seatingCapacity': seating,
        'capacity': seating,
        'parkingCapacity': parking,
        'ac': _ac,
        'occasions': occasions,
        'occasionsFor': occasions.join(', '),
        'more': _moreController.text.trim(),
        'moreDetails': _moreController.text.trim(),
        'imageUrl': _imageController.text.trim(),
        'image': _imageController.text.trim(),
        'location': _locationController.text.trim(),
      };

      widget.onSubmit(_selectedCategory!, payload);
      if (mounted) Navigator.of(context).maybePop();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
