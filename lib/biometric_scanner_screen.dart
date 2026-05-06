// lib/biometric_scanner_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animal_warfare/services/biometric_service.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/widgets/anidex_details_sheet.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/theme.dart';

class BiometricScannerScreen extends StatefulWidget {
  final VoidCallback onBack;
  const BiometricScannerScreen({super.key, required this.onBack});

  @override
  State<BiometricScannerScreen> createState() => _BiometricScannerScreenState();
}

class _BiometricScannerScreenState extends State<BiometricScannerScreen>
    with TickerProviderStateMixin {
  final BiometricService _service = BiometricService();
  final ImagePicker _picker = ImagePicker();

  bool _isScanning = false;
  bool _hasScanned = false;
  String _statusText = 'READY TO SCAN';
  double _progress = 0.0;
  List<ScanResult> _results = [];
  Uint8List? _imageBytes;
  Uint8List? _maskedBytes;
  final TextEditingController _hintController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _service.initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanLineController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _isScanning = true;
        _hasScanned = false;
        _results = [];
        _statusText = 'INITIALIZING SCAN...';
        _progress = 0.0;
      });

      final results = await _service.scanImage(
        bytes,
        maxResults: 15,
        hint: _hintController.text,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _statusText = status.toUpperCase();
              _progress = progress;
            });
          }
        },
      );

      final masked = results.isNotEmpty ? results.first.maskedImage : null;

      if (mounted) {
        setState(() {
          _results = results;
          _maskedBytes = masked;
          _isScanning = false;
          _hasScanned = true;
          _statusText = results.isEmpty
              ? 'NO MATCH FOUND'
              : '${results.length} SPECIES IDENTIFIED';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusText = 'SCAN ERROR: $e';
        });
      }
    }
  }

  Future<void> _refineScan() async {
    if (_imageBytes == null) return;
    setState(() {
      _isScanning = true;
      _statusText = 'REFINING ANALYSIS...';
    });

    final results = await _service.scanImage(
      _imageBytes!,
      maxResults: 15,
      hint: _hintController.text,
      onProgress: (status, progress) {
        if (mounted) {
          setState(() {
            _statusText = status.toUpperCase();
            _progress = progress;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _results = results;
        _isScanning = false;
        _statusText = results.isEmpty
            ? 'NO MATCH FOUND'
            : '${results.length} SPECIES IDENTIFIED';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Deep dark background
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              Colors.cyanAccent.withAlpha(15),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _hasScanned ? _buildResults() : _buildScanArea(),
              ),
              if (!_isScanning) _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black26,
        border: Border(
          bottom: BorderSide(color: Colors.cyanAccent.withAlpha(30)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.cyanAccent, size: 20),
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.fingerprint_rounded,
              color: Colors.cyanAccent, size: 24),
          const SizedBox(width: 12),
          Text(
            'BIO-SCANNER',
            style: GoogleFonts.shareTechMono(
              color: Colors.cyanAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const Spacer(),
          _buildPulseIndicator(),
        ],
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isScanning
              ? Color.lerp(Colors.yellow, Colors.red, _pulseController.value)
              : Colors.cyanAccent,
          boxShadow: [
            BoxShadow(
              color: (_isScanning ? Colors.yellow : Colors.cyanAccent)
                  .withAlpha(100),
              blurRadius: 8 * _pulseController.value + 4,
              spreadRadius: 2 * _pulseController.value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanArea() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageBytes != null) ...[
              _buildImagePreview(),
              const SizedBox(height: 24),
              _buildHintInput(),
              const SizedBox(height: 24),
            ] else ...[
              _buildEmptyState(),
              const SizedBox(height: 32),
            ],
            _buildStatusDisplay(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withAlpha(50)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.memory(
              _imageBytes!,
              height: 220,
              width: 220,
              fit: BoxFit.cover,
            ),
            if (_isScanning)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanLineController,
                  builder: (context, child) => CustomPaint(
                    painter: _ScanLinePainter(_scanLineController.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Icon(
          Icons.center_focus_strong_rounded,
          size: 80,
          color: Colors.cyanAccent.withAlpha(40),
        ),
        const SizedBox(height: 16),
        Text(
          'AWAITING INPUT',
          style: GoogleFonts.shareTechMono(
            color: Colors.cyanAccent.withAlpha(80),
            fontSize: 14,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDisplay() {
    return Column(
      children: [
        Text(
          _statusText,
          textAlign: TextAlign.center,
          style: GoogleFonts.shareTechMono(
            color: _isScanning ? Colors.yellowAccent : Colors.cyanAccent,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        if (_isScanning) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildResultHeader(),
        if (_results.isNotEmpty && _hintController.text.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'HINT: Type a name or genus to improve accuracy.',
              style: GoogleFonts.inter(
                color: Colors.cyanAccent.withAlpha(120),
                fontSize: 9,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, index) =>
                      _buildResultTile(_results[index], index),
                ),
        ),
      ],
    );
  }

  Widget _buildResultHeader() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.cyanAccent.withAlpha(50)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _maskedBytes ?? _imageBytes!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'BIOMETRIC SIGNATURES FOUND',
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildNewScanButton(),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.cyanAccent.withAlpha(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hintController,
                    style: GoogleFonts.shareTechMono(
                        color: Colors.white, fontSize: 11),
                    decoration: InputDecoration(
                      hintText: 'ADD HINT (NAME, GENUS...)',
                      hintStyle: GoogleFonts.shareTechMono(
                        color: Colors.white10,
                        fontSize: 10,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _refineScan(),
                  ),
                ),
                TextButton(
                  onPressed: _isScanning ? null : _refineScan,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                  ),
                  child: Text(
                    'REFINE',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewScanButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          _hasScanned = false;
          _results = [];
          _imageBytes = null;
          _maskedBytes = null;
          _hintController.clear();
          _statusText = 'READY TO SCAN';
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.cyanAccent.withAlpha(40)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'NEW',
            style: GoogleFonts.shareTechMono(
              color: Colors.cyanAccent,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: Colors.white.withAlpha(20)),
          const SizedBox(height: 12),
          Text(
            'NO MATCHING SIGNATURES',
            style: GoogleFonts.shareTechMono(
                color: Colors.white24, fontSize: 12, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(ScanResult result, int index) {
    final org = result.organism;
    final pct = (result.confidence * 100).toStringAsFixed(1);
    final color = result.confidence > 0.7
        ? Colors.greenAccent
        : result.confidence > 0.4
            ? Colors.yellowAccent
            : Colors.orangeAccent;

    final spritePath = result.isExternal
        ? org.sprite
        : BiometricService.spritePathForName(org.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AnidexDetailsSheet.show(context, org),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildIndexBadge(index + 1),
                const SizedBox(width: 12),
                _buildSpritePreview(spritePath),
                const SizedBox(width: 16),
                Expanded(child: _buildResultInfo(org, result.featureScores)),
                const SizedBox(width: 12),
                _buildConfidenceDisplay(result.confidence, color, pct),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndexBadge(int index) {
    return Container(
      width: 24,
      alignment: Alignment.center,
      child: Text(
        '#$index',
        style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 10),
      ),
    );
  }

  Widget _buildSpritePreview(String path) {
    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
      ),
      child: buildSilhouetteSprite(
        imageUrl: path,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        silhouetteColor: null,
      ),
    );
  }

  Widget _buildResultInfo(Organism org, Map<String, double> scores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          org.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          org.scientificName,
          style: GoogleFonts.shareTechMono(
            color: Colors.white38,
            fontSize: 9,
            fontStyle: FontStyle.italic,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        _buildFeatureBreakdown(scores),
      ],
    );
  }

  Widget _buildConfidenceDisplay(double confidence, Color color, String pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$pct%',
          style: GoogleFonts.shareTechMono(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: confidence.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureBreakdown(Map<String, double> scores) {
    if (scores.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        _FeatureDot(label: 'CLR', score: scores['Color'] ?? 0),
        const SizedBox(width: 8),
        _FeatureDot(label: 'SHP', score: scores['Shape'] ?? 0),
        const SizedBox(width: 8),
        _FeatureDot(label: 'PAT', score: scores['Pattern'] ?? 0),
        const SizedBox(width: 8),
        _FeatureDot(label: 'SHD', score: scores['Shade'] ?? 0),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withAlpha(50)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildScanButton(
              icon: Icons.camera_alt_rounded,
              label: 'CAPTURE',
              onTap: () => _pickAndScan(ImageSource.camera),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildScanButton(
              icon: Icons.photo_library_rounded,
              label: 'UPLOADS',
              onTap: () => _pickAndScan(ImageSource.gallery),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withAlpha(60)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.cyanAccent.withAlpha(20),
                Colors.cyanAccent.withAlpha(5),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.shareTechMono(
                  color: Colors.cyanAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHintInput() {
    return Container(
      width: 280,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyanAccent.withAlpha(40)),
      ),
      child: TextField(
        controller: _hintController,
        style: GoogleFonts.shareTechMono(
            color: Colors.white, fontSize: 13, letterSpacing: 1),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          hintText: 'INPUT OPTIONAL HINT',
          hintStyle: GoogleFonts.shareTechMono(
            color: Colors.white24,
            fontSize: 11,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _FeatureDot extends StatelessWidget {
  final String label;
  final double score;

  const _FeatureDot({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score > 0.8
        ? Colors.greenAccent
        : score > 0.5
            ? Colors.yellowAccent
            : Colors.white24;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 6)),
        const SizedBox(height: 3),
        Container(
          width: 28,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: score.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyanAccent.withAlpha(0),
          Colors.cyanAccent.withAlpha(150),
          Colors.cyanAccent.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, y - 4, size.width, 8));

    canvas.drawRect(Rect.fromLTWH(0, y - 2, size.width, 4), paint);

    final overlayPaint = Paint()..color = Colors.cyanAccent.withAlpha(15);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, y), overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.progress != progress;
}
