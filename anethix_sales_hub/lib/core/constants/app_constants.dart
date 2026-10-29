class AppConstants {
  const AppConstants._();

  static const String appName = 'Anethix Sales Hub';
  static const String orgName = 'Anethix Labs';

  static const double pagePadding = 16;
  static const double cardRadius = 16;
  static const double fieldRadius = 12;
  static const double buttonRadius = 12;
  static const double minTapSize = 48;

  static const Duration searchDebounce = Duration(milliseconds: 350);

  static const List<String> industries = [
    'IT',
    'Manufacturing',
    'Finance',
    'Healthcare',
    'Education',
    'Retail',
    'Real Estate',
    'Other',
  ];

  static const List<String> sources = [
    'Website',
    'Referral',
    'LinkedIn',
    'Cold Call',
    'Exhibition',
    'Social Media',
    'Other',
  ];

  static const List<String> leadTypes = [
    'Enterprise',
    'SMB',
    'Startup',
    'Government',
    'Channel Partner',
  ];

  static const List<String> cities = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Pune',
    'Chennai',
    'Kolkata',
    'Ahmedabad',
  ];

  /// Number of days without activity after which a claimed lead is "stuck".
  static const int stuckLeadDays = 3;
}
