import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class FishingMinigameOverlay extends StatefulWidget {
  const FishingMinigameOverlay({super.key});

  @override
  State<FishingMinigameOverlay> createState() => _FishingMinigameOverlayState();
}

class _FishingMinigameOverlayState extends State<FishingMinigameOverlay> {
  bool _isBiting = false;
  bool _finished = false;
  Timer? _biteTimer;
  Timer? _escapeTimer;
  
  @override
  void initState() {
    super.initState();
    _startFishing();
  }
  
  void _startFishing() {
    // Random delay between 2 and 5 seconds
    final delay = Random().nextInt(3000) + 2000;
    _biteTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      setState(() {
        _isBiting = true;
      });
      
      // Reaction window of 600ms
      _escapeTimer = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _handleMiss();
      });
    });
  }
  
  void _handleTap() {
    if (_finished) return;
    
    if (_isBiting) {
      // Success!
      _finished = true;
      _biteTimer?.cancel();
      _escapeTimer?.cancel();
      Navigator.of(context).pop(true);
    } else {
      // Tapped too early
      _finished = true;
      _biteTimer?.cancel();
      _escapeTimer?.cancel();
      _showFeedback('Pulled too early!');
    }
  }
  
  void _handleMiss() {
    if (_finished) return;
    _finished = true;
    _showFeedback('It got away...');
  }
  
  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10))),
    );
    Navigator.of(context).pop(false);
  }
  
  @override
  void dispose() {
    _biteTimer?.cancel();
    _escapeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54, // Overlay dim
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Wait for it...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'PressStart2P'),
              ),
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBiting ? Colors.red : Colors.blueAccent,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Center(
                  child: _isBiting 
                    ? const Text('!', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold))
                    : const Icon(Icons.water, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'TAP WHEN IT BITES!',
                style: TextStyle(color: Colors.yellow, fontSize: 12, fontFamily: 'PressStart2P'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
