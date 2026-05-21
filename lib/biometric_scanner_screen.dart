// lib/biometric_scanner_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animal_warfare/services/biometric_service.dart';
import 'package:animal_warfare/services/segmentation_service.dart';
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/widgets/anidex_details_sheet.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/manual_masking_screen.dart';

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
  final SegmentationService _segmentation = SegmentationService();
  bool _mlReady = false;

  bool _isScanning = false;
  bool _hasScanned = false;
  String _statusText = 'READY TO SCAN';
  double _progress = 0.0;
  List<ScanResult> _results = [];
  Uint8List? _imageBytes;
  Uint8List? _maskedBytes;
  String _predictedClass = 'unknown';
  String _predictedDiet = 'unknown';
  double _predictedWeight = 0.0;
  String _sortBy = 'Overall';
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
    // Warm up the ML segmentation model
    _segmentation.initialize().then((_) {
      if (mounted) {
        setState(() => _mlReady = _segmentation.isAvailable);
      }
    });
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
        onProgress:
            (
              status,
              progress, {
              predictedClass,
              predictedDiet,
              predictedWeight,
            }) {
              if (mounted) {
                setState(() {
                  _statusText = status.toUpperCase();
                  _progress = progress;
                  if (predictedClass != null) _predictedClass = predictedClass;
                  if (predictedDiet != null) _predictedDiet = predictedDiet;
                  if (predictedWeight != null)
                    _predictedWeight = predictedWeight;
                });
              }
            },
      );

      final masked = results.isNotEmpty ? results.first.maskedImage : null;

      if (mounted) {
        setState(() {
          if (results.isNotEmpty) {
            _predictedClass = results.first.detectedClass;
          }
          _results = results;
          _sortResults();
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
      onProgress:
          (status, progress, {predictedClass, predictedDiet, predictedWeight}) {
            if (mounted) {
              setState(() {
                _statusText = status.toUpperCase();
                _progress = progress;
                if (predictedClass != null) _predictedClass = predictedClass;
                if (predictedDiet != null) _predictedDiet = predictedDiet;
                if (predictedWeight != null) _predictedWeight = predictedWeight;
              });
            }
          },
    );

    if (mounted) {
      setState(() {
        if (results.isNotEmpty) {
          _predictedClass = results.first.detectedClass;
        }
        _results = results;
        _sortResults();
        _isScanning = false;
        _statusText = results.isEmpty
            ? 'NO MATCH FOUND'
            : '${results.length} SPECIES IDENTIFIED';
      });
    }
  }

  Future<void> _openManualMasking() async {
    if (_imageBytes == null) return;

    final Uint8List? refinedMask = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => ManualMaskingScreen(imageBytes: _imageBytes!),
      ),
    );

    if (refinedMask != null) {
      setState(() {
        _maskedBytes = refinedMask;
        _isScanning = true;
        _statusText = 'APPLYING MANUAL MASK...';
        _progress = 0.0;
      });

      try {
        final results = await _service.scanImage(
          _imageBytes!,
          preSegmentedBytes: _maskedBytes,
          hint: _hintController.text,
          onProgress:
              (
                msg,
                p, {
                predictedClass,
                predictedDiet,
                predictedWeight,
              }) => setState(() {
                _statusText = msg.toUpperCase();
                _progress = p;
                if (predictedClass != null) _predictedClass = predictedClass;
                if (predictedDiet != null) _predictedDiet = predictedDiet;
                if (predictedWeight != null) _predictedWeight = predictedWeight;
              }),
        );

        setState(() {
          if (results.isNotEmpty) {
            _predictedClass = results.first.detectedClass;
          }
          _results = results;
          _sortResults();
          _isScanning = false;
          _hasScanned = true;
          _statusText = results.isEmpty
              ? 'NO MATCH FOUND'
              : '${results.length} SPECIES IDENTIFIED';
        });
      } catch (e) {
        setState(() {
          _isScanning = false;
          _statusText = 'SCAN ERROR';
        });
      }
    }
  }

  void _showSegmentationPreview() {
    if (_imageBytes == null) return;

    showDialog(
      context: context,
      builder: (context) {
        bool showOriginal = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.cyanAccent.withAlpha(50)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SEGMENTATION PREVIEW',
                          style: GoogleFonts.shareTechMono(
                            color: Colors.cyanAccent,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background pattern to show transparency
                          Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              image: DecorationImage(
                                image: const AssetImage(
                                  'assets/ui/checkerboard.png',
                                ), // Fallback to grey if missing
                                repeat: ImageRepeat.repeat,
                                opacity: 0.1,
                                onError: (_, _) {},
                              ),
                            ),
                          ),
                          Image.memory(
                            showOriginal
                                ? _imageBytes!
                                : (_maskedBytes ?? _imageBytes!),
                            width: 300,
                            height: 300,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPreviewToggle('MASKED', !showOriginal, () {
                          setDialogState(() => showOriginal = false);
                        }),
                        const SizedBox(width: 16),
                        _buildPreviewToggle('ORIGINAL', showOriginal, () {
                          setDialogState(() => showOriginal = true);
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Close preview
                        _openManualMasking();
                      },
                      icon: const Icon(
                        Icons.brush,
                        color: Colors.cyanAccent,
                        size: 16,
                      ),
                      label: Text(
                        'MANUALLY REFINE MASK',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.cyanAccent,
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.cyanAccent.withAlpha(20),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'The engine isolates the animal from the background before extraction. '
                      'This prevents background noise from affecting identification accuracy.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviewToggle(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.cyanAccent.withAlpha(30) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? Colors.cyanAccent : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: active ? Colors.cyanAccent : Colors.white30,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _sortResults() {
    if (_results.isEmpty) return;

    setState(() {
      _results.sort((a, b) {
        double valA, valB;
        switch (_sortBy) {
          case 'Color':
            valA = a.featureScores['Color'] ?? 0;
            valB = b.featureScores['Color'] ?? 0;
            break;
          case 'Shape':
            valA = a.featureScores['Shape'] ?? 0;
            valB = b.featureScores['Shape'] ?? 0;
            break;
          case 'Pattern':
            valA = a.featureScores['Pattern'] ?? 0;
            valB = b.featureScores['Pattern'] ?? 0;
            break;
          case 'Shade':
            valA = a.featureScores['Shade'] ?? 0;
            valB = b.featureScores['Shade'] ?? 0;
            break;
          default:
            valA = a.confidence;
            valB = b.confidence;
        }

        // Priority 1: High-confidence grouping (only for default 'Overall' sort)
        if (_sortBy == 'Overall') {
          if (a.isGenusMate && !b.isGenusMate) return -1;
          if (!a.isGenusMate && b.isGenusMate) return 1;
        }

        // Priority 2: Value-based sorting (accuracy)
        return valB.compareTo(valA); // Descending
      });
    });
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
            colors: [Colors.cyanAccent.withAlpha(15), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _hasScanned ? _buildResults() : _buildScanArea()),
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
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.cyanAccent,
              size: 20,
            ),
            onPressed: widget.onBack,
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.fingerprint_rounded,
            color: Colors.cyanAccent,
            size: 24,
          ),
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
          if (_mlReady)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.greenAccent.withAlpha(60)),
              ),
              child: Text(
                'AI',
                style: GoogleFonts.shareTechMono(
                  color: Colors.greenAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
        const SizedBox(height: 12),
        if (_hasScanned || _isScanning) _buildPredictionPanel(),
      ],
    );
  }

  Widget _buildPredictedProfileBadge() {
    final String label = _predictedClass == 'unknown'
        ? 'GENERIC BIOLOGY'
        : _predictedClass.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.cyanAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.cyanAccent.withAlpha(80), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.cyanAccent.withAlpha(30),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology, color: Colors.cyanAccent, size: 14),
          const SizedBox(width: 6),
          Text(
            'AI PROFILE: ${_predictedClass.toUpperCase()} | ${_predictedDiet.toUpperCase()} | ${_predictedWeight.toStringAsFixed(1)}KG',
            style: GoogleFonts.shareTechMono(
              color: Colors.cyanAccent,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionPanel() {
    if (_predictedClass == 'unknown' && !_isScanning)
      return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        children: [
          Text(
            'PROBABLE BIOLOGICAL PROFILE',
            style: GoogleFonts.shareTechMono(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPredictiveStat('IDENTIFIED BIOTYPE', _predictedClass.toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPredictiveStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: Colors.cyanAccent.withAlpha(100),
            fontSize: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.shareTechMono(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HINT: Type a name or genus to improve accuracy.',
                  style: GoogleFonts.inter(
                    color: Colors.cyanAccent.withAlpha(120),
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                _buildSortSelector(),
              ],
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? _buildNoResults()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                child: GestureDetector(
                  onTap: () => _showSegmentationPreview(),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Image.memory(
                          _maskedBytes ?? _imageBytes!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.cyanAccent.withAlpha(150),
                            size: 14,
                          ),
                        ),
                      ],
                    ),
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
                      color: Colors.white,
                      fontSize: 11,
                    ),
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

  Widget _buildSortSelector() {
    return PopupMenuButton<String>(
      initialValue: _sortBy,
      onSelected: (val) {
        setState(() {
          _sortBy = val;
          _sortResults();
        });
      },
      tooltip: 'Sort by feature',
      offset: const Offset(0, 20),
      color: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.cyanAccent.withAlpha(30)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.cyanAccent.withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SORT: ${_sortBy.toUpperCase()}',
              style: GoogleFonts.shareTechMono(
                color: Colors.cyanAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              color: Colors.cyanAccent,
              size: 14,
            ),
          ],
        ),
      ),
      itemBuilder: (context) =>
          ['Overall', 'Color', 'Shape', 'Pattern', 'Shade']
              .map(
                (s) => PopupMenuItem(
                  value: s,
                  height: 32,
                  child: Text(
                    s.toUpperCase(),
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.white.withAlpha(20),
          ),
          const SizedBox(height: 12),
          Text(
            'NO MATCHING SIGNATURES',
            style: GoogleFonts.shareTechMono(
              color: Colors.white24,
              fontSize: 12,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(ScanResult result, int index) {
    final org = result.organism;
    final pct = (result.confidence * 100).toStringAsFixed(1);
    final tileColor = result.isPinpointed
        ? Colors.amberAccent
        : result.confidence > 0.7
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
        color: result.isPinpointed
            ? Colors.amber.withAlpha(15)
            : Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.isPinpointed
              ? Colors.amberAccent.withAlpha(100)
              : tileColor.withAlpha(40),
          width: result.isPinpointed ? 1.5 : 1.0,
        ),
        boxShadow: result.isPinpointed
            ? [
                BoxShadow(
                  color: Colors.amberAccent.withAlpha(20),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showComparisonDialog(result),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _buildIndexBadge(index + 1),
                const SizedBox(width: 12),
                _buildSpritePreview(spritePath),
                const SizedBox(width: 16),
                Expanded(child: _buildResultInfo(result)),
                const SizedBox(width: 12),
                _buildConfidenceDisplay(result.confidence, tileColor, pct),
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

  Widget _buildResultInfo(ScanResult result) {
    final org = result.organism;
    final scores = result.featureScores;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                org.name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (result.isPinpointed)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(60),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amberAccent, width: 0.5),
                ),
                child: Text(
                  'PINPOINTED',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.amberAccent,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                org.scientificName,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildMiniBadge(org.animalClass.toUpperCase(), Colors.white24),
            const SizedBox(width: 4),
            _buildMiniBadge(
              org.diet.toUpperCase(),
              Colors.green.withAlpha(100),
            ),
            const SizedBox(width: 4),
            _buildMiniBadge(
              '${org.formattedWeight}KG',
              Colors.cyan.withAlpha(100),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildFeatureBreakdown(scores),
      ],
    );
  }

  Widget _buildMiniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.shareTechMono(
          color: Colors.white70,
          fontSize: 7,
          fontWeight: FontWeight.bold,
        ),
      ),
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
        const SizedBox(width: 6),
        _FeatureDot(label: 'SHP', score: scores['Shape'] ?? 0),
        const SizedBox(width: 6),
        _FeatureDot(label: 'PAT', score: scores['Pattern'] ?? 0),
        const SizedBox(width: 6),
        _FeatureDot(label: 'SHD', score: scores['Shade'] ?? 0),
        const SizedBox(width: 6),
        _FeatureDot(label: 'TAX', score: scores['Taxonomy'] ?? 0),
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

  void _showComparisonDialog(ScanResult result) {
    final org = result.organism;
    final spritePath = result.isExternal
        ? org.sprite
        : BiometricService.spritePathForName(org.name);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1A1A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name.toUpperCase(),
                          style: GoogleFonts.shareTechMono(
                            color: Colors.cyanAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          org.scientificName,
                          style: GoogleFonts.inter(
                            color: Colors.white30,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildMiniBadge(
                              org.animalClass.toUpperCase(),
                              Colors.white24,
                            ),
                            const SizedBox(width: 4),
                            _buildMiniBadge(
                              org.diet.toUpperCase(),
                              Colors.green.withAlpha(100),
                            ),
                            const SizedBox(width: 4),
                            _buildMiniBadge(
                              '${org.formattedWeight}KG',
                              Colors.cyan.withAlpha(100),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Side-by-side Visual Verification
              Row(
                children: [
                  Expanded(
                    child: _buildComparisonPreview(
                      'SCANNED SUBJECT',
                      result.maskedImage != null
                          ? Image.memory(
                              result.maskedImage!,
                              fit: BoxFit.contain,
                            )
                          : const Icon(
                              Icons.broken_image,
                              color: Colors.white10,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildComparisonPreview(
                      'SPECIES MATCH',
                      buildSilhouetteSprite(
                        imageUrl: spritePath,
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'BIOMETRIC COMPARISON',
                style: GoogleFonts.shareTechMono(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              _buildComparisonRow('COLOR', result.featureScores['Color'] ?? 0),
              _buildComparisonRow(
                'PATTERN',
                result.featureScores['Pattern'] ?? 0,
              ),
              _buildComparisonRow('SHADE', result.featureScores['Shade'] ?? 0),
              _buildComparisonRow('SHAPE', result.featureScores['Shape'] ?? 0),
              _buildComparisonRow(
                'STRUCTURE',
                result.featureScores['Structure'] ?? 0,
              ),
              _buildComparisonRow('POSE', result.featureScores['Pose'] ?? 0),
              _buildComparisonRow(
                'SYMMETRY',
                result.featureScores['Symmetry'] ?? 0,
              ),
              _buildComparisonRow(
                'TAXONOMY',
                result.featureScores['Taxonomy'] ?? 0,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnidexDetailsPage(organism: org),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: Text(
                    'OPEN ANIDEX ENTRY',
                    style: GoogleFonts.shareTechMono(letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyanAccent.withAlpha(40),
                    foregroundColor: Colors.cyanAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonPreview(String label, Widget content) {
    return Column(
      children: [
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Padding(padding: const EdgeInsets.all(8), child: content),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.shareTechMono(
            color: Colors.white24,
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, double score) {
    final color = score > 0.8
        ? Colors.greenAccent
        : score > 0.5
        ? Colors.yellowAccent
        : Colors.redAccent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 10,
                ),
              ),
              Text(
                '${(score * 100).toInt()}% MATCH',
                style: GoogleFonts.shareTechMono(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: score.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withAlpha(10),
              valueColor: AlwaysStoppedAnimation<Color>(color.withAlpha(150)),
              minHeight: 4,
            ),
          ),
        ],
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
          color: Colors.white,
          fontSize: 13,
          letterSpacing: 1,
        ),
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
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 6),
        ),
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
  bool shouldRepaint(covariant _ScanLinePainter old) =>
      old.progress != progress;
}
