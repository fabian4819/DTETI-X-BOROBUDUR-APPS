import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class AgendaDetailScreen extends StatelessWidget {
  final Map<String, dynamic> agenda;
  
  const AgendaDetailScreen({
    super.key,
    required this.agenda,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Header Image
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // Add bookmark functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Acara ditandai!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
              ),
              IconButton(
                onPressed: () {
                  // Add share functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur berbagi akan segera hadir!'),
                      backgroundColor: Colors.blue,
                    ),
                  );
                },
                icon: const Icon(Icons.share, color: Colors.white),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF1565C0),
                      Color(0xFF0D47A1),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Background pattern or image placeholder
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        child: Icon(
                          _getAgendaIcon(agenda['title']),
                          size: 120,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                    // Content
                    Positioned(
                      bottom: 60,
                      left: 24,
                      right: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              agenda['category'] ?? 'Acara',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            agenda['title'],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event Info
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today,
                          label: 'Tanggal',
                          value: agenda['date'],
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.access_time,
                          label: 'Waktu',
                          value: agenda['time'],
                          color: AppColors.accent,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.location_on,
                          label: 'Lokasi',
                          value: agenda['location'] ?? 'Kompleks Candi Borobudur',
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          icon: Icons.people,
                          label: 'Kapasitas',
                          value: agenda['capacity'] ?? 'Tidak terbatas',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  const Text(
                    'Deskripsi Acara',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Text(
                    agenda['description'],
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.darkGray,
                      height: 1.6,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Activities
                  const Text(
                    'Kegiatan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  ..._getActivities(agenda['title']).map((activity) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              activity['icon'],
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activity['name'],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activity['time'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  const SizedBox(height: 24),
                  
                  // Registration Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _showRegistrationDialog(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.app_registration),
                          SizedBox(width: 8),
                          Text(
                            'Daftar Acara',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  IconData _getAgendaIcon(String title) {
    if (title.toLowerCase().contains('waisak')) {
      return Icons.temple_buddhist;
    } else if (title.toLowerCase().contains('budaya')) {
      return Icons.theater_comedy;
    } else if (title.toLowerCase().contains('festival')) {
      return Icons.festival;
    } else {
      return Icons.event;
    }
  }
  
  List<Map<String, dynamic>> _getActivities(String title) {
    if (title.toLowerCase().contains('waisak')) {
      return [
        {
          'name': 'Prosesi Pindapata',
          'time': '05:00 - 06:00 WIB',
          'icon': Icons.directions_walk,
        },
        {
          'name': 'Meditasi Bersama',
          'time': '06:00 - 07:00 WIB',
          'icon': Icons.self_improvement,
        },
        {
          'name': 'Upacara Waisak',
          'time': '19:00 - 21:00 WIB',
          'icon': Icons.temple_buddhist,
        },
        {
          'name': 'Pelepasan Lampion',
          'time': '21:00 - 22:00 WIB',
          'icon': Icons.lightbulb,
        },
      ];
    } else {
      return [
        {
          'name': 'Pembukaan Acara',
          'time': '08:00 - 09:00 WIB',
          'icon': Icons.play_circle,
        },
        {
          'name': 'Pertunjukan Budaya',
          'time': '09:00 - 12:00 WIB',
          'icon': Icons.theater_comedy,
        },
        {
          'name': 'Workshop Tradisi',
          'time': '13:00 - 15:00 WIB',
          'icon': Icons.school,
        },
        {
          'name': 'Penutupan',
          'time': '16:00 - 17:00 WIB',
          'icon': Icons.stop_circle,
        },
      ];
    }
  }
  
  void _showRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daftar Acara'),
        content: const Text(
          'Apakah Anda ingin mendaftar untuk mengikuti acara ini? '
          'Anda akan menerima konfirmasi melalui email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur akan tersedia di masa mendatang'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Daftar'),
          ),
        ],
      ),
    );
  }
}