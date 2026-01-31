// D:\ttu_housing_app\lib\screens\map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ttu_housing_app/app_settings.dart';

class MapPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;

  const MapPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _map;
  LatLng _selected = const LatLng(30.8410169, 35.6429248); // TTU default
  bool _loadingAddr = false;
  String? _addressPreview;
  int _revToken = 0;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(widget.initialLat, widget.initialLng);
    _reverseGeocode(); // optional preview
  }

  MapType _mapType = MapType.normal;

  void _toggleMapType() {
    setState(() {
      _mapType = _mapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  Future<void> _searchPlace() async {
    final q = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(tr(ctx, 'Search place', 'ابحث عن مكان')),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: InputDecoration(
              hintText: tr(
                ctx,
                'e.g. Tafila, University Street',
                'مثال: الطفيلة، شارع الجامعة',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr(ctx, 'Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(tr(ctx, 'Search', 'بحث')),
            ),
          ],
        );
      },
    );

    if (q == null || q.isEmpty) return;

    try {
      final locs = await locationFromAddress(q);
      if (!mounted || locs.isEmpty) return;

      final latLng = LatLng(locs.first.latitude, locs.first.longitude);
      setState(() => _selected = latLng);

      await _map?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _reverseGeocode();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'No results found.', 'لم يتم العثور على نتائج.'),
          ),
        ),
      );
    }
  }

  Future<void> _reverseGeocode() async {
    final token = ++_revToken;
    setState(() => _loadingAddr = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        _selected.latitude,
        _selected.longitude,
      );

      if (!mounted || token != _revToken) return;

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts =
            [
                  p.street,
                  p.subLocality,
                  p.locality,
                  p.administrativeArea,
                  p.country,
                ]
                .where((e) => (e ?? '').trim().isNotEmpty)
                .map((e) => e!.trim())
                .toList();

        setState(() => _addressPreview = parts.join(', '));
      } else {
        setState(() => _addressPreview = null);
      }
    } catch (_) {
      if (!mounted || token != _revToken) return;
      setState(() => _addressPreview = null);
    } finally {
      if (!mounted || token != _revToken) return;
      if (mounted) setState(() => _loadingAddr = false);
    }
  }

  void _confirm() {
    Navigator.pop<Map<String, dynamic>>(context, {
      'lat': _selected.latitude,
      'lng': _selected.longitude,
      'address': _addressPreview ?? '',
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'Pick Location', 'اختر الموقع')),
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(onPressed: _searchPlace, icon: const Icon(Icons.search)),
          TextButton(
            onPressed: _loadingAddr ? null : _confirm,
            child: Text(tr(context, 'Confirm', 'تأكيد')),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition: CameraPosition(target: _selected, zoom: 15),
            onMapCreated: (c) => _map = c,
            onCameraMove: (pos) => _selected = pos.target,
            onCameraIdle: _reverseGeocode,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
          ),

          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'mapType',
              onPressed: _toggleMapType,
              child: const Icon(Icons.layers_outlined),
            ),
          ),

          const IgnorePointer(
            child: Center(
              child: Icon(Icons.location_pin, size: 44, color: Colors.red),
            ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _loadingAddr
                        ? Text(
                            tr(
                              context,
                              'Getting address...',
                              'جاري جلب العنوان...',
                            ),
                          )
                        : Text(
                            _addressPreview ??
                                tr(
                                  context,
                                  'Move the map to pick a location',
                                  'حرّك الخريطة لتحديد الموقع',
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
