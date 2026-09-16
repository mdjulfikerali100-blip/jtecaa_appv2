// lib/presentation/screens/profile/profile_edit_screen.dart
//
// Architecture Appendix C's ProfileEditForm, updated for L.1.1 (no
// hometown field) and L.1.2 (Current Location is free text). No Privacy
// Settings section anywhere (Appendix E — the feature was removed).
//
// ⚠️ Web-safe photo picking: uses `XFile.readAsBytes()` (cross-platform,
// including Web) rather than `dart:io File`, which doesn't exist on Web
// at all. Compression via `flutter_image_compress`'s
// `compressWithList()` is wrapped in a try/catch — that package's Web
// support has historically varied by version, so a failure there falls
// back to uploading the original (still size-checked) bytes rather than
// blocking the whole upload flow on an unverified platform API.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/company_types.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../core/utils/districts.dart';
import '../../../core/utils/job_departments.dart';
import '../../../core/utils/phone_validator.dart';
import '../../../data/models/user/user_private_model.dart';
import '../../../data/models/user/work_experience_model.dart';
import '../../providers/core_providers.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/common/batch_dropdown_field.dart';
import '../../widgets/common/blood_group_dropdown_field.dart';
import '../../widgets/common/drive_image.dart';
import '../../widgets/common/whatsapp_field.dart';
import '../../widgets/common/work_experience_bottom_sheet.dart';
import '../../widgets/common/work_experience_card.dart';

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myEditableProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load your profile: $e',
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(myEditableProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => _ProfileEditForm(initialProfile: profile),
      ),
    );
  }
}

class _ProfileEditForm extends ConsumerStatefulWidget {
  final UserProfileModel initialProfile;
  const _ProfileEditForm({required this.initialProfile});

  @override
  ConsumerState<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<_ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _companyController = TextEditingController();
  final _groupController = TextEditingController();
  final _designationController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _facebookController = TextEditingController();
  final _currentLocationController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillInputController = TextEditingController();

  late String _department;
  late String _batch;
  late String _bloodGroup;
  late String _district;
  late String _careerStatus;
  String? _companyType;
  String? _jobDepartment;
  String? _dateOfJoining;
  late List<WorkExperience> _workExperience;
  late List<String> _skills;
  String? _photoUrl;

  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _firstNameController.text = p.firstName;
    _lastNameController.text = p.lastName;
    _phoneController.text = p.phone;
    _whatsappController.text = p.whatsapp ?? '';
    _companyController.text = p.company ?? '';
    _groupController.text = p.groupOfCompanies ?? '';
    _designationController.text = p.designation ?? '';
    _linkedinController.text = p.linkedIn ?? '';
    _facebookController.text = p.facebook ?? '';
    _currentLocationController.text = p.currentLocation;
    _bioController.text = p.bio ?? '';

    _department = p.department;
    _batch = p.batch;
    _bloodGroup = p.bloodGroup;
    _district = p.district;
    _careerStatus = p.careerStatus;
    _companyType = p.companyType;
    _jobDepartment = p.jobDepartment;
    _dateOfJoining = p.dateOfJoining;
    _workExperience = List.of(p.workExperience);
    _skills = List.of(p.skills);
    _photoUrl = p.photoUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _companyController.dispose();
    _groupController.dispose();
    _designationController.dispose();
    _linkedinController.dispose();
    _facebookController.dispose();
    _currentLocationController.dispose();
    _bioController.dispose();
    _skillInputController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90);
    if (picked == null) {
      return;
    }

    setState(() => _isUploadingPhoto = true);
    try {
      final rawBytes = await picked.readAsBytes(); // cross-platform, incl. Web
      final compressed = await _compressImage(rawBytes);

      final newFileId =
          await ref.read(userRepositoryProvider).uploadProfilePhoto(
                uid: widget.initialProfile.uid,
                compressedBytes: compressed,
                oldFileId: _photoUrl,
              );
      setState(() => _photoUrl = newFileId);
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo upload failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<Uint8List> _compressImage(Uint8List bytes) async {
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 512,
        minHeight: 512,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      return compressed;
    } catch (_) {
      // ⚠️ flutter_image_compress's Web support has varied by version —
      // fall back to the original bytes rather than blocking the upload;
      // UserRepository.uploadProfilePhoto() still enforces
      // AppConstants.maxPhotoBytes as a hard size guard.
      return bytes;
    }
  }

  void _addOrEditExperience({WorkExperience? existing, int? index}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => WorkExperienceBottomSheet(
        initialExperience: existing,
        onSave: (exp) {
          setState(() {
            if (index != null) {
              _workExperience[index] = exp;
            } else {
              _workExperience.add(exp);
            }
          });
        },
      ),
    );
  }

  Future<void> _confirmDeleteExperience(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this experience?'),
        content: Text(_workExperience[index].companyName),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _workExperience.removeAt(index));
    }
  }

  void _addSkill(String value) {
    final skill = value.trim();
    if (skill.isEmpty || _skills.contains(skill)) {
      _skillInputController.clear();
      return;
    }
    setState(() {
      _skills.add(skill);
      _skillInputController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);

    final updated = widget.initialProfile.copyWith(
      firstName: _firstNameController.text.toUpperCase(),
      lastName: _lastNameController.text.toUpperCase(),
      department: _department,
      batch: _batch,
      bloodGroup: _bloodGroup,
      currentLocation: _currentLocationController.text.trim(),
      district: _district,
      phone: PhoneValidator.normalize(_phoneController.text) ?? '',
      whatsapp: _whatsappController.text.isEmpty
          ? null
          : PhoneValidator.normalize(_whatsappController.text),
      careerStatus: _careerStatus,
      companyType: _companyType,
      groupOfCompanies:
          _groupController.text.isEmpty ? null : _groupController.text,
      company: _companyController.text.isEmpty ? null : _companyController.text,
      designation: _designationController.text.isEmpty
          ? null
          : _designationController.text,
      jobDepartment: _jobDepartment,
      dateOfJoining: _dateOfJoining,
      linkedIn:
          _linkedinController.text.isEmpty ? null : _linkedinController.text,
      facebook:
          _facebookController.text.isEmpty ? null : _facebookController.text,
      workExperience: _workExperience,
      skills: _skills,
      bio: _bioController.text.isEmpty ? null : _bioController.text,
      photoUrl: _photoUrl,
    );

    try {
      await ref
          .read(userRepositoryProvider)
          .syncUserPublic(uid: updated.uid, privateData: updated.toMap());
      ref.invalidate(myEditableProfileProvider);
      ref.invalidate(profileViewProvider(updated.uid));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: theme.colorScheme.primary, width: 2)),
                  child: ClipOval(
                    child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? DriveImage(
                            fileId: _photoUrl!, width: 120, height: 120)
                        : Icon(Icons.person,
                            size: 56,
                            color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                if (_isUploadingPhoto)
                  const CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.black38,
                      child: CircularProgressIndicator(color: Colors.white)),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.camera_alt,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Personal Information'),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'First Name'),
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Last Name'),
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _department,
            decoration: const InputDecoration(labelText: 'Department'),
            items: Departments.all
                .map((d) => DropdownMenuItem(
                    value: d,
                    child: Text(Departments.getShortLabel(d),
                        maxLines: 1, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: (v) => setState(() => _department = v!),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          BatchDropdownField(
              value: _batch, onChanged: (v) => setState(() => _batch = v!)),
          const SizedBox(height: 12),
          BloodGroupDropdownField(
              value: _bloodGroup,
              onChanged: (v) => setState(() => _bloodGroup = v!)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _currentLocationController,
            decoration: const InputDecoration(
                labelText: 'Current Location',
                hintText: 'e.g. Mirpur-10, Dhaka'),
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          DropdownButtonFormField<String>(
            initialValue: _district,
            decoration: const InputDecoration(labelText: 'District'),
            items: Districts.all
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _district = v!),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Contact Information'),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Contact Number'),
            keyboardType: TextInputType.phone,
            validator: PhoneValidator.getErrorMessage,
          ),
          const SizedBox(height: 12),
          WhatsAppField(controller: _whatsappController),
          const SizedBox(height: 12),
          TextFormField(
            controller: _linkedinController,
            decoration: const InputDecoration(labelText: 'LinkedIn URL'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _facebookController,
            decoration: const InputDecoration(labelText: 'Facebook URL'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Current Job Information'),
          DropdownButtonFormField<String>(
            initialValue: _careerStatus,
            decoration: const InputDecoration(labelText: 'Current Status'),
            items: CareerStatusCategories.getDropdownItems(),
            onChanged: (v) => setState(() => _careerStatus = v!),
            validator: (v) => v == null ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _companyType,
            decoration: const InputDecoration(labelText: 'Company Type'),
            items: CompanyTypes.all
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _companyType = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _groupController,
            decoration: const InputDecoration(
                labelText: 'Group of Companies (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: 'Company Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _designationController,
            decoration:
                const InputDecoration(labelText: 'Designation / Position'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _jobDepartment,
            decoration: const InputDecoration(labelText: 'Job Department'),
            items: JobDepartments.all
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _jobDepartment = v),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date of Joining'),
            subtitle: Text(_dateOfJoining ?? 'Not set'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1980),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _dateOfJoining =
                    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
              }
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _sectionHeader(theme, 'Work Experience')),
              TextButton.icon(
                onPressed: () => _addOrEditExperience(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Experience'),
              ),
            ],
          ),
          if (_workExperience.isEmpty)
            Text(
              "No experience added yet. Tap 'Add Experience' to get started.",
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            ...List.generate(_workExperience.length, (i) {
              return Dismissible(
                key: ValueKey('wx_$i${_workExperience[i].companyName}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  await _confirmDeleteExperience(i);
                  return false; // deletion handled via setState above
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: theme.colorScheme.errorContainer,
                  child: Icon(Icons.delete, color: theme.colorScheme.error),
                ),
                child: WorkExperienceCard(
                  experience: _workExperience[i],
                  isEditable: true,
                  onEdit: () => _addOrEditExperience(
                      existing: _workExperience[i], index: i),
                  onDelete: () => _confirmDeleteExperience(i),
                ),
              );
            }),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'Skills'),
          TextField(
            controller: _skillInputController,
            decoration:
                const InputDecoration(hintText: 'Type a skill and press Enter'),
            onSubmitted: _addSkill,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _skills
                .map((s) => Chip(
                    label: Text(s),
                    onDeleted: () => setState(() => _skills.remove(s))))
                .toList(),
          ),
          const SizedBox(height: 24),
          _sectionHeader(theme, 'About Me'),
          TextFormField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
                hintText: 'Tell fellow alumni about yourself...'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56)),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('SAVE CHANGES'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
    );
  }
}
