import '../../data/models/usuario_sqlite_model.dart';

class AppPermissions {
  final bool canViewClientes;
  final bool canManageClientes;
  final bool canViewInventario;
  final bool canAddInventario;
  final bool canEditInventario;
  final bool canDeleteInventario;
  final bool canAddProductImages;
  final bool canEditProductImages;
  final bool canRunDailyAudit;
  final bool canRunWeeklyAudit;
  final bool canViewAuditReports;
  final bool canApproveCollaboratorChanges;
  final bool canManageSubscription;
  final bool canManageCollaborators;

  const AppPermissions({
    required this.canViewClientes,
    required this.canManageClientes,
    required this.canViewInventario,
    required this.canAddInventario,
    required this.canEditInventario,
    required this.canDeleteInventario,
    required this.canAddProductImages,
    required this.canEditProductImages,
    required this.canRunDailyAudit,
    required this.canRunWeeklyAudit,
    required this.canViewAuditReports,
    required this.canApproveCollaboratorChanges,
    required this.canManageSubscription,
    required this.canManageCollaborators,
  });

  factory AppPermissions.forUser(UsuarioSqliteModel? user) {
    switch (user?.tipoUsuario) {
      case UsuarioSqliteModel.tipoNegocio:
        return const AppPermissions(
          canViewClientes: true,
          canManageClientes: true,
          canViewInventario: true,
          canAddInventario: true,
          canEditInventario: true,
          canDeleteInventario: true,
          canAddProductImages: true,
          canEditProductImages: true,
          canRunDailyAudit: true,
          canRunWeeklyAudit: true,
          canViewAuditReports: true,
          canApproveCollaboratorChanges: true,
          canManageSubscription: true,
          canManageCollaborators: true,
        );
      case UsuarioSqliteModel.tipoColaborador:
        return const AppPermissions(
          canViewClientes: false,
          canManageClientes: false,
          canViewInventario: true,
          canAddInventario: true,
          canEditInventario: false,
          canDeleteInventario: false,
          canAddProductImages: true,
          canEditProductImages: false,
          canRunDailyAudit: true,
          canRunWeeklyAudit: true,
          canViewAuditReports: false,
          canApproveCollaboratorChanges: false,
          canManageSubscription: false,
          canManageCollaborators: false,
        );
      case UsuarioSqliteModel.tipoPersonal:
        return const AppPermissions(
          canViewClientes: false,
          canManageClientes: false,
          canViewInventario: false,
          canAddInventario: false,
          canEditInventario: false,
          canDeleteInventario: false,
          canAddProductImages: false,
          canEditProductImages: false,
          canRunDailyAudit: false,
          canRunWeeklyAudit: false,
          canViewAuditReports: false,
          canApproveCollaboratorChanges: false,
          canManageSubscription: false,
          canManageCollaborators: false,
        );
      default:
        return const AppPermissions(
          canViewClientes: false,
          canManageClientes: false,
          canViewInventario: false,
          canAddInventario: false,
          canEditInventario: false,
          canDeleteInventario: false,
          canAddProductImages: false,
          canEditProductImages: false,
          canRunDailyAudit: false,
          canRunWeeklyAudit: false,
          canViewAuditReports: false,
          canApproveCollaboratorChanges: false,
          canManageSubscription: false,
          canManageCollaborators: false,
        );
    }
  }
}
