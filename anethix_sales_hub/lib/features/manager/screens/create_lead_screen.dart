import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/priority_badge.dart';
import '../../../shared/models/enums.dart';
import '../../../shared/providers/shared_providers.dart';
import '../../auth/providers/auth_provider.dart';

class CreateLeadScreen extends ConsumerStatefulWidget {
  const CreateLeadScreen({super.key});

  @override
  ConsumerState<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends ConsumerState<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _company = TextEditingController();
  final _contactPerson = TextEditingController();
  final _email = TextEditingController();
  final _alternatePhone = TextEditingController();
  final _leadType = TextEditingController();
  final _remark = TextEditingController();

  String? _location;
  String? _industry;
  String? _source;
  LeadPriority _priority = LeadPriority.medium;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _company,
      _contactPerson,
      _email,
      _alternatePhone,
      _leadType,
      _remark,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      context.showError('Please fix the highlighted fields.');
      return;
    }

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(leadRepositoryProvider).createLead(
            name: _name.text,
            phone: _phone.text,
            priority: _priority,
            createdBy: user.id,
            company: _company.text,
            contactPerson: _contactPerson.text,
            email: _email.text,
            alternatePhone: _alternatePhone.text,
            location: _location,
            industry: _industry,
            source: _source,
            leadType: _leadType.text,
            managerRemark: _remark.text,
          );
      ref.bumpDataRevision();
      if (!mounted) return;
      context.showInfo('Lead saved as a draft.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add lead')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            AppConstants.pagePadding,
            32,
          ),
          children: [
            const SectionHeader(
              title: 'Contact',
              padding: EdgeInsets.only(bottom: 12),
            ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Lead name *',
                hintText: 'e.g. ERP rollout enquiry',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone *',
                hintText: '10-digit mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: Validators.phone,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _alternatePhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Alternate phone',
                prefixIcon: Icon(Icons.phone_forwarded_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _company,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Company',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _contactPerson,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Contact person',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: (value) =>
                  Validators.email(value, isRequired: false),
            ),
            const SectionHeader(title: 'Qualification'),
            DropdownButtonFormField<String>(
              initialValue: _location,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: [
                for (final city in AppConstants.cities)
                  DropdownMenuItem(value: city, child: Text(city)),
              ],
              onChanged: (value) => setState(() => _location = value),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _industry,
              decoration: const InputDecoration(
                labelText: 'Industry',
                prefixIcon: Icon(Icons.business_center_outlined),
              ),
              items: [
                for (final industry in AppConstants.industries)
                  DropdownMenuItem(value: industry, child: Text(industry)),
              ],
              onChanged: (value) => setState(() => _industry = value),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: const InputDecoration(
                labelText: 'Source',
                prefixIcon: Icon(Icons.share_outlined),
              ),
              items: [
                for (final source in AppConstants.sources)
                  DropdownMenuItem(value: source, child: Text(source)),
              ],
              onChanged: (value) => setState(() => _source = value),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _leadType,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Lead type',
                hintText: AppConstants.leadTypes.join(', '),
                prefixIcon: const Icon(Icons.category_outlined),
              ),
            ),
            const SectionHeader(title: 'Priority'),
            PrioritySelector(
              value: _priority,
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SectionHeader(title: 'Remark'),
            TextFormField(
              controller: _remark,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Context for whoever claims this lead',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const InlineSpinner(size: 16)
                  : const Icon(Icons.save_outlined),
              label: const Text('Save as draft'),
            ),
            const SizedBox(height: 8),
            Text(
              'Drafts stay private until you publish them from the Leads tab.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
