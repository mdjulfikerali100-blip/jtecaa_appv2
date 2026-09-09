// lib/presentation/screens/student/my_profile_screen.dart
//
// Architecture §M.7 — "Unlike Jobs/News... a Student may edit their own
// info whenever they like." No restriction window, no approval step —
// every field here can be changed and saved immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/districts.dart';
import '../../../core/utils/phone_validator.dart';
import '../../../data/models/user/student_profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common/blood_group_dropdown_field.dart';

/// Cache-first fetch of the signed-in Student's own profile
/// (StudentProfileRepository already implements the Hive-first, 12h-TTL
/// logic internally per §M.7 — this provider is a thin Riverpod wrapper).
final myStudentProfileProvider =
    FutureProvider.autoDispose<StudentProfileModel>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) {
    throw StateError('myStudentProfileProvider watched while signed out.');
  }
  return ref.watch(studentProfileRepositoryProvider).getMyProfile(uid);
});

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myStudentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
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
                  onPressed: () => ref.invalidate(myStudentProfileProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (profile) => _MyProfileForm(profile: profile),
      ),
    );
  }
}

class _MyProfileForm extends ConsumerStatefulWidget {
  final StudentProfileModel profile;
  const _MyProfileForm({required this.profile});

  @override
  ConsumerState<_MyProfileForm> createState() => _MyProfileFormState();
}

class _MyProfileFormState extends ConsumerState<_MyProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  String? _bloodGroup;
  String? _district;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _locationController =
        TextEditingController(text: widget.profile.currentLocation ?? '');
    _bloodGroup = widget.profile.bloodGroup;
    _district = widget.profile.district;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await ref.read(studentProfileRepositoryProvider).updateMyProfile(
        widget.profile.uid,
        {
          'full_name': _fullNameController.text.trim().toUpperCase(),
          'phone': PhoneValidator.normalize(_phoneController.text) ?? '',
          'blood_group': _bloodGroup ?? '',
          'district': _district ?? '',
          'current_location': _locationController.text.trim(),
        },
      );
      ref.invalidate(myStudentProfileProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextFormField(
            controller: _fullNameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
            textCapitalization: TextCapitalization.characters,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          // Email is not editable — it's the Firebase Auth identity, not
          // a Sheet field a Student can freely change from this screen.
          TextFormField(
            initialValue: widget.profile.email,
            decoration: const InputDecoration(labelText: 'Email'),
            enabled: false,
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: widget.profile.batch,
            decoration: const InputDecoration(labelText: 'Batch'),
            enabled: false, // batch is fixed at signup, matches the verified ID
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Contact Number', hintText: '0171XXXXXXX'),
            validator: PhoneValidator.getErrorMessage,
          ),
          const SizedBox(height: 16),
          BloodGroupDropdownField(
            value: _bloodGroup,
            onChanged: (v) => setState(() => _bloodGroup = v),
            validator: (v) => null, // optional for Students, §M.4
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _district,
            decoration: const InputDecoration(labelText: 'District (optional)'),
            items: Districts.all
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (v) => setState(() => _district = v),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Current Location (optional)',
              hintText: 'e.g. Mirpur-10, Dhaka',
            ),
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56)),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('SAVE CHANGES'),
          ),
        ],
      ),
    );
  }
}
