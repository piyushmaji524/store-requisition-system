import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MasterDataTab extends StatefulWidget {
  const MasterDataTab({super.key});

  @override
  State<MasterDataTab> createState() => _MasterDataTabState();
}

class _MasterDataTabState extends State<MasterDataTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Materials state
  List<MaterialItem> _materials = [];
  bool _isLoadingMaterials = true;
  String _matSearch = '';

  // Users state
  List<UserItem> _users = [];
  bool _isLoadingUsers = true;
  String _userSearch = '';

  // Locations state
  List<LocationItem> _locations = [];
  bool _isLoadingLocations = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadMaterials();
    _loadUsers();
    _loadLocations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoadingMaterials = true);
    final res = await ApiService.getMaterials(search: _matSearch);
    if (mounted) setState(() { _materials = res; _isLoadingMaterials = false; });
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    final res = await ApiService.getUsers(search: _userSearch);
    if (mounted) setState(() { _users = res; _isLoadingUsers = false; });
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    final res = await ApiService.getLocations();
    if (mounted) setState(() { _locations = res; _isLoadingLocations = false; });
  }

  // --- 1. Quick Stock Edit Dialog ---
  Future<void> _showQuickStockDialog(MaterialItem mat) async {
    final stockController = TextEditingController(text: mat.currentStock.toString());
    final remarkController = TextEditingController(text: 'Physical stock adjusted via Admin Mobile App');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📦 Adjust Material Stock Balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Text(mat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.navyAccent)),
            Text('Item Code: ${mat.code} • Unit: ${mat.unit}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 16),

            TextField(
              controller: stockController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Stock Balance (${mat.unit}) *',
                prefixIcon: const Icon(Icons.inventory, color: AppTheme.primaryGold),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(
                labelText: 'Adjustment Remark / Reason',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                onPressed: () async {
                  final newStock = double.tryParse(stockController.text.trim());
                  if (newStock == null || newStock < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a valid non-negative number')),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final res = await ApiService.quickStockEdit(mat.id, newStock, remarkController.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res['message'] ?? 'Stock updated'),
                        backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                      ),
                    );
                    _loadMaterials();
                  }
                },
                child: const Text('Save Stock Balance'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. Material Add / Edit Form Modal ---
  Future<void> _showMaterialFormDialog([MaterialItem? mat]) async {
    final isEdit = mat != null;
    final nameController = TextEditingController(text: mat?.name ?? '');
    final codeController = TextEditingController(text: mat?.code ?? '');
    final rateController = TextEditingController(text: mat != null ? mat.defaultRate.toString() : '0.00');
    final stockController = TextEditingController(text: mat != null ? mat.currentStock.toString() : '0.00');
    final tallyNameController = TextEditingController(text: mat?.tallyItemName ?? '');
    final tallyCodeController = TextEditingController(text: mat?.tallyItemCode ?? '');
    String selectedUnit = (mat?.unit != null && mat!.unit.isNotEmpty) ? mat.unit : 'NOS';
    String selectedStatus = mat?.status ?? 'ACTIVE';

    final units = ['NOS', 'KG', 'LTR', 'PKT', 'MTR', 'BOX', 'SET', 'ROLL', 'PAIR', 'BAG', 'DOZEN', 'GRAM', 'BOTTLE', 'CAN'];
    if (!units.contains(selectedUnit)) {
      units.insert(0, selectedUnit);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? '✏️ Edit Material' : '✨ Add New Material',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Material Name *',
                    hintText: 'e.g. Atta (Wheat Flour)',
                    prefixIcon: Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: codeController,
                        decoration: InputDecoration(
                          labelText: 'Code ${isEdit ? '' : '(Auto if empty)'}',
                          hintText: 'e.g. MAT-042',
                          prefixIcon: const Icon(Icons.qr_code, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit *'),
                        items: units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontWeight: FontWeight.w700)))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedUnit = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: rateController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Default Rate (₹)',
                          prefixIcon: Icon(Icons.currency_rupee, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Current Stock',
                          prefixIcon: Icon(Icons.layers_outlined, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: tallyNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tally Item Name (Optional)',
                    hintText: 'Exact match with Tally Ledger if different',
                    prefixIcon: Icon(Icons.cloud_outlined, color: AppTheme.navyAccent),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                        ButtonSegment(value: 'INACTIVE', label: Text('Inactive')),
                      ],
                      selected: {selectedStatus},
                      onSelectionChanged: (set) => setModalState(() => selectedStatus = set.first),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isEdit ? 'Update Material' : 'Create Material', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter material name')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final data = {
                        'name': name,
                        'code': codeController.text.trim(),
                        'unit': selectedUnit,
                        'default_rate': double.tryParse(rateController.text.trim()) ?? 0.0,
                        'current_stock': double.tryParse(stockController.text.trim()) ?? 0.0,
                        'tally_item_name': tallyNameController.text.trim(),
                        'tally_item_code': tallyCodeController.text.trim(),
                        'status': selectedStatus,
                      };
                      final res = await ApiService.saveMaterial(data, id: mat?.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Saved successfully.'),
                            backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                          ),
                        );
                        _loadMaterials();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 3. User Add / Edit Form Modal ---
  Future<void> _showUserFormDialog([UserItem? user]) async {
    final isEdit = user != null;
    final nameController = TextEditingController(text: user?.name ?? '');
    final codeController = TextEditingController(text: user?.employeeCode ?? '');
    final mobileController = TextEditingController(text: user?.mobile ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'REQUISITION_USER';
    String selectedStatus = user?.status ?? 'ACTIVE';

    final roles = ['REQUISITION_USER', 'STORE_USER', 'ADMIN', 'SUPER_ADMIN'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? '✏️ Edit User' : '✨ Add New User',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    hintText: 'e.g. Ramesh Sharma',
                    prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Employee Code *',
                          hintText: 'e.g. EMP-101',
                          prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Role *'),
                        items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedRole = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          hintText: '10 digits',
                          prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'user@gunayatan.com',
                          prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryGold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (!isEdit) ...[
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Initial Password / PIN *',
                      hintText: 'Minimum 4 characters',
                      prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryGold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                        ButtonSegment(value: 'INACTIVE', label: Text('Inactive')),
                      ],
                      selected: {selectedStatus},
                      onSelectionChanged: (set) => setModalState(() => selectedStatus = set.first),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isEdit ? 'Update User' : 'Create User', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final code = codeController.text.trim();
                      if (name.isEmpty || code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Employee Code are required.')));
                        return;
                      }
                      if (!isEdit && passwordController.text.trim().length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 4 characters.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final data = {
                        'name': name,
                        'employee_code': code,
                        'mobile': mobileController.text.trim(),
                        'email': emailController.text.trim(),
                        'role': selectedRole,
                        'status': selectedStatus,
                        if (passwordController.text.trim().isNotEmpty) 'password': passwordController.text.trim(),
                      };
                      final res = await ApiService.saveUser(data, id: user?.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Saved successfully.'),
                            backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                          ),
                        );
                        _loadUsers();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 4. Location Add / Edit Form Modal ---
  Future<void> _showLocationFormDialog([LocationItem? loc]) async {
    final isEdit = loc != null;
    final nameController = TextEditingController(text: loc?.name ?? '');
    final codeController = TextEditingController(text: loc?.code ?? '');
    final tallyLedgerController = TextEditingController(text: loc?.tallyLedgerName ?? '');
    final tallyCodeController = TextEditingController(text: loc?.tallyLedgerCode ?? '');
    String selectedStatus = loc?.status ?? 'ACTIVE';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? '✏️ Edit Location' : '✨ Add New Location',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Location Name *',
                    hintText: 'e.g. Main Kitchen / Dining Hall',
                    prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Location Code *',
                    hintText: 'e.g. KIT-01 / LOC-01',
                    prefixIcon: Icon(Icons.tag, color: AppTheme.primaryGold),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: tallyLedgerController,
                  decoration: const InputDecoration(
                    labelText: 'Tally Cost Center / Ledger Name (Optional)',
                    hintText: 'Exact ledger name in Tally ERP',
                    prefixIcon: Icon(Icons.cloud_outlined, color: AppTheme.navyAccent),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'ACTIVE', label: Text('Active')),
                        ButtonSegment(value: 'INACTIVE', label: Text('Inactive')),
                      ],
                      selected: {selectedStatus},
                      onSelectionChanged: (set) => setModalState(() => selectedStatus = set.first),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isEdit ? 'Update Location' : 'Create Location', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final code = codeController.text.trim();
                      if (name.isEmpty || code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name and Code are required.')));
                        return;
                      }
                      Navigator.pop(ctx);
                      final data = {
                        'name': name,
                        'code': code,
                        'tally_ledger_name': tallyLedgerController.text.trim(),
                        'tally_ledger_code': tallyCodeController.text.trim(),
                        'status': selectedStatus,
                      };
                      final res = await ApiService.saveLocation(data, id: loc?.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['message'] ?? 'Saved successfully.'),
                            backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                          ),
                        );
                        _loadLocations();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 5. Reset User PIN / Password Dialog ---
  Future<void> _showResetPinDialog(UserItem user) async {
    final pinController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset PIN: ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee Code: ${user.employeeCode}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'New Password / PIN *',
                hintText: 'Minimum 4 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold),
            onPressed: () async {
              if (pinController.text.trim().length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 4 characters.')),
                );
                return;
              }
              Navigator.pop(ctx);
              final res = await ApiService.resetUserPassword(user.id, pinController.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message'] ?? 'Password reset.'),
                    backgroundColor: res['success'] == true ? AppTheme.successGreen : AppTheme.dangerRed,
                  ),
                );
              }
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(116),
        child: Column(
          children: [
            GunayatanHeader(
              title: 'Master Data Hub',
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
                  onPressed: () {
                    _loadMaterials();
                    _loadUsers();
                    _loadLocations();
                  },
                ),
              ],
            ),
            Container(
              color: AppTheme.surfaceWhite,
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryGold,
                indicatorWeight: 3,
                labelColor: AppTheme.primaryGoldDark,
                unselectedLabelColor: AppTheme.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(text: 'Materials'),
                  Tab(text: 'Users'),
                  Tab(text: 'Locations'),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(
          _tabController.index == 0
              ? 'New Material'
              : _tabController.index == 1
                  ? 'New User'
                  : 'New Location',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        ),
        onPressed: () {
          if (_tabController.index == 0) {
            _showMaterialFormDialog();
          } else if (_tabController.index == 1) {
            _showUserFormDialog();
          } else {
            _showLocationFormDialog();
          }
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Materials Tab
          _buildMaterialsList(),

          // 2. Users Tab
          _buildUsersList(),

          // 3. Locations Tab
          _buildLocationsList(),
        ],
      ),
    );
  }

  Widget _buildMaterialsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surfaceWhite,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search material by name or code...',
              prefixIcon: Icon(Icons.search, color: AppTheme.primaryGold, size: 20),
            ),
            onChanged: (val) {
              _matSearch = val.trim();
              _loadMaterials();
            },
          ),
        ),
        Expanded(
          child: _isLoadingMaterials
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
              : _materials.isEmpty
                  ? const EmptyStateWidget(title: 'No Materials', message: 'No materials match your search.')
                  : RefreshIndicator(
                      color: AppTheme.primaryGold,
                      onRefresh: _loadMaterials,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                        itemCount: _materials.length,
                        itemBuilder: (context, idx) {
                          final mat = _materials[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(mat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      const SizedBox(height: 4),
                                      Text('Code: ${mat.code} • Rate: ₹${mat.defaultRate}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                      if (mat.tallyItemName != null && mat.tallyItemName!.isNotEmpty)
                                        Text('Tally: ${mat.tallyItemName}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryGoldDark)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () => _showQuickStockDialog(mat),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryGoldSoft,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${mat.currentStock} ${mat.unit}',
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(Icons.inventory, size: 12, color: AppTheme.primaryGoldDark),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryGoldDark),
                                          tooltip: 'Edit Material',
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(6),
                                          onPressed: () => _showMaterialFormDialog(mat),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Switch(
                                      value: mat.status == 'ACTIVE',
                                      activeColor: AppTheme.successGreen,
                                      onChanged: (val) async {
                                        await ApiService.toggleMaterialStatus(mat.id);
                                        _loadMaterials();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildUsersList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppTheme.surfaceWhite,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search users by name or code...',
              prefixIcon: Icon(Icons.search, color: AppTheme.primaryGold, size: 20),
            ),
            onChanged: (val) {
              _userSearch = val.trim();
              _loadUsers();
            },
          ),
        ),
        Expanded(
          child: _isLoadingUsers
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
              : _users.isEmpty
                  ? const EmptyStateWidget(title: 'No Users', message: 'No users found.')
                  : RefreshIndicator(
                      color: AppTheme.primaryGold,
                      onRefresh: _loadUsers,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                        itemCount: _users.length,
                        itemBuilder: (context, idx) {
                          final u = _users[idx];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.borderSubtle),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppTheme.primaryGoldSoft,
                                  child: Text(
                                    u.name.isNotEmpty ? u.name[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.primaryGoldDark),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      Text('Code: ${u.employeeCode} • Role: ${u.role}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                      if (u.mobile != null && u.mobile!.isNotEmpty)
                                        Text('Mobile: ${u.mobile}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGoldDark, size: 20),
                                      tooltip: 'Edit User',
                                      onPressed: () => _showUserFormDialog(u),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.key, color: AppTheme.primaryGold, size: 20),
                                      tooltip: 'Reset Password/PIN',
                                      onPressed: () => _showResetPinDialog(u),
                                    ),
                                    Switch(
                                      value: u.status == 'ACTIVE',
                                      activeColor: AppTheme.successGreen,
                                      onChanged: (val) async {
                                        await ApiService.toggleUserStatus(u.id);
                                        _loadUsers();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildLocationsList() {
    return _isLoadingLocations
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
        : _locations.isEmpty
            ? const EmptyStateWidget(title: 'No Locations', message: 'No locations configured.')
            : RefreshIndicator(
                color: AppTheme.primaryGold,
                onRefresh: _loadLocations,
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 80),
                  itemCount: _locations.length,
                  itemBuilder: (context, idx) {
                    final loc = _locations[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGoldSoft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(loc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                Text('Code: ${loc.code}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted)),
                                if (loc.tallyLedgerName != null && loc.tallyLedgerName!.isNotEmpty)
                                  Text('Tally Ledger: ${loc.tallyLedgerName}', style: const TextStyle(fontSize: 11, color: AppTheme.primaryGoldDark)),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGoldDark, size: 20),
                                tooltip: 'Edit Location',
                                onPressed: () => _showLocationFormDialog(loc),
                              ),
                              Switch(
                                value: loc.status == 'ACTIVE',
                                activeColor: AppTheme.successGreen,
                                onChanged: (val) async {
                                  await ApiService.toggleLocationStatus(loc.id);
                                  _loadLocations();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
  }
}
