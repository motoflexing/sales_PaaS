import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/models/enums.dart';
import '../providers/user_management_provider.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  UserRole _role = UserRole.employee;
  String? _managerId;
  bool _obscure = true;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _password]) {
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

    setState(() => _isSaving = true);
    try {
      final user =
          await ref.read(userManagementProvider.notifier).createUser(
                name: _name.text,
                email: _email.text,
                phone: _phone.text,
                role: _role,
                password: _password.text,
                managerId: _role == UserRole.employee ? _managerId : null,
              );
      if (!mounted) return;
      context.showInfo('${user.name} can now sign in.');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) context.showError(describeError(error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final managersAsync = ref.watch(activeManagersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Add user')),
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
              title: 'Profile',
              padding: EdgeInsets.only(bottom: 12),
            ),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email *',
                hintText: 'name@anethix.com',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
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
            const SectionHeader(title: 'Access'),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: UserRole.manager,
                  child: Text('Manager'),
                ),
                DropdownMenuItem(
                  value: UserRole.employee,
                  child: Text('Employee'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _role = value;
                  if (value != UserRole.employee) _managerId = null;
                });
              },
            ),
            if (_role == UserRole.employee) ...[
              const SizedBox(height: 14),
              managersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(child: InlineSpinner()),
                ),
                error: (_, __) => Text(
                  'Could not load the manager list.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
                data: (managers) => DropdownButtonFormField<String>(
                  initialValue: _managerId,
                  decoration: const InputDecoration(
                    labelText: 'Assign to manager *',
                    prefixIcon: Icon(Icons.supervisor_account_outlined),
                  ),
                  items: [
                    for (final UserModel manager in managers)
                      DropdownMenuItem(
                        value: manager.id,
                        child: Text(manager.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _managerId = value),
                  validator: (value) =>
                      Validators.dropdown(value, field: 'manager'),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Temporary password *',
                helperText: 'They should change this after first sign-in.',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (value) => Validators.password(value),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const InlineSpinner(size: 16)
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
