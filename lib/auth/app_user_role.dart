enum AppUserRole { admin, developer, hr, teiker }

class AppUserRoleResolver {
  const AppUserRoleResolver._();

  static const String hrEmail = 'maryborgeshealing@gmail.com';
  static const String developerEmail = 'spacecutcompany@gmail.com';
  static const String developerName = 'Inês Borges';
  static const String adminName = 'Sónia Pereira';
  static const String hrName = 'Maria Borges';

  static AppUserRole fromEmail(String? email) {
    final normalized = (email ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return AppUserRole.teiker;
    if (normalized == developerEmail) return AppUserRole.developer;
    if (normalized == hrEmail) return AppUserRole.hr;
    if (normalized.endsWith('@teiker.ch')) return AppUserRole.admin;
    return AppUserRole.teiker;
  }

  static bool isAdminEmail(String? email) => fromEmail(email).isAdmin;
  static bool isDeveloperEmail(String? email) =>
      fromEmail(email) == AppUserRole.developer;
  static bool isHrEmail(String? email) => fromEmail(email) == AppUserRole.hr;
  static bool isPrivilegedEmail(String? email) {
    return fromEmail(email).isPrivileged;
  }

  static String roleLabel(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return 'Admin';
      case AppUserRole.developer:
        return 'Developer';
      case AppUserRole.hr:
        return 'Recursos Humanos';
      case AppUserRole.teiker:
        return 'Teiker';
    }
  }

  static String displayNameForRole(AppUserRole role) {
    switch (role) {
      case AppUserRole.admin:
        return adminName;
      case AppUserRole.developer:
        return developerName;
      case AppUserRole.hr:
        return hrName;
      case AppUserRole.teiker:
        return 'Teiker Profissional';
    }
  }
}

extension AppUserRoleX on AppUserRole {
  bool get isAdmin =>
      this == AppUserRole.admin || this == AppUserRole.developer;
  bool get isDeveloper => this == AppUserRole.developer;
  bool get isHr => this == AppUserRole.hr;
  bool get isTeiker => this == AppUserRole.teiker;
  bool get isPrivileged => isAdmin || isHr || isDeveloper;
}
