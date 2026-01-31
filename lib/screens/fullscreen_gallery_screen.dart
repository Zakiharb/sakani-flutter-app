import 'package:flutter/material.dart';

class FullscreenGalleryScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;

  const FullscreenGalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.heroPrefix = 'apt_img_',
  });

  @override
  State<FullscreenGalleryScreen> createState() => _FullscreenGalleryScreenState();
}

class _FullscreenGalleryScreenState extends State<FullscreenGalleryScreen> {
  late final PageController _ctrl;
  int _index = 0;

  bool _isNetwork(String s) => s.startsWith('http://') || s.startsWith('https://');

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.images;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${images.length}'),
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final url = images[i];

          final imageWidget = _isNetwork(url)
              ? Image.network(url, fit: BoxFit.contain)
              : Image.asset(url, fit: BoxFit.contain);

          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Hero(
                tag: '${widget.heroPrefix}$i',
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: imageWidget,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
