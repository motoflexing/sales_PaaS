class Validators {
  const Validators._();

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  // Indian mobile numbers are 10 digits starting 6-9.
  static final RegExp _indianMobile = RegExp(r'^[6-9]\d{9}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final empty = required(value, field: 'Name');
    if (empty != null) return empty;
    if (value!.trim().length < 2) return 'Enter the full name';
    return null;
  }

  static String? email(String? value, {bool isRequired = true}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return isRequired ? 'Email is required' : null;
    if (!_email.hasMatch(trimmed)) return 'Enter a valid email address';
    return null;
  }

  static String? phone(String? value, {bool isRequired = true}) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return isRequired ? 'Phone number is required' : null;
    if (!_indianMobile.hasMatch(digits)) {
      return 'Enter a 10-digit mobile number starting with 6-9';
    }
    return null;
  }

  static String? password(String? value, {int min = 6}) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < min) return 'Use at least $min characters';
    return null;
  }

  static String? dropdown(Object? value, {String field = 'This field'}) {
    if (value == null) return 'Select a $field';
    return null;
  }
}
