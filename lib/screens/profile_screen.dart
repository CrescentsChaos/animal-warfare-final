import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For cloud storage
import 'package:image_picker/image_picker.dart'; // For image gallery
import 'dart:io'; // Needed to check for local file paths

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Database and utility instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers and State for editable fields
  late TextEditingController _nameController;
  late String _selectedGender;
  late TextEditingController _avatarUrlController;

  // State to toggle between view and edit mode
  bool _isEditing = false; 

  // Initial state loaded from Firebase (fallback for data not in Firestore)
  String? _initialName;
  String? _initialAvatarUrl;
  
  // Flag to manage loading state for async operations
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Fallback defaults from Firebase Auth
    _initialName = widget.user.displayName ?? 'Mysterious Player';
    _initialAvatarUrl = widget.user.photoURL;
    _selectedGender = 'Not Set'; 

    // Initialize controllers with fallbacks
    _nameController = TextEditingController(text: _initialName);
    _avatarUrlController = TextEditingController(text: _initialAvatarUrl);

    _loadLocalProfile();
  }

  // Load profile data from Firestore
  Future<void> _loadLocalProfile() async {
    setState(() {
      _isLoading = true;
    });

    final doc = await _firestore.collection('user_profiles').doc(widget.user.uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      if (mounted) {
        setState(() {
          // Load data from Firestore, falling back to Firebase auth data
          _nameController.text = data['name'] ?? _initialName!;
          _selectedGender = data['gender'] ?? 'Not Set';
          _avatarUrlController.text = data['avatarUrl'] ?? _initialAvatarUrl!;
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save profile data to Firestore
  Future<void> _saveLocalProfile() async {
    final profileData = {
      'name': _nameController.text,
      'gender': _selectedGender,
      'avatarUrl': _avatarUrlController.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    
    await _firestore
        .collection('user_profiles')
        .doc(widget.user.uid)
        .set(profileData, SetOptions(merge: true));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved to cloud!')),
      );
      // Switch back to view mode after saving
      setState(() {
        _isEditing = false;
      });
    }
  }

  // Function to pick image from gallery
  Future<void> _pickImageFromGallery() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        // Update controller with the local file path
        _avatarUrlController.text = image.path;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  // Helper function to render the correct avatar image
  Widget getAvatarImage(String? url) {
    if (url != null && url.isNotEmpty) {
      // Check if it's a local file path (starts with common device paths)
      if (url.startsWith('/data/user/') || url.startsWith('/storage/emulated/')) {
        return Image.file(File(url), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 50, color: Colors.white);
        });
      } else {
        // Assume it's a network URL
        return Image.network(url, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 50, color: Colors.white);
        });
      }
    }
    // Default fallback
    return const Icon(Icons.person, size: 50, color: Colors.white);
  }

  // Toggles the editing mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = true;
    });
  }

  // ⭐️⭐️⭐️ BUILD METHOD IS HERE ⭐️⭐️⭐️
  @override
  Widget build(BuildContext context) {
    // Determine the current values
    final currentAvatarUrl = _avatarUrlController.text.isNotEmpty 
        ? _avatarUrlController.text 
        : widget.user.photoURL;
    
    final currentName = _nameController.text;
    final currentGender = _selectedGender;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'EDIT PROFILE' : 'USER PROFILE',
          style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 18.0, color: Colors.white),
        ),
        backgroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // Show loading spinner
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 👤 Avatar Display
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey,
                      child: ClipOval(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: getAvatarImage(currentAvatarUrl),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- Conditionally render View or Edit Mode ---
                  if (_isEditing)
                    // ➡️ EDIT MODE (Shows Text Fields, Dropdown, Gallery Button)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLabel('USERNAME'),
                        _buildTextField(_nameController, hint: 'Enter your nickname'),
                        const SizedBox(height: 20),

                        _buildLabel('GENDER'),
                        _buildGenderDropdown(),
                        const SizedBox(height: 20),
                        
                        _buildLabel('AVATAR URL (Image link)'),
                        _buildTextField(_avatarUrlController, hint: 'Optional link for your avatar'),
                        
                        const SizedBox(height: 10),
                        _buildMenuButton(
                          'BROWSE GALLERY', 
                          _pickImageFromGallery, 
                          isPrimary: false
                        ),
                        
                        const SizedBox(height: 40),

                        // SAVE Button
                        _buildMenuButton('SAVE', _saveLocalProfile, isPrimary: true),
                      ],
                    )
                  else
                    // ➡️ VIEW MODE (Shows only Text Data and Edit Button)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildViewItem('NAME', currentName),
                        _buildViewItem('GENDER', currentGender),
                        _buildViewItem('EMAIL (Auth)', widget.user.email ?? 'N/A', isLink: true), // Email is from Firebase Auth
                        _buildViewItem('CUSTOM AVATAR', currentAvatarUrl ?? 'N/A', isLink: true),
                        const SizedBox(height: 40),

                        // EDIT Button
                        _buildMenuButton('EDIT PROFILE', _toggleEditMode, isPrimary: true),
                      ],
                    ),
                  
                  const SizedBox(height: 20),

                  // --- BACK BUTTON (Always visible) ---
                  _buildMenuButton('BACK', () => Navigator.of(context).pop(), isPrimary: false),
                ],
              ),
            ),
    );
  }
  
  // Helper to display data in View Mode
  Widget _buildViewItem(String label, String value, {bool isLink = false}) {
    // ... (implementation of _buildViewItem remains the same)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'PressStart2P',
              fontSize: isLink ? 10.0 : 16.0,
              color: isLink ? Colors.blueGrey[200] : Colors.white,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Colors.redAccent),
        ],
      ),
    );
  }

  // Helper for text labels
  Widget _buildLabel(String text) {
    // ... (implementation of _buildLabel remains the same)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 12.0,
          color: Colors.yellowAccent,
        ),
      ),
    );
  }

  // Helper for text input fields
  Widget _buildTextField(TextEditingController controller, {String hint = ''}) {
    // ... (implementation of _buildTextField remains the same)
    return TextField(
      controller: controller,
      style: const TextStyle(
        fontFamily: 'PressStart2P',
        fontSize: 14.0,
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'PressStart2P',
          fontSize: 14.0,
          color: Colors.grey[600],
        ),
        filled: true,
        fillColor: Colors.black,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.redAccent, width: 2.0),
          borderRadius: BorderRadius.zero,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      ),
      onChanged: (_) {
        // Force UI update when avatar URL changes to refresh the CircleAvatar
        if (controller == _avatarUrlController) {
          setState(() {});
        }
      },
    );
  }

  // Helper for the gender dropdown
  Widget _buildGenderDropdown() {
    // ... (implementation of _buildGenderDropdown remains the same)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.redAccent, width: 2.0),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedGender,
          isExpanded: true,
          dropdownColor: Colors.black,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14.0,
            color: Colors.white,
          ),
          items: <String>['Not Set', 'Male', 'Female', 'Other']
              .map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedGender = newValue!;
            });
          },
        ),
      ),
    );
  }

  // Helper for buttons
  Widget _buildMenuButton(String text, VoidCallback onPressed, {bool isPrimary = true}) {
    // ... (implementation of _buildMenuButton remains the same)
    return SizedBox(
      width: 200,
      height: 40,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.yellowAccent : Colors.blueGrey[800],
          foregroundColor: Colors.black,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(0),
            side: BorderSide(
              color: isPrimary ? Colors.redAccent : Colors.grey, 
              width: 3.0
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 16.0,
            color: isPrimary ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}