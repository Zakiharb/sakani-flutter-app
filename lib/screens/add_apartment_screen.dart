// D:\ttu_housing_app\lib\screens\add_apartment_screen.dart
import 'package:flutter/material.dart';
import 'package:ttu_housing_app/app_settings.dart';
import 'package:ttu_housing_app/models/models.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:ttu_housing_app/screens/map_picker_screen.dart';

class AddApartmentScreen extends StatefulWidget {
  final Apartment? initialApartment;
  const AddApartmentScreen({super.key, this.initialApartment});

  @override
  State<AddApartmentScreen> createState() => _AddApartmentScreenState();
}

class _AddApartmentScreenState extends State<AddApartmentScreen> {
  int _step = 1;
  bool _isSubmitting = false;
  late final VoidCallback _refresh;

  final _titleController = TextEditingController();
  final _titleArController = TextEditingController();

  final _priceController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bathroomsController = TextEditingController();

  final _descriptionController = TextEditingController();
  final _descriptionArController = TextEditingController();

  String? _coverKey;

  bool _furnished = false;
  bool _isPicking = false;

  final _addressController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  final List<String> _existingImages = [];
  final List<XFile> _newImages = [];

  static const int _maxImages = 20;

  bool _isNetworkImage(String path) => path.startsWith('http');

  int get _totalImages => _existingImages.length + _newImages.length;
  bool get _canAddMore => _totalImages < _maxImages;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _openMapPicker() async {
    final initLat = double.tryParse(_latController.text.trim()) ?? 30.8410169;
    final initLng = double.tryParse(_lngController.text.trim()) ?? 35.6429248;

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(initialLat: initLat, initialLng: initLng),
      ),
    );

    if (result == null) return;

    setState(() {
      final lat = (result['lat'] as num).toDouble();
      final lng = (result['lng'] as num).toDouble();
      _latController.text = lat.toStringAsFixed(6);
      _lngController.text = lng.toStringAsFixed(6);

      final addr = (result['address'] as String?)?.trim();
      _addressController.text = (addr != null && addr.isNotEmpty)
          ? addr
          : '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    });
  }

  Future<void> _pickFromGallery() async {
    if (_isPicking) return;
    if (!_canAddMore) {
      _snack(
        tr(
          context,
          'You reached the maximum number of photos.',
          'وصلت للحد الأقصى من الصور.',
        ),
      );
      return;
    }

    setState(() => _isPicking = true);

    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked.isEmpty) return;

      final remaining = _maxImages - _totalImages;
      final toAdd = picked.length > remaining
          ? picked.take(remaining).toList()
          : picked;

      setState(() {
        _newImages.addAll(toAdd);

        _coverKey ??= toAdd.first.path;
      });

      if (_coverKey == null && _newImages.isNotEmpty) {
        _coverKey = _newImages.first.path;
      }

      if (picked.length > remaining) {
        _snack(
          tr(
            context,
            'Some photos were skipped (max $_maxImages).',
            'تم تجاهل بعض الصور (الحد الأقصى $_maxImages).',
          ),
        );
      }
    } catch (e) {
      _snack('Image picker error: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickFromCamera() async {
    if (_isPicking) return;

    if (!_canAddMore) {
      _snack(
        tr(
          context,
          'You reached the maximum number of photos.',
          'وصلت للحد الأقصى من الصور.',
        ),
      );
      return;
    }

    setState(() => _isPicking = true);

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;

      setState(() {
        _newImages.add(picked);

        _coverKey ??= picked.path;
      });
    } catch (e) {
      _snack('Camera error: $e');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _removeExistingAt(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _removeNewAt(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _next() async {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      await _submit();
    }
  }

  void _back() {
    if (_step > 1) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    // ✅ تأكيد إلزامية الموقع (حتى لو زر Next صار enabled بالغلط)
    final address = _addressController.text.trim();
    final latText = _latController.text.trim();
    final lngText = _lngController.text.trim();

    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);

    if (address.isEmpty || lat == null || lng == null) {
      _snack(
        tr(
          context,
          'Location is required (address + valid lat/lng).',
          'الموقع مطلوب (العنوان + خط عرض/طول صحيح).',
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final desc = _descriptionController.text.trim();

    try {
      Navigator.pop<Map<String, dynamic>>(context, {
        'title': title,
        'titleAr': title, 'price': _priceController.text.trim(),
        'rooms': _roomsController.text.trim(),
        'bathrooms': _bathroomsController.text.trim(),
        'description': desc,
        'descriptionAr': desc,
        'furnished': _furnished,
        'address': address,
        'lat': lat.toString(), // ✅ نرجّعها كنص (وبرا بتحولها double)
        'lng': lng.toString(),
        'coverKey': _coverKey,
        'existingImages': List<String>.from(_existingImages),
        'newImagePaths': _newImages.map((x) => x.path).toList(),
      });
    } catch (e) {
      _snack('Submit error: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool get _canNext {
    if (_step == 1) {
      final descLen = _descriptionController.text.trim().length;

      return _titleController.text.trim().isNotEmpty &&
          _priceController.text.trim().isNotEmpty &&
          _roomsController.text.trim().isNotEmpty &&
          _bathroomsController.text.trim().isNotEmpty &&
          descLen >= 15; // ✅ الوصف إجباري وحد أدنى
    } else if (_step == 2) {
      return _existingImages.isNotEmpty || _newImages.isNotEmpty;
    } else if (_step == 3) {
      final lat = double.tryParse(_latController.text.trim());
      final lng = double.tryParse(_lngController.text.trim());
      return _addressController.text.trim().isNotEmpty &&
          lat != null &&
          lng != null;
    }

    return true;
  }

  @override
  void initState() {
    super.initState();
    _refresh = () {
      if (mounted) setState(() {});
    };

    _titleController.addListener(_refresh);
    _priceController.addListener(_refresh);
    _roomsController.addListener(_refresh);
    _bathroomsController.addListener(_refresh);
    _addressController.addListener(_refresh);
    _latController.addListener(_refresh);
    _lngController.addListener(_refresh);
    _descriptionController.addListener(_refresh);

    final apt = widget.initialApartment;
    if (apt != null) {
      _titleController.text = apt.title; // بدون tr داخل initState
      _priceController.text = apt.price.toStringAsFixed(0);
      _roomsController.text = apt.rooms.toString();
      _bathroomsController.text = apt.bathrooms.toString();

      _descriptionController.text = apt.description; // بدون tr

      _furnished = apt.furnished;
      _existingImages.addAll(apt.images);
      if (apt.images.isNotEmpty) {
        _coverKey = apt.coverImageUrl ?? apt.images.first;
      }

      _addressController.text = apt.address;
      _latController.text = apt.lat?.toString() ?? '';
      _lngController.text = apt.lng?.toString() ?? '';
    }
  }

  bool _didLocaleFill = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didLocaleFill) return;

    final apt = widget.initialApartment;
    if (apt != null) {
      _titleController.text = tr(context, apt.title, apt.titleAr ?? apt.title);
      _descriptionController.text = tr(
        context,
        apt.description,
        apt.descriptionAr ?? apt.description,
      );
    }

    _didLocaleFill = true;
  }

  @override
  void dispose() {
    _titleController.removeListener(_refresh);
    _priceController.removeListener(_refresh);
    _roomsController.removeListener(_refresh);
    _bathroomsController.removeListener(_refresh);
    _addressController.removeListener(_refresh);
    _latController.removeListener(_refresh);
    _lngController.removeListener(_refresh);
    _titleController.dispose();
    _titleArController.dispose();
    _priceController.dispose();
    _roomsController.dispose();
    _bathroomsController.dispose();
    _descriptionController.dispose();
    _descriptionArController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _descriptionController.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialApartment != null;
    final scheme = Theme.of(context).colorScheme;
    final steps = [1, 2, 3];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? tr(context, 'Edit Apartment', 'تعديل الشقة')
              : tr(context, 'Add New Apartment', 'إضافة شقة جديدة'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
      ),
      backgroundColor: scheme.surface,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              children: steps.map((s) {
                final isActive = _step >= s;
                return Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isActive
                            ? scheme.primary
                            : scheme.outlineVariant,
                        child: Text(
                          '$s',
                          style: TextStyle(
                            color: isActive ? Colors.white : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (s != steps.last)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: _step > s
                                ? scheme.primary
                                : scheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildStep(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: ElevatedButton(
              onPressed: (_canNext && !_isSubmitting)
                  ? () async => await _next()
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: _step == 3
                    ? const Color(0xFF22C55E)
                    : scheme.primary,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _step == 3
                    ? (isEdit
                          ? tr(context, 'Save changes', 'حفظ التعديلات')
                          : tr(
                              context,
                              'Submit for Approval',
                              'إرسال للمراجعة',
                            ))
                    : tr(context, 'Next', 'التالي'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    final scheme = Theme.of(context).colorScheme;

    switch (_step) {
      case 1:
        return ListView(
          children: [
            Text(
              tr(context, 'Basic Information', 'المعلومات الأساسية'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),

            Text(tr(context, 'Apartment Title', 'عنوان الشقة')),
            const SizedBox(height: 4),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: tr(
                  context,
                  'e.g., Modern 2BR Apartment',
                  'مثال: شقة غرفتين حديثة',
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(tr(context, 'Monthly Rent (JOD)', 'الإيجار الشهري (دينار)')),
            const SizedBox(height: 4),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '850',
              ),
            ),
            const SizedBox(height: 12),

            Text(tr(context, 'Number of Rooms', 'عدد الغرف')),
            const SizedBox(height: 4),
            TextField(
              controller: _roomsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '2',
              ),
            ),
            const SizedBox(height: 12),

            Text(tr(context, 'Number of Bathrooms', 'عدد الحمامات')),
            const SizedBox(height: 4),
            TextField(
              controller: _bathroomsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '1',
              ),
            ),
            const SizedBox(height: 12),

            // ✅ حذفنا حقل Distance من هنا (لأنه محسوب تلقائياً)
            Text(tr(context, 'Description ', 'الوصف *')),
            const SizedBox(height: 4),

            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 400, // ✅ Counter تلقائي
              onChanged: (_) => _refresh(),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: tr(
                  context,
                  'Describe your apartment...',
                  'اكتب وصف الشقة...',
                ),
                helperText: tr(
                  context,
                  'Minimum 15 characters',
                  'على الأقل 15 حرف',
                ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Checkbox(
                  value: _furnished,
                  onChanged: (v) => setState(() => _furnished = v ?? false),
                ),
                Text(tr(context, 'Furnished', 'مفروشة')),
              ],
            ),
          ],
        );

      case 2:
        return ListView(
          children: [
            Text(
              tr(context, 'Upload Photos', 'أضف صور'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              tr(
                context,
                'Add clear photos of the apartment. ($_totalImages/$_maxImages)',
                'أضف صور واضحة للشقة. ($_totalImages/$_maxImages)',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _canAddMore ? _pickFromGallery : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(tr(context, 'Gallery', 'المعرض')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!_isPicking && _canAddMore)
                        ? _pickFromCamera
                        : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(tr(context, 'Camera', 'الكاميرا')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_totalImages == 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tr(
                          context,
                          'No photos added yet. You must add at least one photo to continue.',
                          'لم يتم إضافة صور بعد. يجب إضافة صورة واحدة على الأقل للمتابعة.',
                        ),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),

            if (_totalImages > 0) ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _totalImages,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final bool isExisting = index < _existingImages.length;

                  Widget img;
                  VoidCallback onRemove;

                  if (isExisting) {
                    final path = _existingImages[index];
                    img = _isNetworkImage(path)
                        ? Image.network(path, fit: BoxFit.cover)
                        : Image.asset(path, fit: BoxFit.cover);

                    onRemove = () => _removeExistingAt(index);
                  } else {
                    final newIndex = index - _existingImages.length;
                    final file = File(_newImages[newIndex].path);

                    img = Image.file(file, fit: BoxFit.cover);
                    onRemove = () => _removeNewAt(newIndex);
                  }

                  final String key = isExisting
                      ? _existingImages[index]
                      : _newImages[index - _existingImages.length].path;

                  final bool isCover = (_coverKey == key);

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: img,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: scheme.error,
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),

                      // ✅ زر تحديد صورة الغلاف
                      Positioned(
                        top: 4,
                        left: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _coverKey = key),
                          child: CircleAvatar(
                            radius: 14,
                            backgroundColor: Colors.white.withOpacity(0.9),
                            child: Icon(
                              isCover ? Icons.star : Icons.star_border,
                              size: 18,
                              color: isCover
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),

                      if (isCover)
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tr(context, 'Cover', 'الغلاف'),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        );

      case 3:
      default:
        return ListView(
          children: [
            Text(
              tr(context, 'Location', 'الموقع'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                context,
                'Location is required: address + valid lat/lng.',
                'الموقع مطلوب: عنوان + خط عرض/طول صحيح.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            Text(tr(context, 'Full Address', 'العنوان الكامل')),
            const SizedBox(height: 4),
            TextField(
              controller: _addressController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: tr(
                  context,
                  '123 University St, Tafila',
                  'مثال: شارع الجامعة, الطفيلة',
                ),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: tr(context, 'Lat', 'خط العرض'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: tr(context, 'Lng', 'خط الطول'),
                      isDense: true,
                    ),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _openMapPicker,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                tr(context, 'Pick location on map', 'تحديد الموقع على الخريطة'),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),

            Text(
              tr(
                context,
                'Distance to TTU will be calculated automatically.',
                'سيتم حساب المسافة إلى الجامعة تلقائيًا.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),

            const SizedBox(height: 12),
          ],
        );
    }
  }
}
