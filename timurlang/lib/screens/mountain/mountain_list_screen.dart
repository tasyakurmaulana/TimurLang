// ============================================
// TimurLang - Mountain List Screen
// Search & filter mountains
// ============================================

import 'package:flutter/material.dart';
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
    final content = Column(
      children: [
        if (!widget.embedded)
          AppBar(title: const Text('Cari Gunung')),
        Padding(
          padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.embedded) ...[
                const SizedBox(height: 32),
                const Text(
                  'Jelajahi Gunung 🏔️',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
              ],
              // Search bar
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Cari nama gunung...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: GestureDetector(
                    onTap: () => setState(() => _showFilters = !_showFilters),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _showFilters
                            ? AppTheme.primaryGreen.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.tune,
                        size: 18,
                        color: _showFilters ? AppTheme.primaryGreen : Colors.white54,
                      ),
                    ),
                  ),
                ),
              ),
              // Filters
              if (_showFilters) ...[
                const SizedBox(height: 16),
                _buildFilters(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${_filtered.length} gunung ditemukan',
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5)),
              ),
              const Spacer(),
              if (_selectedGrade != null || _sumberAir != null)
                GestureDetector(
                  onTap: _resetFilters,
                  child: const Text(
                    'Reset Filter',
                    style: TextStyle(fontSize: 13, color: AppTheme.primaryGreen),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terrain, size: 60, color: Colors.white.withValues(alpha: 0.15)),
                          const SizedBox(height: 12),
                          Text(
                            'Gunung tidak ditemukan',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, i) {
                        return MountainCard(
                          mountain: _filtered[i],
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.mountainDetail,
                            arguments: _filtered[i],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );

    if (widget.embedded) {
      return SafeArea(child: content);
    }

    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elevation slider
          Text('Elevasi (mdpl)', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          RangeSlider(
            values: _elevasiRange,
            min: 0,
            max: 5000,
            divisions: 50,
            labels: RangeLabels(
              '${_elevasiRange.start.round()} m',
              '${_elevasiRange.end.round()} m',
            ),
            activeColor: AppTheme.primaryGreen,
            onChanged: (v) {
              setState(() => _elevasiRange = v);
              _applyFilters();
            },
          ),
          const SizedBox(height: 8),
          // Grade filter
          Text('Tingkat Bahaya', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: AppConstants.mountainGrades.map((grade) {
              final isSelected = _selectedGrade == grade;
              return FilterChip(
                label: Text(grade.split(' - ').first),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _selectedGrade = selected ? grade : null);
                  _applyFilters();
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          // Water source
          Text('Sumber Air', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Row(
            children: [
              FilterChip(
                label: const Text('Ada ✓'),
                selected: _sumberAir == true,
                onSelected: (s) {
                  setState(() => _sumberAir = s ? true : null);
                  _applyFilters();
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Tidak ada'),
                selected: _sumberAir == false,
                onSelected: (s) {
                  setState(() => _sumberAir = s ? false : null);
                  _applyFilters();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
