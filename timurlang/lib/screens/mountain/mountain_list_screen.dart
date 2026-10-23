// ============================================
// TimurLang - Mountain List Screen
// Search & filter mountains
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../models/mountain.dart';
import '../../services/database_service.dart';
import '../../widgets/mountain_card.dart';

class MountainListScreen extends StatefulWidget {
  final bool embedded;
  const MountainListScreen({super.key, this.embedded = false});

  @override
  State<MountainListScreen> createState() => _MountainListScreenState();
}

class _MountainListScreenState extends State<MountainListScreen> {
  List<Mountain> _mountains = [];
  List<Mountain> _filtered = [];
  bool _isLoading = true;
  String? _selectedGrade;
  bool? _sumberAir;
  RangeValues _elevasiRange = const RangeValues(0, 5000);
  final _searchCtrl = TextEditingController();
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadMountains();
  }

  Future<void> _loadMountains() async {
    try {
      final mountains = await DatabaseService.instance.getAllMountains();
      setState(() {
        _mountains = mountains;
        _filtered = mountains;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filtered = _mountains.where((m) {
        // Search
        if (_searchCtrl.text.isNotEmpty) {
          if (!m.namaGunung.toLowerCase().contains(_searchCtrl.text.toLowerCase())) {
            return false;
          }
        }
        // Elevation
        if (m.elevasiMdpl < _elevasiRange.start || m.elevasiMdpl > _elevasiRange.end) {
          return false;
        }
        // Grade
        if (_selectedGrade != null && m.tingkatBahaya != _selectedGrade) {
          return false;
        }
        // Water source
        if (_sumberAir != null && m.sumberAirTersedia != _sumberAir) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedGrade = null;
      _sumberAir = null;
      _elevasiRange = const RangeValues(0, 5000);
      _filtered = _mountains;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _selectedGrade != null ||
        _sumberAir != null ||
        _elevasiRange.start > 0 ||
        _elevasiRange.end < 5000 ||
        _searchCtrl.text.isNotEmpty;

    final content = CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        if (!widget.embedded)
          const SliverAppBar(
            title: Text('Cari Gunung'),
            floating: true,
            snap: true,
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Jelajahi Gunung',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => _applyFilters(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Cari nama gunung...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 13.5,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showFilters = !_showFilters),
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _showFilters
                              ? AppTheme.primary.withValues(alpha: 0.15)
                              : AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _showFilters
                                ? AppTheme.primary.withValues(alpha: 0.3)
                                : AppTheme.border,
                          ),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _showFilters ? AppTheme.primary : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
                // Filters
                if (_showFilters) ...[
                  const SizedBox(height: 14),
                  _buildFilters(),
                ],
                const SizedBox(height: 14),
                // Results count & reset
                Row(
                  children: [
                    Text(
                      '${_filtered.length} gunung ditemukan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (hasActiveFilter)
                      GestureDetector(
                        onTap: _resetFilters,
                        child: Text(
                          'Reset Filter',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          )
        else if (_filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terrain_rounded,
                    size: 64,
                    color: AppTheme.textSecondary.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Gunung tidak ditemukan',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  return MountainCard(
                    mountain: _filtered[i],
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.mountainDetail,
                      arguments: _filtered[i],
                    ),
                  );
                },
                childCount: _filtered.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: 80),
        ),
      ],
    );

    if (widget.embedded) {
      return SafeArea(child: content);
    }

    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildFilters() {
    final hasActiveFilter = _selectedGrade != null ||
        _sumberAir != null ||
        _elevasiRange.start > 0 ||
        _elevasiRange.end < 5000;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textPrimary.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Header
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Filter Pencarian',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (hasActiveFilter)
                InkWell(
                  onTap: _resetFilters,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Reset',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.border),
          const SizedBox(height: 14),

          // Elevation Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rentang Elevasi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primarySubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${_elevasiRange.start.round()} - ${_elevasiRange.end.round()} mdpl',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.surfaceSubtle,
              thumbColor: AppTheme.primary,
              overlayColor: AppTheme.primary.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: RangeSlider(
              values: _elevasiRange,
              min: 0,
              max: 5000,
              divisions: 50,
              onChanged: (v) {
                setState(() => _elevasiRange = v);
                _applyFilters();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0 mdpl',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Text(
                  '5.000 mdpl',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tingkat Bahaya (Grade)
          Text(
            'Tingkat Kesulitan / Bahaya',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.mountainGrades.map((grade) {
              final label = grade.split(' - ').first;
              final isSelected = _selectedGrade == grade;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() => _selectedGrade = isSelected ? null : grade);
                  _applyFilters();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                      width: 1.1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Sumber Air (clean options without checkmark AI slop)
          Text(
            'Ketersediaan Sumber Air',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildWaterFilterOption(
                label: 'Semua',
                isSelected: _sumberAir == null,
                icon: Icons.all_inclusive_rounded,
                onTap: () {
                  setState(() => _sumberAir = null);
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
              _buildWaterFilterOption(
                label: 'Tersedia Air',
                isSelected: _sumberAir == true,
                icon: Icons.water_drop_outlined,
                onTap: () {
                  setState(() => _sumberAir = _sumberAir == true ? null : true);
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
              _buildWaterFilterOption(
                label: 'Tanpa Air',
                isSelected: _sumberAir == false,
                icon: Icons.water_drop_outlined,
                onTap: () {
                  setState(() => _sumberAir = _sumberAir == false ? null : false);
                  _applyFilters();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaterFilterOption({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: 1.1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
