class AdminUser {
  final int id;
  final String name;
  final String employeeCode;
  final String? mobile;
  final String? email;
  final String role;
  final int? departmentId;
  final String? departmentName;
  final String status;

  AdminUser({
    required this.id,
    required this.name,
    required this.employeeCode,
    this.mobile,
    this.email,
    required this.role,
    this.departmentId,
    this.departmentName,
    required this.status,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'ADMIN',
      departmentId: json['department_id'] != null ? int.tryParse(json['department_id'].toString()) : null,
      departmentName: json['department_name']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'employee_code': employeeCode,
    'mobile': mobile,
    'email': email,
    'role': role,
    'department_id': departmentId,
    'department_name': departmentName,
    'status': status,
  };
}

class DashboardMetrics {
  final int totalMasterReqs;
  final int totalSubReqs;
  final int totalItems;
  final double totalIssuedQty;
  final double totalValuation;
  final int pendingItems;
  final int issuedItems;
  final int partialItems;
  final int notAvailableItems;
  final int tallyExportedSubs;
  final int activeOverridesCount;
  final String? dateFrom;
  final String? dateTo;

  DashboardMetrics({
    required this.totalMasterReqs,
    required this.totalSubReqs,
    required this.totalItems,
    required this.totalIssuedQty,
    this.totalValuation = 0.0,
    required this.pendingItems,
    required this.issuedItems,
    required this.partialItems,
    required this.notAvailableItems,
    required this.tallyExportedSubs,
    required this.activeOverridesCount,
    this.dateFrom,
    this.dateTo,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) {
    return DashboardMetrics(
      totalMasterReqs: int.tryParse(json['total_master_reqs']?.toString() ?? '0') ?? 0,
      totalSubReqs: int.tryParse(json['total_sub_reqs']?.toString() ?? '0') ?? 0,
      totalItems: int.tryParse(json['total_items']?.toString() ?? '0') ?? 0,
      totalIssuedQty: double.tryParse(json['total_issued_qty']?.toString() ?? '0') ?? 0.0,
      totalValuation: double.tryParse(json['total_valuation']?.toString() ?? '0') ?? 0.0,
      pendingItems: int.tryParse(json['pending_items']?.toString() ?? '0') ?? 0,
      issuedItems: int.tryParse(json['issued_items']?.toString() ?? '0') ?? 0,
      partialItems: int.tryParse(json['partial_items']?.toString() ?? '0') ?? 0,
      notAvailableItems: int.tryParse(json['not_available_items']?.toString() ?? '0') ?? 0,
      tallyExportedSubs: int.tryParse(json['tally_exported_subs']?.toString() ?? '0') ?? 0,
      activeOverridesCount: int.tryParse(json['active_overrides_count']?.toString() ?? '0') ?? 0,
      dateFrom: json['date_from']?.toString(),
      dateTo: json['date_to']?.toString(),
    );
  }
}

class AdminRequisition {
  final int id;
  final String requisitionNumber;
  final String requisitionDate;
  final String status;
  final String? notes;
  final String userName;
  final String employeeCode;
  final String? mobile;
  final int totalSubs;
  final int totalItems;
  final double totalIssuedAmount;
  final String createdAt;

  AdminRequisition({
    required this.id,
    required this.requisitionNumber,
    required this.requisitionDate,
    required this.status,
    this.notes,
    required this.userName,
    required this.employeeCode,
    this.mobile,
    required this.totalSubs,
    required this.totalItems,
    required this.totalIssuedAmount,
    required this.createdAt,
  });

  factory AdminRequisition.fromJson(Map<String, dynamic> json) {
    return AdminRequisition(
      id: int.tryParse(json['id'].toString()) ?? 0,
      requisitionNumber: json['requisition_number']?.toString() ?? '',
      requisitionDate: json['requisition_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      notes: json['notes']?.toString(),
      userName: json['user_name']?.toString() ?? 'Unknown',
      employeeCode: json['employee_code']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      totalSubs: int.tryParse(json['total_subs']?.toString() ?? '0') ?? 0,
      totalItems: int.tryParse(json['total_items']?.toString() ?? '0') ?? 0,
      totalIssuedAmount: double.tryParse(json['total_issued_amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class MaterialItem {
  final int id;
  final String name;
  final String code;
  final String unit;
  final double defaultRate;
  double currentStock;
  final String? tallyItemName;
  final String? tallyItemCode;
  String status;
  final String? categoryName;

  MaterialItem({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.defaultRate,
    required this.currentStock,
    this.tallyItemName,
    this.tallyItemCode,
    required this.status,
    this.categoryName,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'NOS',
      defaultRate: double.tryParse(json['default_rate']?.toString() ?? '0') ?? 0.0,
      currentStock: double.tryParse(json['current_stock']?.toString() ?? '0') ?? 0.0,
      tallyItemName: json['tally_item_name']?.toString(),
      tallyItemCode: json['tally_item_code']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      categoryName: json['category_name']?.toString(),
    );
  }
}

class LocationItem {
  final int id;
  final String name;
  final String code;
  final String? tallyLedgerName;
  final String? tallyLedgerCode;
  String status;

  LocationItem({
    required this.id,
    required this.name,
    required this.code,
    this.tallyLedgerName,
    this.tallyLedgerCode,
    required this.status,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      tallyLedgerName: json['tally_ledger_name']?.toString(),
      tallyLedgerCode: json['tally_ledger_code']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
    );
  }
}

class UserItem {
  final int id;
  final String employeeCode;
  final String name;
  final String? mobile;
  final String? email;
  final String role;
  String status;
  final String? departmentName;

  UserItem({
    required this.id,
    required this.employeeCode,
    required this.name,
    this.mobile,
    this.email,
    required this.role,
    required this.status,
    this.departmentName,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      employeeCode: json['employee_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? 'USER',
      status: json['status']?.toString() ?? 'ACTIVE',
      departmentName: json['department_name']?.toString(),
    );
  }
}

class DateOverrideItem {
  final int id;
  final String overrideDate;
  final String openedByName;
  final String openedAt;
  final String expiresAt;
  final String reason;
  final String status;
  final String liveStatus;
  final int remainingSeconds;

  DateOverrideItem({
    required this.id,
    required this.overrideDate,
    required this.openedByName,
    required this.openedAt,
    required this.expiresAt,
    required this.reason,
    required this.status,
    required this.liveStatus,
    required this.remainingSeconds,
  });

  factory DateOverrideItem.fromJson(Map<String, dynamic> json) {
    return DateOverrideItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      overrideDate: json['override_date']?.toString() ?? '',
      openedByName: json['opened_by_name']?.toString() ?? 'Admin',
      openedAt: json['opened_at']?.toString() ?? '',
      expiresAt: json['expires_at']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      liveStatus: json['live_status']?.toString() ?? 'OPEN',
      remainingSeconds: int.tryParse(json['remaining_seconds']?.toString() ?? '0') ?? 0,
    );
  }
}

class ActivityLogItem {
  final int id;
  final String action;
  final String? entityType;
  final String? entityId;
  final dynamic newValues;
  final String? ipAddress;
  final String createdAt;
  final String? userName;
  final String? userRole;

  ActivityLogItem({
    required this.id,
    required this.action,
    this.entityType,
    this.entityId,
    this.newValues,
    this.ipAddress,
    required this.createdAt,
    this.userName,
    this.userRole,
  });

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) {
    return ActivityLogItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      action: json['action']?.toString() ?? '',
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      newValues: json['new_values'],
      ipAddress: json['ip_address']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      userName: json['user_name']?.toString(),
      userRole: json['user_role']?.toString(),
    );
  }
}
