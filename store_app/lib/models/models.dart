class StoreUser {
  final int id;
  final String employeeCode;
  final String name;
  final String email;
  final String? mobile;
  final String role;
  final String? departmentName;

  StoreUser({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.email,
    this.mobile,
    required this.role,
    this.departmentName,
  });

  factory StoreUser.fromJson(Map<String, dynamic> json) {
    return StoreUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      employeeCode: json['employee_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString(),
      role: json['role']?.toString() ?? 'STORE_USER',
      departmentName: json['department_name']?.toString() ?? 'Store & Warehouse',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_code': employeeCode,
    'name': name,
    'email': email,
    'mobile': mobile,
    'role': role,
    'department_name': departmentName,
  };
}

class StoreItem {
  final int id;
  final int subRequisitionId;
  final int materialId;
  final String materialName;
  final String unit;
  final double requestedQuantity;
  final double issuedQuantity;
  final double unitRate;
  final double amount;
  final String? remark;
  final String? storeRemark;
  String status; // 'PENDING', 'ISSUED', 'PARTIALLY_ISSUED', 'NOT_AVAILABLE'
  final bool isEmergency;
  final String createdAt;
  final String? storeActionAt;
  final String? storeActionByName;
  final double currentStock;
  final String materialCode;
  final String? materialCategory;
  final String subRequisitionNo;
  final int locationId;
  final String locationName;
  final String locationCode;
  final int masterRequisitionId;
  final String masterRequisitionNo;
  final String requisitionDate;
  final int userId;
  final String userName;
  final String employeeCode;
  final String? userMobile;
  final String? departmentName;

  bool get isPending => status == 'PENDING';
  bool get isIssued => status == 'ISSUED';
  bool get isPartial => status == 'PARTIAL_ISSUED' || status == 'PARTIALLY_ISSUED';
  bool get isNotAvailable => status == 'NOT_AVAILABLE';

  StoreItem({
    required this.id,
    required this.subRequisitionId,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.requestedQuantity,
    required this.issuedQuantity,
    required this.unitRate,
    required this.amount,
    this.remark,
    this.storeRemark,
    required this.status,
    required this.isEmergency,
    required this.createdAt,
    this.storeActionAt,
    this.storeActionByName,
    required this.currentStock,
    required this.materialCode,
    this.materialCategory,
    required this.subRequisitionNo,
    required this.locationId,
    required this.locationName,
    required this.locationCode,
    required this.masterRequisitionId,
    required this.masterRequisitionNo,
    required this.requisitionDate,
    required this.userId,
    required this.userName,
    required this.employeeCode,
    this.userMobile,
    this.departmentName,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      subRequisitionId: json['sub_requisition_id'] is int ? json['sub_requisition_id'] : int.tryParse(json['sub_requisition_id'].toString()) ?? 0,
      materialId: json['material_id'] is int ? json['material_id'] : int.tryParse(json['material_id'].toString()) ?? 0,
      materialName: json['material_name_snapshot']?.toString() ?? json['material_name']?.toString() ?? 'Material',
      unit: json['unit_snapshot']?.toString() ?? json['unit']?.toString() ?? 'Unit',
      requestedQuantity: (json['requested_quantity'] is num) ? (json['requested_quantity'] as num).toDouble() : double.tryParse(json['requested_quantity'].toString()) ?? 0.0,
      issuedQuantity: (json['issued_quantity'] is num) ? (json['issued_quantity'] as num).toDouble() : double.tryParse(json['issued_quantity'].toString()) ?? 0.0,
      unitRate: (json['unit_rate'] is num) ? (json['unit_rate'] as num).toDouble() : double.tryParse(json['unit_rate'].toString()) ?? 0.0,
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount'].toString()) ?? 0.0,
      remark: json['remark']?.toString(),
      storeRemark: json['store_remark']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      isEmergency: json['is_emergency'] == 1 || json['is_emergency'] == '1' || json['is_emergency'] == true,
      createdAt: json['created_at']?.toString() ?? '',
      storeActionAt: json['store_action_at']?.toString(),
      storeActionByName: json['store_action_by_name']?.toString(),
      currentStock: (json['current_stock'] is num) ? (json['current_stock'] as num).toDouble() : double.tryParse(json['current_stock'].toString()) ?? 0.0,
      materialCode: json['material_code']?.toString() ?? '',
      materialCategory: json['material_category']?.toString(),
      subRequisitionNo: json['sub_requisition_no']?.toString() ?? '',
      locationId: json['location_id'] is int ? json['location_id'] : int.tryParse(json['location_id'].toString()) ?? 0,
      locationName: json['location_name']?.toString() ?? 'Site Location',
      locationCode: json['location_code']?.toString() ?? '',
      masterRequisitionId: json['master_requisition_id'] is int ? json['master_requisition_id'] : int.tryParse(json['master_requisition_id'].toString()) ?? 0,
      masterRequisitionNo: json['master_requisition_no']?.toString() ?? '',
      requisitionDate: json['requisition_date']?.toString() ?? '',
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id'].toString()) ?? 0,
      userName: json['user_name']?.toString() ?? 'Employee',
      employeeCode: json['employee_code']?.toString() ?? '',
      userMobile: json['user_mobile']?.toString(),
      departmentName: json['department_name']?.toString() ?? 'Department',
    );
  }
}

class FeedStats {
  final int totalItems;
  final int pendingCount;
  final int issuedCount;
  final int partialCount;
  final int notAvailableCount;
  final double totalIssuedAmount;
  final int dispatchProgress;

  FeedStats({
    required this.totalItems,
    required this.pendingCount,
    required this.issuedCount,
    required this.partialCount,
    required this.notAvailableCount,
    required this.totalIssuedAmount,
    required this.dispatchProgress,
  });

  factory FeedStats.fromJson(Map<String, dynamic> json) {
    return FeedStats(
      totalItems: json['total_items'] is int ? json['total_items'] : int.tryParse(json['total_items'].toString()) ?? 0,
      pendingCount: json['pending_count'] is int ? json['pending_count'] : int.tryParse(json['pending_count'].toString()) ?? 0,
      issuedCount: json['issued_count'] is int ? json['issued_count'] : int.tryParse(json['issued_count'].toString()) ?? 0,
      partialCount: json['partial_count'] is int ? json['partial_count'] : int.tryParse(json['partial_count'].toString()) ?? 0,
      notAvailableCount: json['not_available_count'] is int ? json['not_available_count'] : int.tryParse(json['not_available_count'].toString()) ?? 0,
      totalIssuedAmount: (json['total_issued_amount'] is num) ? (json['total_issued_amount'] as num).toDouble() : double.tryParse(json['total_issued_amount'].toString()) ?? 0.0,
      dispatchProgress: json['dispatch_progress'] is int ? json['dispatch_progress'] : int.tryParse(json['dispatch_progress'].toString()) ?? 0,
    );
  }
}

class LocationItem {
  final int id;
  final String name;
  final String code;

  LocationItem({required this.id, required this.name, required this.code});

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class StockMaterial {
  final int id;
  final String code;
  final String name;
  final String unit;
  final double defaultRate;
  final double currentStock;
  final String? category;

  StockMaterial({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.defaultRate,
    required this.currentStock,
    this.category,
  });

  factory StockMaterial.fromJson(Map<String, dynamic> json) {
    return StockMaterial(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'Nos',
      defaultRate: (json['default_rate'] is num) ? (json['default_rate'] as num).toDouble() : double.tryParse(json['default_rate'].toString()) ?? 0.0,
      currentStock: (json['current_stock'] is num) ? (json['current_stock'] as num).toDouble() : double.tryParse(json['current_stock'].toString()) ?? 0.0,
      category: json['category']?.toString(),
    );
  }
}

class TargetUser {
  final int id;
  final String name;
  final String employeeCode;
  final String? departmentName;

  TargetUser({required this.id, required this.name, required this.employeeCode, this.departmentName});

  factory TargetUser.fromJson(Map<String, dynamic> json) {
    return TargetUser(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      employeeCode: json['employee_code']?.toString() ?? '',
      departmentName: json['department_name']?.toString(),
    );
  }
}
