// edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final LocalAuthService _authService = LocalAuthService();
  final ImagePicker _picker = ImagePicker();

  UserData? _currentUser;
  File? _pickedAvatarFile;
  final TextEditingController _usernameController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = true; // Only used for the initial load

  // Custom retro/military colors
  static const Color primaryButtonColor = Color(0xFF38761D);
  static const Color secondaryButtonColor = Color(0xFF1E3F2A);
  static const Color highlightColor = Color(0xFFDAA520);

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // Load user data from the local storage file
  Future<void> _loadUserProfile() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      _usernameController.text = user.username;
      _selectedGender = user.gender != 'N/A' ? user.gender : null;

      if (user.avatar.isNotEmpty && user.avatar != 'default') {
        try {
          final file = File(user.avatar);
          if (await file.exists()) {
            _pickedAvatarFile = file;
          }
        } catch (e) {
          debugPrint('Error loading avatar file: $e');
        }
      }
    }

    setState(() {
      _currentUser = user;
      _isLoading = false;
    });
  }

  // Pick image from the device gallery (No change needed here)
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null) {
      setState(() {
        _pickedAvatarFile = File(image.path);
      });
    }
  }

  // Save the updated profile information
  Future<void> _saveProfile() async {
    if (_currentUser == null || _isLoading) return;

    // We do NOT call setState here, which prevents the stutter/jank.

    // 1. Get the new avatar path (if one was picked), otherwise keep the old one
    final newAvatarPath = _pickedAvatarFile?.path ?? _currentUser!.avatar;

    // 2. Call the service to update the profile data in the JSON file (File I/O)
    await _authService.updateProfile(
      _currentUser!.username,
      avatar: newAvatarPath,
      gender: _selectedGender ?? 'N/A',
    );

    // 3. Provide feedback and navigate back smoothly
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile Updated Successfully!')),
      );
      // Pop the Edit screen immediately after saving
      Navigator.of(context).pop(); 
    }
  }

  // --- UI Helpers (No change needed here) ---
  Widget _buildThemedButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    // ... (unchanged implementation)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: primaryButtonColor,
        border: Border.all(color: highlightColor, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool enabled = true,
  }) {
    // ... (unchanged implementation)
    return Container(
      decoration: BoxDecoration(
        color: secondaryButtonColor.withOpacity(0.8),
        border: Border.all(color: highlightColor.withOpacity(0.6), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: highlightColor.withOpacity(0.8),
            fontSize: 12,
            fontFamily: 'PressStart2P',
          ),
          prefixIcon: Icon(icon, color: highlightColor.withOpacity(0.8), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // --- Main Build Method ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDIT PROFILE'),
        backgroundColor: secondaryButtonColor,
        foregroundColor: highlightColor,
        titleTextStyle: const TextStyle(fontFamily: 'PressStart2P', fontSize: 18),
      ),
      // Only check _isLoading for the initial load, not for the save button click
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: highlightColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // ... (Avatar and Gender logic unchanged)
                  
                  // 1. AVATAR (Select from Gallery)
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: highlightColor.withOpacity(0.2),
                      backgroundImage: _pickedAvatarFile != null
                          ? FileImage(_pickedAvatarFile!) as ImageProvider
                          : null,
                      child: _pickedAvatarFile == null
                          ? const Icon(Icons.add_a_photo, size: 50, color: highlightColor)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap to Change Avatar',
                    style: TextStyle(color: highlightColor, fontSize: 10, fontFamily: 'PressStart2P'),
                  ),
                  const SizedBox(height: 40),

                  // 2. USERNAME (Read-only)
                  _buildTextField(
                    controller: _usernameController,
                    labelText: 'USERNAME',
                    icon: Icons.person,
                    enabled: false,
                  ),

                  // 3. GENDER (Dropdown)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: secondaryButtonColor.withOpacity(0.8),
                      border: Border.all(color: highlightColor.withOpacity(0.6), width: 1),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedGender,
                        hint: Text(
                          'GENDER',
                          style: TextStyle(
                            color: highlightColor.withOpacity(0.8),
                            fontSize: 12,
                            fontFamily: 'PressStart2P',
                          ),
                        ),
                        dropdownColor: secondaryButtonColor.withOpacity(0.9),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'PressStart2P'),
                        icon: Icon(Icons.arrow_drop_down, color: highlightColor.withOpacity(0.8)),
                        items: const [
                          DropdownMenuItem(value: 'Male', child: Text('MALE')),
                          DropdownMenuItem(value: 'Female', child: Text('FEMALE')),
                          DropdownMenuItem(value: 'Other', child: Text('OTHER')),
                          DropdownMenuItem(value: 'N/A', child: Text('N/A')),
                        ],
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 4. SAVE PROFILE BUTTON
                  _buildThemedButton(
                    text: 'SAVE CHANGES',
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
    );
  }
}