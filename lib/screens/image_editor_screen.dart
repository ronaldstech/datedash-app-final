import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';

class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawnPath({required this.points, required this.color, required this.strokeWidth});
}

class ImageEditorScreen extends StatefulWidget {
  final File imageFile;

  const ImageEditorScreen({super.key, required this.imageFile});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  late File _currentImage;
  final TextEditingController _captionController = TextEditingController();

  final List<DrawnPath> _paths = [];
  DrawnPath? _currentPath;

  Color _selectedColor = Colors.red;
  final double _strokeWidth = 4.0;
  bool _isProcessing = false;

  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    const Color(0xFFFF4D85), // Theme pink
  ];

  @override
  void initState() {
    super.initState();
    _currentImage = widget.imageFile;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _cropImage() async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: _currentImage.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor:Theme.of(context).scaffoldBackgroundColor,
            toolbarWidgetColor: const Color(0xFFFF4D85),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _currentImage = File(croppedFile.path);
          _paths.clear(); // Clear drawings because aspect ratio changed
        });
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
    }
  }

  Future<void> _send() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Use higher pixel ratio for better resolution
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception("Failed to convert image to bytes");
      }

      final buffer = byteData.buffer.asUint8List();
      
      // Save to temp directory
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/edited_image_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(buffer);

      if (mounted) {
        Navigator.pop(context, {
          'file': tempFile,
          'caption': _captionController.text.trim(),
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to process image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _onPanStart(DragStartDetails details, BoxConstraints constraints) {
    // Only accept points within bounds
    if (_isPointInside(details.localPosition, constraints)) {
      setState(() {
        _currentPath = DrawnPath(
          points: [details.localPosition],
          color: _selectedColor,
          strokeWidth: _strokeWidth,
        );
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    if (_currentPath != null) {
      // Reclamp to bounding box if dragging outside
      Offset fixedPoint = details.localPosition;
      if (fixedPoint.dx < 0) fixedPoint = Offset(0, fixedPoint.dy);
      if (fixedPoint.dx > constraints.maxWidth) fixedPoint = Offset(constraints.maxWidth, fixedPoint.dy);
      if (fixedPoint.dy < 0) fixedPoint = Offset(fixedPoint.dx, 0);
      if (fixedPoint.dy > constraints.maxHeight) fixedPoint = Offset(fixedPoint.dx, constraints.maxHeight);

      setState(() {
        _currentPath!.points.add(fixedPoint);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentPath != null) {
      setState(() {
        _paths.add(_currentPath!);
        _currentPath = null;
      });
    }
  }

  bool _isPointInside(Offset point, BoxConstraints constraints) {
    return point.dx >= 0 && point.dx <= constraints.maxWidth &&
           point.dy >= 0 && point.dy <= constraints.maxHeight;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Always dark background for editor to highlight photo
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _paths.isNotEmpty ? () {
              setState(() {
                _paths.removeLast();
              });
            } : null,
          ),
          IconButton(
            icon: const Icon(Iconsax.crop),
            onPressed: _cropImage,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Color picker row
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _colors.map((c) => _buildColorButton(c)).toList(),
                ),
              ),
            ),
            
            // Image drawing area
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return RepaintBoundary(
                      key: _repaintKey,
                      child: Stack(
                        children: [
                          Image.file(
                            _currentImage,
                            fit: BoxFit.contain,
                          ),
                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: (details) => _onPanStart(details, constraints),
                              onPanUpdate: (details) => _onPanUpdate(details, constraints),
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                painter: DrawingPainter(
                                  paths: _paths,
                                  currentPath: _currentPath,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ),
            ),

            // Bottom Caption & Send Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: TextField(
                        controller: _captionController,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _send,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFF4D85), // Theme pink
                      ),
                      child: _isProcessing 
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                        : const Icon(Iconsax.send_1, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 	0.5),
                blurRadius: 8,
                spreadRadius: 2,
              )
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;

  DrawingPainter({required this.paths, this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    for (var path in paths) {
      _drawPath(canvas, path);
    }
    if (currentPath != null) {
      _drawPath(canvas, currentPath!);
    }
  }

  void _drawPath(Canvas canvas, DrawnPath path) {
    if (path.points.isEmpty) return;
    
    final paint = Paint()
      ..color = path.color
      ..strokeWidth = path.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final drawPath = Path();
    drawPath.moveTo(path.points.first.dx, path.points.first.dy);
    for (int i = 1; i < path.points.length; i++) {
      drawPath.lineTo(path.points[i].dx, path.points[i].dy);
    }
    canvas.drawPath(drawPath, paint);
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}

