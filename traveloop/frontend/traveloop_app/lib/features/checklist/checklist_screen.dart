import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/api_constants.dart';
import '../../core/services/api_service.dart';
// ─── Data Model ────────────────────────────────────────────────────────────────
class ChecklistItem {
  final int id;
  final int tripId;
  final String label;
  final String category;
  bool isPacked;
  ChecklistItem({
    required this.id,
    required this.tripId,
    required this.label,
    required this.category,
    required this.isPacked,
  });
  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: j['id'],
        tripId: j['trip_id'],
        label: j['label'],
        category: (j['category'] as String? ?? 'other').toLowerCase(),
        isPacked: j['is_packed'] ?? false,
      );
}
// ─── Screen ────────────────────────────────────────────────────────────────────
class ChecklistScreen extends StatefulWidget {
  final int tripId;
  const ChecklistScreen({super.key, required this.tripId});
  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}
class _ChecklistScreenState extends State<ChecklistScreen> {
  // State
  List<ChecklistItem> _items = [];
  bool _loading = true;
  String? _error;
  // Controls
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _groupBy = 'category'; // 'category' | 'status'
  String _sortBy = 'default';   // 'default' | 'name' | 'date'
  String _filterStatus = 'all'; // 'all' | 'packed' | 'unpacked'
  final Set<String> _collapsed = {};
  // Categories order
  static const _categoryOrder = ['documents', 'clothing', 'electronics', 'other'];
  @override
  void initState() {
    super.initState();
    _fetch();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
  // ── API ────────────────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('${ApiConstants.checklist}?trip_id=${widget.tripId}');
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        setState(() { _items = data.map((e) => ChecklistItem.fromJson(e)).toList(); });
      } else {
        setState(() => _error = 'Failed to load checklist (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = 'Network error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
  Future<void> _toggle(ChecklistItem item) async {
    final prev = item.isPacked;
    setState(() => item.isPacked = !prev);
    try {
      final res = await ApiService.put(
        '${ApiConstants.checklist}/${item.id}',
        {'is_packed': item.isPacked},
      );
      if (res.statusCode != 200) setState(() => item.isPacked = prev);
    } catch (_) {
      setState(() => item.isPacked = prev);
    }
  }
  Future<void> _addItem(String label, String category) async {
    try {
      final res = await ApiService.post(ApiConstants.checklist, {
        'trip_id': widget.tripId,
        'label': label,
        'category': category,
      });
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() => _items.add(ChecklistItem.fromJson(data)));
      } else {
        _showSnack('Failed to add item');
      }
    } catch (_) {
      _showSnack('Network error');
    }
  }
  Future<void> _resetAll() async {
    try {
      final res = await ApiService.put(
        '${ApiConstants.checklist}/reset/${widget.tripId}', {});
      if (res.statusCode == 200) {
        setState(() { for (var i in _items) i.isPacked = false; });
      } else {
        _showSnack('Reset failed');
      }
    } catch (_) {
      _showSnack('Network error');
    }
  }
  // ── Helpers ────────────────────────────────────────────────────────────────
  List<ChecklistItem> get _filtered {
    var list = _items.where((i) {
      final matchQuery = _searchQuery.isEmpty || i.label.toLowerCase().contains(_searchQuery);
      final matchStatus = _filterStatus == 'all' ||
          (_filterStatus == 'packed' && i.isPacked) ||
          (_filterStatus == 'unpacked' && !i.isPacked);
      return matchQuery && matchStatus;
    }).toList();
    if (_sortBy == 'name') list.sort((a, b) => a.label.compareTo(b.label));
    return list;
  }
  Map<String, List<ChecklistItem>> get _grouped {
    final items = _filtered;
    if (_groupBy == 'status') {
      return {
        'Packed': items.where((i) => i.isPacked).toList(),
        'Unpacked': items.where((i) => !i.isPacked).toList(),
      };
    }
    final Map<String, List<ChecklistItem>> map = {};
    for (final cat in _categoryOrder) {
      final group = items.where((i) => i.category == cat).toList();
      if (group.isNotEmpty) map[cat] = group;
    }
    final other = items.where((i) => !_categoryOrder.contains(i.category)).toList();
    if (other.isNotEmpty) map['other'] = other;
    return map;
  }
  int get _packedCount => _items.where((i) => i.isPacked).length;
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  void _shareChecklist() {
    final buf = StringBuffer('Packing Checklist\n\n');
    _grouped.forEach((group, items) {
      buf.writeln('== ${_capitalize(group)} ==');
      for (final i in items) buf.writeln('${i.isPacked ? "[x]" : "[ ]"} ${i.label}');
      buf.writeln();
    });
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _showSnack('Checklist copied to clipboard!');
  }
  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showAddDialog() {
    final labelCtrl = TextEditingController();
    String selectedCat = 'documents';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Add Item', style: AppTextStyles.heading3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: InputDecoration(
                  hintText: 'Item name',
                  hintStyle: AppTextStyles.bodySecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _categoryOrder.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(_capitalize(c), style: AppTextStyles.body),
                )).toList(),
                onChanged: (v) => setDlg(() => selectedCat = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final label = labelCtrl.text.trim();
                if (label.isNotEmpty) {
                  Navigator.pop(ctx);
                  _addItem(label, selectedCat);
                }
              },
              child: Text('Add', style: AppTextStyles.buttonText),
            ),
          ],
        ),
      ),
    );
  }
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group By', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              _chipRow(['category', 'status'], _groupBy, (v) {
                setState(() => _groupBy = v);
                setSheet(() {});
              }),
              const SizedBox(height: 16),
              Text('Sort By', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              _chipRow(['default', 'name'], _sortBy, (v) {
                setState(() => _sortBy = v);
                setSheet(() {});
              }),
              const SizedBox(height: 16),
              Text('Filter', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              _chipRow(['all', 'packed', 'unpacked'], _filterStatus, (v) {
                setState(() => _filterStatus = v);
                setSheet(() {});
              }),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
  Widget _chipRow(List<String> options, String selected, Function(String) onTap) {
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () => onTap(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Text(
              _capitalize(opt),
              style: AppTextStyles.caption.copyWith(
                color: isSelected ? AppColors.background : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }
  PreferredSizeWidget _buildAppBar() => AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Traveloop',
            style: AppTextStyles.heading2.copyWith(color: AppColors.primary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.person, color: AppColors.primary, size: 20),
            ),
          ),
        ],
      );
  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(_error!, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: _fetch,
              icon: const Icon(Icons.refresh, color: AppColors.background),
              label: Text('Retry', style: AppTextStyles.buttonText),
            ),
          ],
        ),
      );
  Widget _buildBody() {
    final grouped = _grouped;
    final total = _items.length;
    final packed = _packedCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      children: [
        // ── Search Bar
        _buildSearchBar(),
        const SizedBox(height: 12),
        // ── Group / Filter / Sort Row
        _buildControlRow(),
        const SizedBox(height: 12),
        // ── Trip Selector (static label for now)
        _buildTripSelector(),
        const SizedBox(height: 12),
        // ── Progress
        _buildProgress(packed, total),
        const SizedBox(height: 16),
        // ── Categories
        if (grouped.isEmpty)
          _buildEmpty()
        else
          ...grouped.entries.map((e) => _buildCategory(e.key, e.value)),
        const SizedBox(height: 100),
      ],
    );
  }
  Widget _buildSearchBar() => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: AppTextStyles.body,
          decoration: const InputDecoration(
            hintText: 'Search bar......',
            hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
  Widget _buildControlRow() => Row(
        children: [
          _controlBtn(Icons.group_work_outlined, 'Group by', _showFilterSheet),
          const SizedBox(width: 8),
          _controlBtn(Icons.filter_list, 'Filter', _showFilterSheet),
          const SizedBox(width: 8),
          _controlBtn(Icons.sort, 'Sort by...', _showFilterSheet),
        ],
      );
  Widget _controlBtn(IconData icon, String label, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surfaceSecondary,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(label,
                    style: AppTextStyles.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  Widget _buildTripSelector() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
          color: AppColors.surfaceSecondary,
        ),
        child: Row(
          children: [
            Icon(Icons.flight_takeoff, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Trip: Paris & Rome Adventure',
                style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
          ],
        ),
      );
  Widget _buildProgress(int packed, int total) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress: $packed/$total items packed',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                total == 0 ? '0%' : '${((packed / total) * 100).round()}%',
                style: AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : packed / total,
              minHeight: 8,
              backgroundColor: AppColors.surfaceSecondary,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      );
  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.checklist_rtl, size: 56, color: AppColors.border),
            const SizedBox(height: 12),
            Text('No items found', style: AppTextStyles.bodySecondary),
            const SizedBox(height: 4),
            Text('Tap "+ Add item" to get started',
                style: AppTextStyles.caption),
          ],
        ),
      );
  Widget _buildCategory(String category, List<ChecklistItem> items) {
    final isCollapsed = _collapsed.contains(category);
    final packedInCat = items.where((i) => i.isPacked).length;
    final total = items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        GestureDetector(
          onTap: () => setState(() {
            if (isCollapsed) _collapsed.remove(category);
            else _collapsed.add(category);
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isCollapsed ? Icons.chevron_right : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _capitalize(category),
                    style: AppTextStyles.heading3.copyWith(color: AppColors.primary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$packedInCat/$total',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Items
        if (!isCollapsed)
          ...items.map((item) => _buildItem(item)),
        const SizedBox(height: 10),
      ],
    );
  }
  Widget _buildItem(ChecklistItem item) => Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(color: AppColors.border.withOpacity(0.5), width: 0.5),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: GestureDetector(
            onTap: () => _toggle(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: item.isPacked ? AppColors.primary : AppColors.background,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: item.isPacked ? AppColors.primary : AppColors.border,
                  width: item.isPacked ? 0 : 1.5,
                ),
              ),
              child: item.isPacked
                  ? const Icon(Icons.check, color: AppColors.background, size: 14)
                  : null,
            ),
          ),
          title: Text(
            item.label,
            style: AppTextStyles.body.copyWith(
              decoration: item.isPacked ? TextDecoration.lineThrough : null,
              color: item.isPacked ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
        ),
      );
  Widget _buildBottomBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Add item
            Expanded(
              flex: 3,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _showAddDialog,
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: Text('Add item',
                    style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
              ),
            ),
            const SizedBox(width: 8),
            // Reset
            Expanded(
              flex: 2,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showResetConfirm(),
                child: Text('Reset all',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            // Share
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: _shareChecklist,
                icon: const Icon(Icons.share, size: 16, color: AppColors.background),
                label: Text('Share', style: AppTextStyles.caption.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                )),
              ),
            ),
          ],
        ),
      );
  void _showResetConfirm() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset All Items?', style: AppTextStyles.heading3),
        content: Text(
          'This will uncheck all packed items.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () { Navigator.pop(ctx); _resetAll(); },
            child: Text('Reset', style: AppTextStyles.buttonText),
          ),
        ],
      ),
    );
  }
}