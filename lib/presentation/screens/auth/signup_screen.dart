// lib/presentation/screens/auth/signup_screen.dart
//
// Architecture §M.2 (Role Tab) + §7.1 (Auth flow) + Appendix H/§M.3 (ID
// checksums). One Form, one `SignupRole` toggle (SegmentedButton, not a
// separate TabController+TabBarView) — simpler state management since
// most controllers are shared and only a handful of fields differ
// between roles.
//
// ⚠️ GAPS FILLED vs. the Master Prompt's abbreviated Phase 3 bullet list:
// the bullet list omits Phone and Career Status for the Alumni tab, but
// `UserProfileModel` (Phase 1) requires both as non-nullable constructor
// params, and Architecture §7.1's own required-fields rule lists
// "Contact Number" and "Career Status" as mandatory. Both fields are
// included below — without them `profile.toMap()` would need force-unwrap
// placeholders, which violates the "no placeholders" rule far more than
// a slightly longer form does.
//
// ⚠️ SPEC CONTRADICTION RESOLVED: the Master Prompt's bullet list says
// "Current Location, District dropdowns" (implying both are dropdowns),
// but Architecture Appendix L.1.2 explicitly changed Current Location to
// a free-text field ("CHANGED: Current Location is now a free-text
// field"). L.1.2 is the more specific, explicitly-flagged update, so
// Current Location is a TextFormField here, District remains a dropdown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/alumni_id_validator.dart';
import '../../../core/utils/batch_helper.dart';
import '../../../core/utils/career_status_categories.dart';
import '../../../core/utils/departments_helper.dart';
import '../../../core/utils/districts.dart';
import '../../../core/utils/phone_validator.dart';
import '../../../core/utils/student_id_validator.dart';
import '../../../data/models/user/role_model.dart';
import '../../../data/models/user/student_profile_model.dart';
import '../../../data/models/user/user_private_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../widgets/common/batch_dropdown_field.dart';
import '../../widgets/common/blood_group_dropdown_field.dart';
import 'verification_gate_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Shared controllers (both roles)
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedBatch;

  // Alumni-only controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _alumniPhoneController = TextEditingController();
  final _alumniLocationController = TextEditingController();
  String? _department;
  String? _bloodGroupAlumni;
  String? _districtAlumni;
  String? _careerStatus;

  // Student-only controllers
  final _fullNameController = TextEditingController();
  final _studentPhoneController = TextEditingController();
  final _studentLocationController = TextEditingController();
  String? _bloodGroupStudent;
  String? _districtStudent;

  SignupRole _selectedRole = SignupRole.alumni;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _alumniPhoneController.dispose();
    _alumniLocationController.dispose();
    _fullNameController.dispose();
    _studentPhoneController.dispose();
    _studentLocationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final batchNumber = BatchHelper.extractBatchNumber(_selectedBatch ?? '');

    // Step 1: offline checksum verification — Appendix H/§M.3, no
    // network call at all, must pass before an Auth account is even
    // attempted.
    if (_selectedRole == SignupRole.alumni) {
      final result =
          AlumniIdValidator.validate(_idController.text, batchNumber);
      if (!result.isValid) {
        _showError(result.errorMessage!);
        return;
      }
    } else {
      final result =
          StudentIdValidator.validate(_idController.text, batchNumber);
      if (!result.isValid) {
        _showError(result.errorMessage!);
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // Step 2: create the Firebase Auth account (shared by both roles).
    final uid = await ref.read(authControllerProvider.notifier).createAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (uid == null) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final error = ref.read(authControllerProvider).error;
      _showError(
          error?.toString() ?? 'Could not create account. Please try again.');
      return;
    }

    // Step 3: create the profile in the correct backend for this role.
    // ⚠️ Cross-system limitation, not specified anywhere in Architecture:
    // Firestore (Alumni) and Google Sheets (Student) can't share one
    // atomic transaction. If this step fails after the Auth account
    // already exists, we roll back the Auth account (best-effort) so the
    // same email can be retried cleanly rather than being permanently
    // stuck in a half-created state.
    try {
      if (_selectedRole == SignupRole.alumni) {
        final now = DateTime.now();
        final profile = UserProfileModel(
          uid: uid,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          email: _emailController.text.trim(),
          department: _department!,
          batch: _selectedBatch!,
          bloodGroup: _bloodGroupAlumni!,
          district: _districtAlumni!,
          currentLocation: _alumniLocationController.text.trim(),
          phone: PhoneValidator.normalize(_alumniPhoneController.text) ?? '',
          careerStatus: _careerStatus!,
          isVerified: false,
          // The offline checksum (Appendix H) IS the activation gate now
          // that alumni_registry/claimed no longer exist (§4.2.D) — so an
          // account that passed checksum validation is activated
          // immediately, with no separate admin-approval step.
          isActivated: true,
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(userRepositoryProvider).signUpAlumni(profile: profile);
      } else {
        await ref.read(userRepositoryProvider).writeStudentRole(uid);
        final now = DateTime.now();
        final profile = StudentProfileModel(
          uid: uid,
          fullName: _fullNameController.text.trim().toUpperCase(),
          phone: PhoneValidator.normalize(_studentPhoneController.text) ?? '',
          batch: _selectedBatch!,
          bloodGroup: _bloodGroupStudent,
          district: _districtStudent,
          currentLocation: _studentLocationController.text.trim().isEmpty
              ? null
              : _studentLocationController.text.trim(),
          email: _emailController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
        await ref.read(studentProfileRepositoryProvider).createProfile(profile);
      }
    } catch (e) {
      await ref.read(authControllerProvider.notifier).rollbackAccount();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Could not finish signup, please try again: $e');
      return;
    }

    // Step 4: send verification email (same mechanism for both roles,
    // §M.1) and move to the gate screen.
    await ref.read(authControllerProvider.notifier).sendEmailVerification();

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VerificationGateScreen()),
      (route) => false,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlumni = _selectedRole == SignupRole.alumni;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // §M.2 — Role Tab
              Center(
                child: SegmentedButton<SignupRole>(
                  segments: const [
                    ButtonSegment(
                        value: SignupRole.alumni,
                        label: Text('Alumni'),
                        icon: Icon(Icons.school)),
                    ButtonSegment(
                        value: SignupRole.student,
                        label: Text('Student'),
                        icon: Icon(Icons.person)),
                  ],
                  selected: {_selectedRole},
                  onSelectionChanged: (s) =>
                      setState(() => _selectedRole = s.first),
                ),
              ),
              const SizedBox(height: 24),

              // Shared: ID + Batch (Appendix H / §M.3)
              TextFormField(
                controller: _idController,
                decoration: InputDecoration(
                  labelText: isAlumni ? 'Alumni ID' : 'Student ID',
                  hintText:
                      isAlumni ? 'jtecAAAAAKZZalumni' : 'jtecABCDEFGHstudent',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ID is required' : null,
              ),
              const SizedBox(height: 12),
              BatchDropdownField(
                value: _selectedBatch,
                onChanged: (v) => setState(() => _selectedBatch = v),
              ),
              const SizedBox(height: 24),

              // Role-specific name field(s)
              if (isAlumni) ...[
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
              ] else
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'At least 6 characters'
                    : null,
              ),
              const SizedBox(height: 24),

              if (isAlumni)
                ..._buildAlumniOnlyFields()
              else
                ..._buildStudentOnlyFields(),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56)),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('CREATE ACCOUNT'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAlumniOnlyFields() {
    return [
      // ⚠️ Appendix G.2 rule: value is the raw code, child shows the
      // short label — never render the raw department code directly.
      DropdownButtonFormField<String>(
        value: _department,
        decoration: const InputDecoration(labelText: 'Department'),
        items: Departments.all
            .map((d) => DropdownMenuItem(
                  value: d,
                  child: Text(Departments.getShortLabel(d),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: (v) => setState(() => _department = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      BloodGroupDropdownField(
        value: _bloodGroupAlumni,
        onChanged: (v) => setState(() => _bloodGroupAlumni = v),
      ),
      const SizedBox(height: 12),
      // ⚠️ Appendix L.1.2 — free-text, not a district-style dropdown.
      TextFormField(
        controller: _alumniLocationController,
        decoration: const InputDecoration(
          labelText: 'Current Location',
          hintText: 'e.g. Mirpur-10, Dhaka',
        ),
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      ),
      DropdownButtonFormField<String>(
        value: _districtAlumni,
        decoration: const InputDecoration(labelText: 'District'),
        items: Districts.all
            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
            .toList(),
        onChanged: (v) => setState(() => _districtAlumni = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _alumniPhoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Contact Number', hintText: '0171XXXXXXX'),
        validator: PhoneValidator.getErrorMessage,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _careerStatus,
        decoration: const InputDecoration(labelText: 'Current Status'),
        items: CareerStatusCategories.getDropdownItems(),
        onChanged: (v) => setState(() => _careerStatus = v),
        validator: (v) => v == null ? 'Required' : null,
      ),
    ];
  }

  List<Widget> _buildStudentOnlyFields() {
    return [
      TextFormField(
        controller: _studentPhoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
            labelText: 'Contact Number', hintText: '0171XXXXXXX'),
        validator: PhoneValidator.getErrorMessage,
      ),
      const SizedBox(height: 12),
      // §M.4: blood_group/district/current_location are all optional for
      // Students, so the shared dropdown widgets' default "required"
      // validator is overridden to `null` (always valid) here.
      BloodGroupDropdownField(
        value: _bloodGroupStudent,
        onChanged: (v) => setState(() => _bloodGroupStudent = v),
        validator: (v) => null,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _districtStudent,
        decoration: const InputDecoration(labelText: 'District (optional)'),
        items: Districts.all
            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
            .toList(),
        onChanged: (v) => setState(() => _districtStudent = v),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _studentLocationController,
        decoration: const InputDecoration(
          labelText: 'Current Location (optional)',
          hintText: 'e.g. Mirpur-10, Dhaka',
        ),
        textCapitalization: TextCapitalization.words,
        maxLength: 80,
      ),
    ];
  }
}
