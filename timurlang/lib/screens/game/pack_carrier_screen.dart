// ============================================
// TimurLang - Pack Your Carrier Mini Game
// ============================================

import 'package:flutter/material.dart';
import '../../config/theme.dart';

class CarrierItem {
  final String name;
  final int weight; // 1-5 scale
  final IconData icon;
  final Color color;

  CarrierItem(this.name, this.weight, this.icon, this.color);
}

class PackCarrierScreen extends StatefulWidget {
  const PackCarrierScreen({super.key});

  @override
  State<PackCarrierScreen> createState() => _PackCarrierScreenState();
}

class _PackCarrierScreenState extends State<PackCarrierScreen> {
  // Carrier zones (Top, Middle, Bottom)
  final List<CarrierItem> _topZone = [];
  final List<CarrierItem> _middleZone = [];
  final List<CarrierItem> _bottomZone = [];

  final List<CarrierItem> _availableItems = [
    CarrierItem('Sleeping Bag (Ringan)', 1, Icons.bed, Colors.blue),
    CarrierItem('Pakaian Ganti (Sedang)', 2, Icons.checkroom, Colors.cyan),
    CarrierItem('Peralatan Masak (Berat)', 4, Icons.soup_kitchen, Colors.orange),
    CarrierItem('Logistik Makanan (Sangat Berat)', 5, Icons.restaurant, AppTheme.dangerRed),
    CarrierItem('Tenda (Berat)', 4, Icons.holiday_village, Colors.green),
    CarrierItem('Jas Hujan & P3K (Akses Cepat)', 2, Icons.medical_services, Colors.redAccent),
  ];

  int _score = 0;
  bool _isEvaluated = false;

  void _evaluatePacking() {
    _score = 0;
    
    // Ideal:
    // Bottom: Sleeping bag, clothes (light, bulky)
    // Middle: Heavy items (Tent, Food, Cooking gear) - close to back
    // Top: Quick access (Raincoat, First Aid)
    
    for (var item in _bottomZone) {
      if (item.weight <= 2) { _score += 20; } // Good
      else { _score -= 10; } // Bad (Heavy at bottom pulls you down)
    }

    for (var item in _middleZone) {
      if (item.weight >= 4) { _score += 20; } // Good (Heavy in middle near spine)
      else { _score += 5; } // Neutral
    }

    for (var item in _topZone) {
      if (item.name.contains('Akses Cepat')) { _score += 30; } // Excellent
      else if (item.weight >= 4) { _score -= 20; } // Bad (Top heavy = unstable)
      else { _score += 10; }
    }

    // Clamp score 0-100
    if (_score < 0) _score = 0;
    if (_score > 100) _score = 100;

    setState(() {
      _isEvaluated = true;
    });
  }

  void _resetGame() {
    setState(() {
      _availableItems.addAll(_topZone);
      _availableItems.addAll(_middleZone);
      _availableItems.addAll(_bottomZone);
      _topZone.clear();
      _middleZone.clear();
      _bottomZone.clear();
      _isEvaluated = false;
      _score = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Game: Pack Your Carrier')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardDark,
            child: const Text(
              'Susun barang bawaan dengan benar! Barang berat harus dekat dengan punggung (tengah), barang ringan di bawah, dan barang penting di atas.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ),
          
          Expanded(
            child: Row(
              children: [
                // Available Items
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.black12,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text('Barang', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _availableItems.length,
                            itemBuilder: (context, i) {
                              return Draggable<CarrierItem>(
                                data: _availableItems[i],
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _buildItemCard(_availableItems[i]),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildItemCard(_availableItems[i]),
                                ),
                                child: _buildItemCard(_availableItems[i]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Carrier
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryGreen, width: 3),
                      ),
                      child: Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('CARRIER (RANSEL)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Expanded(child: _buildZone('Bagian Atas (Top Lid)', _topZone)),
                          const Divider(color: AppTheme.primaryGreen, height: 1),
                          Expanded(flex: 2, child: _buildZone('Bagian Tengah (Main Comp)', _middleZone)),
                          const Divider(color: AppTheme.primaryGreen, height: 1),
                          Expanded(child: _buildZone('Bagian Bawah (Bottom)', _bottomZone)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer Evaluation
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardDark,
            child: _isEvaluated
                ? Column(
                    children: [
                      Text(
                        'Skor Anda: $_score/100',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _score > 70 ? AppTheme.safeGreen : AppTheme.dangerRed,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _score > 80 ? 'Hebat! Anda siap mendaki.' : 'Masih kurang tepat, ransel bisa membuat Anda cepat lelah atau tidak stabil.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _resetGame, child: const Text('Main Lagi')),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _availableItems.isEmpty ? _evaluatePacking : null,
                      child: const Text('Evaluasi Susunan'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(CarrierItem item) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: item.color),
      ),
      child: Column(
        children: [
          Icon(item.icon, color: item.color),
          const SizedBox(height: 4),
          Text(item.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildZone(String label, List<CarrierItem> zoneList) {
    return DragTarget<CarrierItem>(
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: double.infinity,
          color: candidateData.isNotEmpty ? Colors.white12 : Colors.transparent,
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
              Expanded(
                child: Wrap(
                  children: zoneList.map((item) => GestureDetector(
                    onTap: () {
                      setState(() {
                        zoneList.remove(item);
                        _availableItems.add(item);
                      });
                    },
                    child: SizedBox(
                      width: 80,
                      child: _buildItemCard(item),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        );
      },
      onWillAcceptWithDetails: (data) => !_isEvaluated,
      onAcceptWithDetails: (details) {
        setState(() {
          _availableItems.remove(details.data);
          zoneList.add(details.data);
        });
      },
    );
  }
}
