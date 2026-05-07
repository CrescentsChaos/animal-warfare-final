import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

class ManualMaskingScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ManualMaskingScreen({super.key, required this.imageBytes});

  @override
  State<ManualMaskingScreen> createState() => _ManualMaskingScreenState();
}

class _ManualMaskingScreenState extends State<ManualMaskingScreen> {
  final List<MaskStroke> _strokes = [];
  MaskStroke? _currentStroke;
  
  bool _isEraser = false;
  double _thickness = 20.0;
  
  ui.Image? _uiImage;
  bool _isProcessing = true;

  @override
  void initState() {
    super.initState();
    _loadUiImage();
  }

  Future<void> _loadUiImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
      _isProcessing = false;
    });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _currentStroke = MaskStroke(
        points: [details.localPosition],
        thickness: _thickness,
        isEraser: _isEraser,
      );
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentStroke?.points.add(details.localPosition);
    });
  }

  Future<void> _applyMask() async {
    if (_uiImage == null) return;
    
    setState(() => _isProcessing = true);

    // 1. Create a mask image the same size as the original image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(_uiImage!.width.toDouble(), _uiImage!.height.toDouble());
    
    // Fill with transparent (background to remove)
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.transparent);

    // We need to scale the strokes from screen coordinates to image coordinates
    // We assume the image is centered and scaled to fit the screen in the UI
    // For simplicity in this implementation, we will use the RenderBox to calculate scaling
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final screenWidth = renderBox.size.width;
    final screenHeight = renderBox.size.height;
    
    // Fit image to screen
    double scale;
    double offsetX = 0;
    double offsetY = 0;
    
    if (size.width / size.height > screenWidth / screenHeight) {
      scale = screenWidth / size.width;
      offsetY = (screenHeight - (size.height * scale)) / 2;
    } else {
      scale = screenHeight / size.height;
      offsetX = (screenWidth - (size.width * scale)) / 2;
    }

    final maskPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in _strokes) {
      maskPaint.strokeWidth = stroke.thickness / scale;
      // If eraser, we draw with clear color. 
      // BUT we want to create a WHITE mask for the subject, so eraser should draw TRANSPARENT.
      // Initially the canvas is transparent. We draw WHITE to select.
      maskPaint.color = stroke.isEraser ? Colors.transparent : Colors.white;
      maskPaint.blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

      if (stroke.points.length > 1) {
        final path = Path();
        final start = (stroke.points[0] - Offset(offsetX, offsetY)) / scale;
        path.moveTo(start.dx, start.dy);
        for (int i = 1; i < stroke.points.length; i++) {
          final p = (stroke.points[i] - Offset(offsetX, offsetY)) / scale;
          path.lineTo(p.dx, p.dy);
        }
        canvas.drawPath(path, maskPaint);
      } else if (stroke.points.isNotEmpty) {
        final p = (stroke.points[0] - Offset(offsetX, offsetY)) / scale;
        canvas.drawCircle(p, (stroke.thickness / scale) / 2, maskPaint..style = PaintingStyle.fill);
      }
    }

    final maskPicture = recorder.endRecording();
    final maskImage = await maskPicture.toImage(size.width.toInt(), size.height.toInt());

    // 2. Composite: Original image + Mask (BlendMode.dstIn)
    final finalRecorder = ui.PictureRecorder();
    final finalCanvas = Canvas(finalRecorder);
    
    finalCanvas.drawImage(_uiImage!, Offset.zero, Paint());
    finalCanvas.drawImage(maskImage, Offset.zero, Paint()..blendMode = BlendMode.dstIn);
    
    final finalPicture = finalRecorder.endRecording();
    final finalUiImage = await finalPicture.toImage(size.width.toInt(), size.height.toInt());
    
    final byteData = await finalUiImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      Navigator.pop(context, byteData.buffer.asUint8List());
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image and Masking Layer
          if (_uiImage != null)
            Center(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: MaskPainter(
                      image: _uiImage!,
                      strokes: _strokes,
                      isEraser: _isEraser,
                    ),
                  ),
                ),
              ),
            ),
          
          // Toolbar
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                Text(
                  'PAINT TO SELECT',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.cyanAccent, size: 32),
                  onPressed: _applyMask,
                ),
              ],
            ),
          ),
          
          // Controls
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildToolButton(Icons.brush, 'BRUSH', !_isEraser, () => setState(() => _isEraser = false)),
                          _buildToolButton(Icons.auto_fix_normal, 'ERASER', _isEraser, () => setState(() => _isEraser = true)),
                          _buildToolButton(Icons.undo, 'UNDO', false, () {
                            if (_strokes.isNotEmpty) setState(() => _strokes.removeLast());
                          }),
                          _buildToolButton(Icons.delete_sweep, 'CLEAR', false, () {
                            setState(() => _strokes.clear());
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.line_weight, color: Colors.white54, size: 20),
                          Expanded(
                            child: Slider(
                              value: _thickness,
                              min: 5,
                              max: 100,
                              activeColor: Colors.cyanAccent,
                              inactiveColor: Colors.white10,
                              onChanged: (v) => setState(() => _thickness = v),
                            ),
                          ),
                          Text(
                            '${_thickness.toInt()}px',
                            style: GoogleFonts.shareTechMono(color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Paint the area you want to KEEP for scanning',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: active ? Colors.cyanAccent : Colors.white54),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.shareTechMono(
              color: active ? Colors.cyanAccent : Colors.white54,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class MaskStroke {
  final List<Offset> points;
  final double thickness;
  final bool isEraser;

  MaskStroke({required this.points, required this.thickness, required this.isEraser});
}

class MaskPainter extends CustomPainter {
  final ui.Image image;
  final List<MaskStroke> strokes;
  final bool isEraser;

  MaskPainter({required this.image, required this.strokes, required this.isEraser});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw the image to fit the screen
    double scale;
    double offsetX = 0;
    double offsetY = 0;
    
    final imgWidth = image.width.toDouble();
    final imgHeight = image.height.toDouble();
    
    if (imgWidth / imgHeight > size.width / size.height) {
      scale = size.width / imgWidth;
      offsetY = (size.height - (imgHeight * scale)) / 2;
    } else {
      scale = size.height / imgHeight;
      offsetX = (size.width - (imgWidth * scale)) / 2;
    }

    final dstRect = Rect.fromLTWH(offsetX, offsetY, imgWidth * scale, imgHeight * scale);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imgWidth, imgHeight),
      dstRect,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );

    // 2. Draw a dim overlay on parts not selected? 
    // Actually, let's draw the selection as a semi-transparent green overlay.
    canvas.saveLayer(size.shortestSide.toInt().toDouble() != 0 ? Rect.fromLTWH(0,0,size.width, size.height) : null, Paint());
    
    final maskPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      maskPaint.strokeWidth = stroke.thickness;
      maskPaint.color = Colors.greenAccent.withAlpha(150);
      maskPaint.blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver;

      if (stroke.points.length > 1) {
        final path = Path();
        path.moveTo(stroke.points[0].dx, stroke.points[0].dy);
        for (int i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, maskPaint);
      } else if (stroke.points.isNotEmpty) {
        canvas.drawCircle(stroke.points[0], stroke.thickness / 2, maskPaint..style = PaintingStyle.fill);
      }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MaskPainter oldDelegate) => true;
}
