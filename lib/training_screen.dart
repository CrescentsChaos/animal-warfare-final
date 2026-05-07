import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';

import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/services/feature_db_service.dart';
import 'package:animal_warfare/services/biometric_service.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final TextEditingController _scientificNameCtrl = TextEditingController();
  bool _isDragging = false;
  bool _isProcessing = false;
  
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();

  void _addLog(String msg) {
    setState(() {
      _logs.add(msg);
    });
    // Auto-scroll to bottom
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
    _addLog('Files to process: ${files.length}');

    final dbService = FeatureDbService();
    final biometricService = BiometricService();

    int successCount = 0;
    int failCount = 0;

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      _addLog('Processing [${i+1}/${files.length}]: ${file.name}...');
      
      try {
        final bytes = await file.readAsBytes();
        
        // Wait, BiometricService.extractFeatures expects Uint8List
        // It returns Future<OrganismFeature>
        // But what about the name? The OrganismFeature takes organismName.
        // Where do we get organismName from scientificName?
        // We need to look it up from Organisms.json or DB.
        
        // Lookup organism name
        final existingInDb = await dbService.searchByScientificName(sciName);
        String organismName = 'Unknown';
        if (existingInDb.isNotEmpty) {
          organismName = existingInDb.first.organismName;
        } else {
          // It might be a totally new species not in DB.
          // In real app, we might need to parse Organisms.json, but for now we'll just use sciName
          // Or we can check if there's a quick way to find common name.
          // For simplicity, if not found, we just use scientificName as the name.
          organismName = sciName;
        }

        final newFeature = await biometricService.extractFeatures(
          bytes,
          name: organismName,
        );

        // Upsert into DB using the new upsert logic
        await dbService.upsertTrainedFeature(
          scientificName: sciName,
          newFeature: newFeature,
        );

        _addLog('  -> Success! DB updated.');
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
                style: AppTextStyles.body(context, baseSize: 18, color: AppColors.highlight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the exact scientific name of the species, then drop multiple images to batch-train the model. The features will be averaged with existing data.',
                style: AppTextStyles.small(context),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _scientificNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Scientific Name (e.g. Panthera tigris)',
                  labelStyle: const TextStyle(color: AppColors.textMuted),
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
              const SizedBox(height: 24),
              
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
                          _isDragging ? Icons.download_rounded : Icons.cloud_upload_rounded,
                          size: 64,
                          color: _isDragging ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isDragging ? 'Drop images here!' : 'Drag & Drop Images Here',
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
                          Text('Process Log', style: AppTextStyles.label(context)),
                          if (_isProcessing)
                            const SizedBox(
                              width: 16, height: 16,
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
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _logs[index],
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: _logs[index].contains('ERROR') || _logs[index].contains('FAILED')
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
}
