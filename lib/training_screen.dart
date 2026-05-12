import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/feature_db_service.dart';
import 'package:animal_warfare/services/biometric_service.dart';
import 'package:animal_warfare/models/organism.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TextEditingController _scientificNameCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  bool _isDragging = false;
  bool _isProcessing = false;

  String _selectedClass = 'unknown';
  String _selectedDiet = 'unknown';

  // Auto-populated organism lookup
  List<Organism> _organisms = [];
  Organism? _matchedOrganism;

  static const List<String> _classOptions = [
    'unknown',
    'mammal',
    'bird',
    'fish',
    'amphibian',
    'reptile',
    'insect',
    'arachnid',
    'crustacean',
    'mollusk',
    'annelid',
    'cnidarian',
    'echinoderm',
    'otherInvertebrate',
  ];

  static const List<String> _dietOptions = [
    'unknown',
    'carnivore',
    'herbivore',
    'omnivore',
    'insectivore',
    'piscivore',
    'scavenger',
    'detritivore',
    'filter feeder',
    'nectarivore',
    'granivore',
    'parasite',
  ];

  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrganisms();
    _scientificNameCtrl.addListener(_lookupOrganism);
  }

  @override
  void dispose() {
    _scientificNameCtrl.removeListener(_lookupOrganism);
    _scientificNameCtrl.dispose();
    _weightCtrl.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOrganisms() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> data = json.decode(response);
      _organisms = data.map((j) => Organism.fromJson(j)).toList();
      _addLog('Loaded ${_organisms.length} organisms from database.');
    } catch (e) {
      _addLog('WARNING: Could not load Organisms.json: $e');
    }
  }

  void _lookupOrganism() {
    final sciName = _scientificNameCtrl.text.trim().toLowerCase();
    if (sciName.isEmpty || _organisms.isEmpty) {
      setState(() => _matchedOrganism = null);
      return;
    }

    final match = _organisms.cast<Organism?>().firstWhere(
      (o) =>
          o!.scientificName.toLowerCase() == sciName ||
          o.name.toLowerCase() == sciName,
      orElse: () => null,
    );

    if (match != null && match != _matchedOrganism) {
      setState(() {
        _matchedOrganism = match;
        _selectedClass = match.animalClass.isNotEmpty
            ? match.animalClass
            : 'unknown';
        _selectedDiet = match.diet.isNotEmpty ? match.diet : 'unknown';
        _weightCtrl.text = match.weight.toString();
      });
      _addLog('Auto-populated from: ${match.name} (${match.scientificName})');
    } else if (match == null) {
      setState(() => _matchedOrganism = null);
    }
  }

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _processFiles(List<XFile> files) async {
    final sciName = _scientificNameCtrl.text.trim();
    if (sciName.isEmpty) {
      _addLog('ERROR: Please enter a scientific name first.');
      return;
    }

    if (files.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    _addLog('--- Started Training Batch ---');
    _addLog('Scientific Name: $sciName');
    _addLog(
      'Class: $_selectedClass | Diet: $_selectedDiet | Weight: ${_weightCtrl.text}kg',
    );
    _addLog('Files to process: ${files.length}');

    final dbService = FeatureDbService();
    final biometricService = BiometricService();

    final double? weight = double.tryParse(_weightCtrl.text.trim());

    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      _addLog('Processing [${i + 1}/${files.length}]: ${file.name}...');

      try {
        final bytes = await file.readAsBytes();

        // Lookup organism name from DB or scientific name
        final existingInDb = await dbService.searchByScientificName(sciName);
        String organismName;
        if (existingInDb.isNotEmpty) {
          organismName = existingInDb.first.organismName;
        } else if (_matchedOrganism != null) {
          organismName = _matchedOrganism!.name;
        } else {
          organismName = sciName;
        }

        final newFeature = await biometricService.extractFeatures(
          bytes,
          name: organismName,
        );

        // Upsert into DB with class/diet/weight metadata
        await dbService.upsertTrainedFeature(
          scientificName: sciName,
          newFeature: newFeature,
          animalClass: _selectedClass != 'unknown' ? _selectedClass : null,
          diet: _selectedDiet != 'unknown' ? _selectedDiet : null,
          weight: weight,
        );

        _addLog(
          '  -> Success! DB updated (class=$_selectedClass, diet=$_selectedDiet, weight=${weight ?? "N/A"}kg).',
        );
        successCount++;
      } catch (e) {
        _addLog('  -> FAILED: $e');
        failCount++;
      }
    }

    _addLog('--- Training Batch Complete ---');
    _addLog('Success: $successCount');
    _addLog('Failed: $failCount');

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null && result.files.isNotEmpty) {
      final xfiles = result.files.map((f) => XFile(f.path!)).toList();
      await _processFiles(xfiles);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Model Trainer', style: AppTextStyles.headline(context)),
        backgroundColor: AppColors.surface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: DropTarget(
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (details) async {
          setState(() {
            _isDragging = false;
          });
          await _processFiles(details.files);
        },
        child: Container(
          color: _isDragging
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Biometric Feature Trainer',
                style: AppTextStyles.body(
                  context,
                  baseSize: 18,
                  color: AppColors.highlight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the exact scientific name of the species, configure class/diet/weight, then drop multiple images to batch-train the model.',
                style: AppTextStyles.small(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Scientific Name Input
              TextField(
                controller: _scientificNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Scientific Name (e.g. Panthera tigris)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
                  suffixIcon: _matchedOrganism != null
                      ? const Icon(
                          Icons.check_circle,
                          color: AppColors.correctGreen,
                          size: 20,
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              if (_matchedOrganism != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    'Matched: ${_matchedOrganism!.name}',
                    style: const TextStyle(
                      color: AppColors.correctGreen,
                      fontSize: 11,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Class, Diet, Weight Row
              Row(
                children: [
                  // Class Dropdown
                  Expanded(
                    child: _buildDropdown(
                      label: 'CLASS',
                      value: _selectedClass,
                      items: _classOptions,
                      onChanged: (v) =>
                          setState(() => _selectedClass = v ?? 'unknown'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Diet Dropdown
                  Expanded(
                    child: _buildDropdown(
                      label: 'DIET',
                      value: _selectedDiet,
                      items: _dietOptions,
                      onChanged: (v) =>
                          setState(() => _selectedDiet = v ?? 'unknown'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Weight Input
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'WEIGHT (KG)',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: '0.0',
                              hintStyle: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Drop Zone
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isDragging ? AppColors.primary : AppColors.border,
                      width: _isDragging ? 2 : 1,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isDragging
                              ? Icons.download_rounded
                              : Icons.cloud_upload_rounded,
                          size: 64,
                          color: _isDragging
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDragging
                              ? 'Drop images here!'
                              : 'Drag & Drop Images Here',
                          style: AppTextStyles.body(context, baseSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _pickFiles,
                          icon: const Icon(Icons.folder_open),
                          label: const Text('Browse Files'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            foregroundColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Logs Area
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Process Log',
                            style: AppTextStyles.label(context),
                          ),
                          if (_isProcessing)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      const Divider(color: AppColors.border),
                      Expanded(
                        child: ListView.builder(
                          controller: _logScrollController,
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 2.0,
                              ),
                              child: Text(
                                _logs[index],
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color:
                                      _logs[index].contains('ERROR') ||
                                          _logs[index].contains('FAILED')
                                      ? AppColors.dangerLight
                                      : _logs[index].contains('Success')
                                      ? AppColors.correctGreen
                                      : Colors.white70,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 42,
          child: DropdownButtonFormField<String>(
            initialValue: items.contains(value) ? value : items.first,
            items: items
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: onChanged,
            dropdownColor: AppColors.surface,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
