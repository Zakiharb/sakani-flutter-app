// D:\ttu_housing_app\lib\screens\filters_screen.dart

import 'package:flutter/material.dart';
import 'package:ttu_housing_app/app_settings.dart';

class FiltersScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> filters) onApply;
  final Map<String, dynamic> initialFilters;

  /// حدود السلايدر (اختياري) — لو ما انبعتت بنستخدم قيم افتراضية
  final double priceMinBound;
  final double priceMaxBound;
  final double distanceMaxBound;

  /// يرجّع عدد النتائج المتوقعة (Level 2)
  final int Function(Map<String, dynamic> draftFilters)? previewCount;

  const FiltersScreen({
    super.key,
    required this.onApply,
    this.initialFilters = const {},
    this.priceMinBound = 0,
    this.priceMaxBound = 500,
    this.distanceMaxBound = 10,
    this.previewCount,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late double _priceMinBound;
  late double _priceMaxBound;
  late double _distanceMaxBound;

  late RangeValues _priceRange;
  late double _maxDistance;

  int? _roomsMin; // >=
  int? _bathroomsMin; // >=
  bool _furnishedOnly = false;

  double _asDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? double.nan;
    }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  bool _asBool(dynamic v, {bool def = false}) {
    if (v is bool) return v;
    if (v == null) return def;
    final s = v.toString().toLowerCase().trim();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
    return def;
  }

  void _initBounds() {
    // تأمين الحدود بحيث ما يصير min==max
    _priceMinBound = widget.priceMinBound;
    _priceMaxBound = widget.priceMaxBound;
    if (_priceMaxBound <= _priceMinBound) {
      _priceMaxBound = _priceMinBound + 1;
    }

    _distanceMaxBound = widget.distanceMaxBound;
    if (_distanceMaxBound <= 0) _distanceMaxBound = 10;
  }

  void _loadInitialFilters() {
    final f = widget.initialFilters;

    final minP = _asDouble(f['minPrice']);
    final maxP = _asDouble(f['maxPrice']);
    final maxD = _asDouble(f['maxDistance']);

    // السعر: إذا ما في قيم -> نعتبره Any (full range)
    final start = minP.isNaN ? _priceMinBound : minP.clamp(_priceMinBound, _priceMaxBound);
    final end = maxP.isNaN ? _priceMaxBound : maxP.clamp(_priceMinBound, _priceMaxBound);
    _priceRange = RangeValues(
      start <= end ? start : end,
      start <= end ? end : start,
    );

    // المسافة: إذا ما في -> Any (max bound)
    _maxDistance = maxD.isNaN ? _distanceMaxBound : maxD.clamp(0.0, _distanceMaxBound);

    _roomsMin = _asInt(f['rooms']); // رح نخليها >=
    _bathroomsMin = _asInt(f['bathrooms']); // >=
    _furnishedOnly = _asBool(f['furnishedOnly'], def: false);
  }

  Map<String, dynamic> _draftFilters() {
    // نعتبر الفلتر "غير مفعّل" إذا رجع للوضع الافتراضي
    final isPriceDefault =
        (_priceRange.start - _priceMinBound).abs() < 0.0001 &&
        (_priceRange.end - _priceMaxBound).abs() < 0.0001;

    final isDistanceDefault = (_maxDistance - _distanceMaxBound).abs() < 0.0001;

    return {
      'minPrice': isPriceDefault ? null : _priceRange.start,
      'maxPrice': isPriceDefault ? null : _priceRange.end,
      'maxDistance': isDistanceDefault ? null : _maxDistance,
      'rooms': _roomsMin, // >=
      'bathrooms': _bathroomsMin, // >=
      'furnishedOnly': _furnishedOnly,
    };
  }

  bool _hasAnyFilter(Map<String, dynamic> f) {
    return f['minPrice'] != null ||
        f['maxPrice'] != null ||
        f['maxDistance'] != null ||
        f['rooms'] != null ||
        f['bathrooms'] != null ||
        (f['furnishedOnly'] == true);
  }

  void _clearAll() {
    setState(() {
      _priceRange = RangeValues(_priceMinBound, _priceMaxBound);
      _maxDistance = _distanceMaxBound;
      _roomsMin = null;
      _bathroomsMin = null;
      _furnishedOnly = false;
    });
  }

  void _apply() {
    final draft = _draftFilters();

    // ننظف null keys عشان map يكون أنظف
    draft.removeWhere((k, v) => v == null);

    widget.onApply(draft);
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _initBounds();
    _loadInitialFilters();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final draft = _draftFilters();
    final hasAny = _hasAnyFilter(draft);

    final count = widget.previewCount?.call(draft);

    Widget chip({
      required String label,
      required VoidCallback onClear,
      IconData? icon,
    }) {
      return InputChip(
        label: Text(label),
        avatar: icon == null ? null : Icon(icon, size: 16),
        onDeleted: onClear,
      );
    }

    final activeChips = <Widget>[];

    // Price chip
    final minP = draft['minPrice'] as double?;
    final maxP = draft['maxPrice'] as double?;
    if (minP != null || maxP != null) {
      activeChips.add(
        chip(
          icon: Icons.payments_outlined,
          label:
              '${tr(context, 'Price', 'السعر')}: ${_priceRange.start.toStringAsFixed(0)} - ${_priceRange.end.toStringAsFixed(0)}',
          onClear: () => setState(() {
            _priceRange = RangeValues(_priceMinBound, _priceMaxBound);
          }),
        ),
      );
    }

    // Distance chip
    final maxD = draft['maxDistance'] as double?;
    if (maxD != null) {
      activeChips.add(
        chip(
          icon: Icons.place_outlined,
          label:
              '${tr(context, '≤', '≤')} ${_maxDistance.toStringAsFixed(1)} ${tr(context, 'km', 'كم')}',
          onClear: () => setState(() {
            _maxDistance = _distanceMaxBound;
          }),
        ),
      );
    }

    // Rooms chip
    if (_roomsMin != null) {
      activeChips.add(
        chip(
          icon: Icons.bed_outlined,
          label:
              '${tr(context, 'Rooms', 'الغرف')}: ${_roomsMin!}+',
          onClear: () => setState(() => _roomsMin = null),
        ),
      );
    }

    // Bathrooms chip
    if (_bathroomsMin != null) {
      activeChips.add(
        chip(
          icon: Icons.bathtub_outlined,
          label:
              '${tr(context, 'Bathrooms', 'الحمامات')}: ${_bathroomsMin!}+',
          onClear: () => setState(() => _bathroomsMin = null),
        ),
      );
    }

    // Furnished chip
    if (_furnishedOnly) {
      activeChips.add(
        chip(
          icon: Icons.chair_outlined,
          label: tr(context, 'Furnished', 'مفروشة'),
          onClear: () => setState(() => _furnishedOnly = false),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Filters', 'الفلاتر')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
       
      ),
      backgroundColor: scheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active filters summary
          if (hasAny) ...[
            Text(
              tr(context, 'Active filters', 'الفلاتر المفعّلة'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeChips,
            ),
            const SizedBox(height: 16),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 8),
          ],

          // PRICE
          Text(
            tr(context, 'Price (JOD)', 'السعر (دينار)'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_priceRange.start.toStringAsFixed(0)}'),
              Text('${_priceRange.end.toStringAsFixed(0)}'),
            ],
          ),
          RangeSlider(
            min: _priceMinBound,
            max: _priceMaxBound,
            values: _priceRange,
            onChanged: (v) => setState(() => _priceRange = v),
          ),
          const SizedBox(height: 16),

          // ROOMS (>=)
          Text(
            tr(context, 'Rooms (at least)', 'الغرف (على الأقل)'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(tr(context, 'Any', 'أي')),
                selected: _roomsMin == null,
                onSelected: (_) => setState(() => _roomsMin = null),
              ),
              ...[
                {'v': 1, 'tEn': '1+', 'tAr': '1+'},
                {'v': 2, 'tEn': '2+', 'tAr': '2+'},
                {'v': 3, 'tEn': '3+', 'tAr': '3+'},
                {'v': 4, 'tEn': '4+', 'tAr': '4+'},
              ].map((m) {
                final v = m['v'] as int;
                final label = tr(context, m['tEn'] as String, m['tAr'] as String);

                // studio: نخليه يعادل roomsMin = 0
                return ChoiceChip(
                  label: Text(label),
                  selected: _roomsMin == v,
                  onSelected: (_) => setState(() => _roomsMin = v),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // BATHROOMS (>=)
          Text(
            tr(context, 'Bathrooms (at least)', 'الحمامات (على الأقل)'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text(tr(context, 'Any', 'أي')),
                selected: _bathroomsMin == null,
                onSelected: (_) => setState(() => _bathroomsMin = null),
              ),
              ...[
                {'v': 1, 'tEn': '1+', 'tAr': '1+'},
                {'v': 2, 'tEn': '2+', 'tAr': '2+'},
                {'v': 3, 'tEn': '3+', 'tAr': '3+'},
              ].map((m) {
                final v = m['v'] as int;
                final label = tr(context, m['tEn'] as String, m['tAr'] as String);
                return ChoiceChip(
                  label: Text(label),
                  selected: _bathroomsMin == v,
                  onSelected: (_) => setState(() => _bathroomsMin = v),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // DISTANCE
          Text(
            tr(context, 'Max distance to TTU (km)', 'أقصى مسافة عن الجامعة (كم)'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (_maxDistance - _distanceMaxBound).abs() < 0.0001
                ? tr(context, 'Any distance', 'أي مسافة')
                : '${tr(context, 'Up to', 'حتى')} ${_maxDistance.toStringAsFixed(1)} ${tr(context, 'km', 'كم')}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          Slider(
            min: 0,
            max: _distanceMaxBound,
            value: _maxDistance,
            divisions: (_distanceMaxBound * 2).round().clamp(1, 300),
            onChanged: (v) => setState(() => _maxDistance = v),
          ),
          const SizedBox(height: 8),

          // Furnished
          SwitchListTile(
            value: _furnishedOnly,
            onChanged: (v) => setState(() => _furnishedOnly = v),
            title: Text(tr(context, 'Furnished only', 'مفروشة فقط')),
            activeThumbColor: scheme.primary,
          ),

          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _clearAll,
                child: Text(tr(context, 'Clear', 'مسح')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  count == null
                      ? tr(context, 'Apply', 'تطبيق')
                      : '${tr(context, 'Apply', 'تطبيق')} (${count.toString()})',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
