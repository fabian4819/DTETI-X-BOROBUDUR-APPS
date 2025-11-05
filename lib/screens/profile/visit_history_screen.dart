import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class VisitHistoryScreen extends StatelessWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('profile.visit_history'.tr()),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '12',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'visit_history_detail.total_visits'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '8',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'visit_history_detail.this_month'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '24',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'visit_history_detail.total_hours'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            Text(
              'visit_history_detail.recent_visits'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Visit history list
            ...List.generate(_getVisitHistory().length, (index) {
              final visit = _getVisitHistory()[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: visit['color'].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        visit['icon'],
                        color: visit['color'],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit['location'],
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            visit['date'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${visit['duration']} • ${visit['activities']} ${'common.activities'.tr()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Selesai',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  List<Map<String, dynamic>> _getVisitHistory() {
    return [
      {
        'location': 'visit_history_detail.temple_main_name'.tr(),
        'date': '15 Januari 2025',
        'duration': '3 ${'visit_history_detail.hours'.tr()}',
        'activities': 5,
        'icon': Icons.temple_buddhist,
        'color': AppColors.primary,
      },
      {
        'location': 'visit_history_detail.museum_name'.tr(),
        'date': '12 Januari 2025',
        'duration': '2 ${'visit_history_detail.hours'.tr()}',
        'activities': 3,
        'icon': Icons.museum,
        'color': AppColors.accent,
      },
      {
        'location': 'visit_history_detail.lumbini_park_name'.tr(),
        'date': '8 Januari 2025',
        'duration': '1.5 ${'visit_history_detail.hours'.tr()}',
        'activities': 2,
        'icon': Icons.park,
        'color': AppColors.success,
      },
      {
        'location': 'visit_history_detail.mendut_temple_name'.tr(),
        'date': '5 Januari 2025',
        'duration': '1 ${'visit_history_detail.hours'.tr()}',
        'activities': 2,
        'icon': Icons.account_balance,
        'color': AppColors.secondary,
      },
      {
        'location': 'visit_history_detail.pawon_temple_name'.tr(),
        'date': '2 Januari 2025',
        'duration': '45 ${'visit_history_detail.minutes'.tr()}',
        'activities': 1,
        'icon': Icons.foundation,
        'color': AppColors.warning,
      },
    ];
  }
}