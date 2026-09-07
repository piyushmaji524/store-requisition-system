class User {
  final int id;
  final String employeeCode;
  final String name;
  final String? mobile;
  final String? email;
  final String role;
  final String? departmentName;

  User({
    required this.id,
    required this.employeeCode,
    required this.name,
    this.mobile,
    this.email,
    required this.role,
    this.departmentName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      employeeCode: json['employee_code'] ?? '',
      name: json['name'] ?? '',
      mobile: json['mobile'],
      email: json['email'],
      role: json['role'] ?? 'REQUISITION_USER',
      departmentName: json['department_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'employee_code': employeeCode,
    'name': name,
    'mobile': mobile,
    'email': email,
    'role': role,
    'department_name': departmentName,
  };
}

class MaterialItem {
  final int id;
  final String name;
  final String code;
  final String unit;
  final double defaultRate;
  final String? category;

  MaterialItem({
    required this.id,
    required this.name,
    required this.code,
    required this.unit,
    required this.defaultRate,
    this.category,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      unit: json['unit'] ?? 'Pcs',
      defaultRate: (json['default_rate'] != null) ? double.parse(json['default_rate'].toString()) : 0.0,
      category: json['category_name'] ?? 'General',
    );
  }
}

class LocationItem {
  final int id;
  final String name;
  final String code;

  LocationItem({
    required this.id,
    required this.name,
    required this.code,
  });

  factory LocationItem.fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      code: json['code'] ?? '',
    );
  }
}

class RequisitionItemModel {
  final int id;
  final int materialId;
  final String materialName;
  final String? materialCode;
  final String unit;
  final double requestedQuantity;
  final double issuedQuantity;
  final String? remark;
  final String? storeRemark;
  final String status;
  final bool isLocked;
  final bool isEmergency;
  final String? locationName;
  final String? storeActionByName;
  final String? storeActionAt;

  RequisitionItemModel({
    required this.id,
    required this.materialId,
    required this.materialName,
    this.materialCode,
    required this.unit,
    required this.requestedQuantity,
    required this.issuedQuantity,
    this.remark,
    this.storeRemark,
    required this.status,
    required this.isLocked,
    required this.isEmergency,
    this.locationName,
    this.storeActionByName,
    this.storeActionAt,
  });

  factory RequisitionItemModel.fromJson(Map<String, dynamic> json, {String? location}) {
    return RequisitionItemModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      materialId: json['material_id'] is int ? json['material_id'] : int.parse(json['material_id'].toString()),
      materialName: json['material_name'] ?? '',
      materialCode: json['material_code'],
      unit: json['unit'] ?? 'Pcs',
      requestedQuantity: double.parse((json['requested_quantity'] ?? 0).toString()),
      issuedQuantity: double.parse((json['issued_quantity'] ?? 0).toString()),
      remark: json['remark'],
      storeRemark: json['store_remark'],
      status: json['status'] ?? 'PENDING',
      isLocked: json['is_locked'] == true || json['store_action_at'] != null,
      isEmergency: json['is_emergency'] == true || json['is_emergency'] == 1,
      locationName: location ?? json['location_name'],
      storeActionByName: json['store_action_by_name'],
      storeActionAt: json['store_action_at'],
    );
  }
}

class SubRequisitionModel {
  final int id;
  final String subRequisitionNo;
  final int locationId;
  final String locationName;
  final String locationCode;
  final String status;
  final List<RequisitionItemModel> items;

  SubRequisitionModel({
    required this.id,
    required this.subRequisitionNo,
    required this.locationId,
    required this.locationName,
    required this.locationCode,
    required this.status,
    required this.items,
  });

  factory SubRequisitionModel.fromJson(Map<String, dynamic> json) {
    var rawItems = (json['items'] as List<dynamic>?) ?? [];
    var locName = json['location_name'] ?? '';
    return SubRequisitionModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      subRequisitionNo: json['sub_requisition_no'] ?? '',
      locationId: json['location_id'] is int ? json['location_id'] : int.parse(json['location_id'].toString()),
      locationName: locName,
      locationCode: json['location_code'] ?? '',
      status: json['status'] ?? 'OPEN',
      items: rawItems.map((e) => RequisitionItemModel.fromJson(e, location: locName)).toList(),
    );
  }
}

class MasterRequisitionModel {
  final int id;
  final String requisitionNo;
  final String requisitionDate;
  final String status;
  final Map<String, dynamic> stats;
  final List<SubRequisitionModel> subRequisitions;

  MasterRequisitionModel({
    required this.id,
    required this.requisitionNo,
    required this.requisitionDate,
    required this.status,
    required this.stats,
    required this.subRequisitions,
  });

  factory MasterRequisitionModel.fromJson(Map<String, dynamic> json) {
    var rawSubs = (json['sub_requisitions'] as List<dynamic>?) ?? [];
    return MasterRequisitionModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      requisitionNo: json['requisition_no'] ?? '',
      requisitionDate: json['requisition_date'] ?? '',
      status: json['status'] ?? 'OPEN',
      stats: (json['stats'] as Map<String, dynamic>?) ?? {},
      subRequisitions: rawSubs.map((e) => SubRequisitionModel.fromJson(e)).toList(),
    );
  }

  List<RequisitionItemModel> get allItems {
    List<RequisitionItemModel> list = [];
    for (var sub in subRequisitions) {
      list.addAll(sub.items);
    }
    return list;
  }
}
