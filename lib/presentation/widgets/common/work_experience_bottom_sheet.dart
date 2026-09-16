// lib/presentation/widgets/common/work_experience_bottom_sheet.dart
//
// Architecture Appendix C + L.1.5 — Add/Edit Work Experience form.
//
// ⚠️ Uses Start/End Date pickers, NOT the free-text "duration" field from
// Appendix C's original code. Appendix L.1.5 explicitly replaced that:
// "added startDate/endDate (nullable = still running) so 'Total Work
// Experience' can be computed accurately instead of parsing the old
// free-text duration string, which can't be summed reliably." Since
// `WorkExperience` (Phase 1) was already built with startDate/endDate,
// this form matches that model from the start.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/company_types.dart';
import '../../../core/utils/job_departments.dart';
import '../../../data/models/user/work_experience_model.dart';

class WorkExperienceBottomSheet extends StatefulWidget {
  final WorkExperience? initialExperience;
  final ValueChanged<WorkExperience> onSave;

  const WorkExperienceBottomSheet({
    super.key,
    this.initialExperience,
    required this.onSave,
  });

  @override
  State<WorkExperienceBottomSheet> createState() =>
      _WorkExperienceBottomSheetState();
}

class _WorkExperienceBottomSheetState extends State<WorkExperienceBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _groupController = TextEditingController();
  final _designationController = TextEditingController();

  late String _companyType;
  late String _jobDepartment;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isCurrentJob = false;

  @override
  void initState() {
    super.initState();
    final exp = widget.initialExperience;
    _companyType = exp?.companyType ?? CompanyTypes.all.first;
    _jobDepartment = exp?.jobDepartment ?? JobDepartments.all.first;
    _companyController.text = exp?.companyName ?? '';
    _groupController.text = exp?.groupOfCompanies ?? '';
    _designationController.text = exp?.designation ?? '';
    _startDate = exp?.startDate;
    _endDate = exp?.endDate;
    _isCurrentJob = exp != null && exp.endDate == null;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _groupController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: DateTime(1980),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }
    if (!_isCurrentJob && _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please select an end date, or check "I currently work here"')),
      );
      return;
    }

    final experience = WorkExperience(
      companyType: _companyType,
      groupOfCompanies: _groupController.text.trim().isEmpty
          ? null
          : _groupController.text.trim(),
      companyName: _companyController.text.trim(),
      designation: _designationController.text.trim(),
      jobDepartment: _jobDepartment,
      startDate: _startDate!,
      endDate: _isCurrentJob ? null : _endDate,
    );
    widget.onSave(experience);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: theme.colorScheme.outline,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.initialExperience == null
                  ? 'Add Work Experience'
                  : 'Edit Work Experience',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _companyType,
              decoration: const InputDecoration(
                  labelText: 'Company Type *',
                  prefixIcon: Icon(Icons.business)),
              items: CompanyTypes.all
                  .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t,
                          maxLines: 1, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _companyType = v!),
              validator: (v) => v == null ? 'Select company type' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupController,
              decoration: const InputDecoration(
                labelText: 'Group of Companies (optional)',
                prefixIcon: Icon(Icons.account_tree),
                hintText: 'e.g., Square Group, Beximco Group',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                prefixIcon: Icon(Icons.apartment),
                hintText: 'e.g., Square Textiles Ltd.',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Company name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _designationController,
              decoration: const InputDecoration(
                labelText: 'Designation / Position *',
                prefixIcon: Icon(Icons.work),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Designation is required'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _jobDepartment,
              decoration: const InputDecoration(
                  labelText: 'Job Department *',
                  prefixIcon: Icon(Icons.people)),
              items: JobDepartments.all
                  .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d,
                          maxLines: 1, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _jobDepartment = v!),
              validator: (v) => v == null ? 'Select department' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(isStart: true),
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Start Date *'),
                      child: Text(_startDate != null
                          ? dateFmt.format(_startDate!)
                          : 'Select'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap:
                        _isCurrentJob ? null : () => _pickDate(isStart: false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Date'),
                      child: Text(
                        _isCurrentJob
                            ? 'Present'
                            : (_endDate != null
                                ? dateFmt.format(_endDate!)
                                : 'Select'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('I currently work here'),
              value: _isCurrentJob,
              onChanged: (v) => setState(() {
                _isCurrentJob = v ?? false;
                if (_isCurrentJob) {
                  _endDate = null;
                }
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56)),
              child: Text(widget.initialExperience == null
                  ? 'ADD EXPERIENCE'
                  : 'UPDATE EXPERIENCE'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
