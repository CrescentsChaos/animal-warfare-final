// lib/edit_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';

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

  // Controllers
  final TextEditingController _usernameController =
      TextEditingController(); // readonly
  final TextEditingController _displayNameController = TextEditingController();

  // State
  String? _selectedGender;
  String? _selectedFrame;
  // UI State
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = await _authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() {
        _currentUser = user;
        _usernameController.text = user.username;
        _displayNameController.text = user.displayName;
        _selectedGender = user.gender != 'N/A' && user.gender.isNotEmpty
            ? user.gender
            : null;
        _selectedFrame = user.avatarFrame.isNotEmpty ? user.avatarFrame : null;

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
      setState(() {
        _pickedAvatarFile = File(image.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null || _isLoading) return;
    setState(() => _isLoading = true);

    final newAvatarPath = _pickedAvatarFile?.path ?? _currentUser!.avatar;

    final userState = Provider.of<UserState>(context, listen: false);
    await userState.updateProfile(
      avatar: newAvatarPath,
      gender: _selectedGender ?? 'N/A',
      displayName: _displayNameController.text.trim(),
      avatarIconKey:
          _currentUser!.avatarIconKey, // Keep existing generic icon key
      faction: _currentUser!.faction, // Preserve empty faction string
      title: _currentUser!.title, // Preserve empty title string
      bio: _currentUser!.bio, // Preserve empty bio string
      avatarFrame: _selectedFrame ?? '',
      profileBackground: _currentUser!.profileBackground,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Identity Updated Successfully',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: AppColors.surface,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'EDIT IDENTITY',
          style: AppTextStyles.headline(context, baseSize: 14),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
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
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _buildAvatarPreview()),
                    SizedBox(height: 32.h),

                    _buildSectionHeader('BIOMETRIC DATA'),
                    SizedBox(height: 16.h),
                    _buildDisabledField(
                      'USERNAME',
                      _usernameController.text,
                      Icons.lock,
                    ),
                    SizedBox(height: 16.h),
                    _buildTextField(
                      'DISPLAY NAME',
                      _displayNameController,
                      Icons.badge,
                    ),
                    SizedBox(height: 16.h),
                    _buildDropdown(
                      'GENDER',
                      _selectedGender,
                      ['MALE', 'FEMALE', 'OTHER'],
                      (v) => setState(() => _selectedGender = v),
                    ),
                    SizedBox(height: 16.h),
                    _buildDropdown(
                      'AVATAR FRAME',
                      _selectedFrame,
                      <String>{
                        '',
                        ...(_currentUser?.unlockedFrames ?? []),
                        ?_selectedFrame,
                      }.toList(),
                      (v) => setState(() => _selectedFrame = v),
                    ),

                    SizedBox(height: 32.h),

                    _buildSaveButton(),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAvatarPreview() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: _pickedAvatarFile != null
                      ? AppColors.highlight
                      : AppColors.primary,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_pickedAvatarFile != null
                                ? AppColors.highlight
                                : AppColors.primary)
                            .withValues(alpha: 0.2),
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
                  ? Icon(Icons.person, size: 60.w, color: AppColors.textMuted)
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
                    color: AppColors.highlight,
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
        SizedBox(height: 12.h),
        Text(
          'UPDATE AVATAR',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9.sp,
            color: AppColors.highlight,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 14.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledField(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20.sp),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20.sp),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 8.h),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: AppColors.surfaceVariant,
              hint: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Text(
                  'Not selected',
                  style: GoogleFonts.inter(
                    color: AppColors.textMuted,
                    fontSize: 12.sp,
                  ),
                ),
              ),
              icon: Padding(
                padding: EdgeInsets.only(right: 14.w),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                ),
              ),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13.sp),
              items: items.map((g) {
                String displayString = 'NONE';
                if (g.isNotEmpty) {
                  displayString = g
                      .split('_')
                      .map(
                        (w) => w.isNotEmpty
                            ? '${w[0].toUpperCase()}${w.substring(1)}'
                            : '',
                      )
                      .join(' ');
                }
                return DropdownMenuItem(
                  value: g,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    child: Text(displayString),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: Size(double.infinity, 54.h),
        elevation: 0,
      ),
      child: const Text(
        'SAVE CHANGES',
        style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
      ),
    );
  }
}
