// lib/presentation/screens/jobs/post_job_screen.dart
//
// Architecture §7.5 (Post Job Form) — Title, Company, Description,
// Deadline, and 4 apply methods with "minimum 1 required" validation.
// Doubles as the Edit form when [existingJob] is passed in.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/job/job_post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/jobs_provider.dart';

class PostJobScreen extends ConsumerStatefulWidget {
  final JobPostModel? existingJob;

  const PostJobScreen({super.key, this.existingJob});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();

  DateTime? _deadline;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existingJob != null;

  @override
  void initState() {
    super.initState();
    final job = widget.existingJob;
    if (job != null) {
      _titleController.text = job.title;
      _companyController.text = job.company;
      _descriptionController.text = job.description ?? '';
      _linkController.text = job.applyLink ?? '';
      _emailController.text = job.applyEmail ?? '';
      _phoneController.text = job.applyPhone ?? '';
      _whatsappController.text = job.applyWhatsapp ?? '';
      _deadline = DateTime.tryParse(job.deadline);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  bool get _hasAnyApplyMethod =>
      _linkController.text.trim().isNotEmpty ||
      _emailController.text.trim().isNotEmpty ||
      _phoneController.text.trim().isNotEmpty ||
      _whatsappController.text.trim().isNotEmpty;

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a deadline')),
      );
      return;
    }
    if (!_hasAnyApplyMethod) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'At least one apply method (Link, Email, Phone, or WhatsApp) is required')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final deadlineStr =
        '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}';

    try {
      if (_isEditing) {
        final body = JobPostModel.toEditBody(
          id: widget.existingJob!.id,
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          applyLink: _linkController.text.trim().isEmpty
              ? null
              : _linkController.text.trim(),
          applyEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          applyPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          applyWhatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
        );
        await ref.read(jobRepositoryProvider).editJob(body);
      } else {
        final uid = ref.read(currentUidProvider);
        if (uid == null) {
          throw StateError('Not signed in.');
        }
        // Appendix L.2.1 "client computes, server just stores" — pull
        // the poster's name/batch from their own cache-first profile
        // read rather than a fresh Firestore query.
        final myProfile =
            await ref.read(userRepositoryProvider).getMyProfile(uid);
        final body = JobPostModel.toPostBody(
          title: _titleController.text.trim(),
          company: _companyController.text.trim(),
          description: _descriptionController.text.trim(),
          deadline: deadlineStr,
          applyLink: _linkController.text.trim().isEmpty
              ? null
              : _linkController.text.trim(),
          applyEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          applyPhone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          applyWhatsapp: _whatsappController.text.trim().isEmpty
              ? null
              : _whatsappController.text.trim(),
          postedByUid: uid,
          postedByName: myProfile.fullName,
          postedByBatch: myProfile.batch,
        );
        await ref.read(jobRepositoryProvider).postJob(body);
      }

      ref.invalidate(activeJobsProvider);
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Job' : 'Post a Job')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Job Title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(labelText: 'Company *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Deadline *'),
              subtitle: Text(
                _deadline != null
                    ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
                    : 'Not set',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDeadline,
            ),
            const SizedBox(height: 16),
            Text(
              'Apply Methods (at least one required)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _linkController,
              decoration: const InputDecoration(
                  labelText: 'Apply Link', hintText: 'https://...'),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Apply Email', hintText: 'hr@company.com'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                  labelText: 'Apply Phone', hintText: '0171XXXXXXX'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsappController,
              decoration: const InputDecoration(
                  labelText: 'Apply WhatsApp', hintText: '0171XXXXXXX'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),
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
                  : Text(_isEditing ? 'UPDATE JOB' : 'POST JOB'),
            ),
          ],
        ),
      ),
    );
  }
}
