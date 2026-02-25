enum AppUserRole { admin, hr, teiker }

class AppUserRoleResolver {
  const AppUserRoleResolver._();

  static const String hrEmail = 'maryborgeshealing@gmail.com';

  static AppUserRole fromEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return AppUserRole.teiker;
    if (normalized == hrEmail) return AppUserRole.hr;
    if (normalized.endsWith('@teiker.ch')) return AppUserRole.admin;
    return AppUserRole.teiker;
  }

  static bool isAdminEmail(String? email) => fromEmail(email) == AppUserRole.admin;
  static bool isHrEmail(String? email) => fromEmail(email) == AppUserRole.hr;
  static bool isPrivilegedEmail(String? email) {
    final role = fromEmail(email);
    return role == AppUserRole.admin || role == AppUserRole.hr;
  }

  static String roleLabel(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return 'Admin';
      case AppUserRole.hr:
        return 'Recursos Humanos';
      case AppUserRole.teiker:
        return 'Teiker';
    }
  }
}

extension AppUserRoleX on AppUserRole {
  bool get isAdmin => this == AppUserRole.admin;
  bool get isHr => this == AppUserRole.hr;
  bool get isTeiker => this == AppUserRole.teiker;
  bool get isPrivileged => isAdmin || isHr;
}
