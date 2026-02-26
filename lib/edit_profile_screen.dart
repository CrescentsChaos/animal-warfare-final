// lib/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animal_warfare/theme.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUser = user;
        _usernameController.text = user.username;
        _selectedGender = user.gender != 'N/A' ? user.gender : null;
        if (user.avatar.isNotEmpty && user.avatar != 'default') {
          final file = File(user.avatar);
          if (file.existsSync()) {
            _pickedAvatarFile = file;
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null && mounted) {
      setState(() => _pickedAvatarFile = File(image.path));
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null || _isLoading) return;
    setState(() => _isLoading = true);

    final newAvatarPath = _pickedAvatarFile?.path ?? _currentUser!.avatar;
    await _authService.updateProfile(
      _currentUser!.username,
      avatar: newAvatarPath,
      gender: _selectedGender ?? 'N/A',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Identity Updated Successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.secondaryButtonColor,
      appBar: AppBar(title: const Text('EDIT IDENTITY'), elevation: 0),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.85),
              BlendMode.darken,
            ),
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.highlightColor,
                ),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 24.h),
                child: Column(
                  children: [
                    _buildAvatarSelector(),
                    SizedBox(height: 40.h),
                    _buildSectionHeader('BIOMETRIC DATA'),
                    SizedBox(height: 20.h),
                    _buildDisabledField(
                      'USERNAME',
                      _usernameController.text,
                      Icons.lock,
                    ),
                    SizedBox(height: 16.h),
                    _buildGenderSelector(),
                    SizedBox(height: 60.h),
                    _buildSaveButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarSelector() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 140.w,
              height: 140.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.highlightColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.highlightColor.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                image: _pickedAvatarFile != null
                    ? DecorationImage(
                        image: FileImage(_pickedAvatarFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _pickedAvatarFile == null
                  ? Icon(
                      Icons.person,
                      size: 70.w,
                      color: AppColors.highlightColor.withOpacity(0.5),
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.highlightColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          'UPDATE AVATAR',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 8.sp,
            color: AppColors.highlightColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 3.w, height: 14.h, color: AppColors.highlightColor),
        SizedBox(width: 12.w),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9.sp,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledField(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white24, size: 18.w),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 8.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 13.sp,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.highlightColor.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedGender,
          dropdownColor: AppColors.secondaryButtonColor,
          hint: Text(
            'SELECT GENDER',
            style: TextStyle(color: Colors.white24, fontSize: 11.sp),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.highlightColor,
          ),
          style: TextStyle(color: Colors.white, fontSize: 13.sp),
          items: [
            'MALE',
            'FEMALE',
            'OTHER',
          ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (val) => setState(() => _selectedGender = val),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.highlightColor,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size(double.infinity, 54.h),
        elevation: 8,
        shadowColor: AppColors.highlightColor.withOpacity(0.4),
      ),
      child: const Text(
        'SYNCHRONIZE DATA',
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
      ),
    );
  }
}
