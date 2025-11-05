import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'agenda_detail_screen.dart';

class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('agenda.title'.tr()),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar widget placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 60,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'agenda_detail.event_calendar'.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            Text(
              'agenda_detail.upcoming_events'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Upcoming events
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _getAgendaList().length,
              itemBuilder: (context, index) {
                final agenda = _getAgendaList()[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AgendaDetailScreen(agenda: agenda),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: index == 0 ? AppColors.primary : AppColors.lightGray,
                        width: index == 0 ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: index == 0 ? AppColors.primary : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                agenda['day'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: index == 0 ? Colors.white : AppColors.darkGray,
                                ),
                              ),
                              Text(
                                agenda['month'],
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: index == 0 ? Colors.white : AppColors.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agenda['title'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                agenda['shortDescription'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mediumGray,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: AppColors.mediumGray,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    agenda['time'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (index == 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'agenda_detail.event_soon'.tr(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.mediumGray,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAgendaList() {
    return [
      {
        'title': 'Perayaan Waisak di Borobudur 2025',
        'shortDescription': 'Perayaan hari raya Waisak yang diselenggarakan di kompleks Candi Borobudur dengan rangkaian acara spiritual dan budaya',
        'description': 'Perayaan Waisak (Vesak) merupakan hari raya Buddha yang memperingati kelahiran, pencerahan, dan wafatnya Sang Buddha Gautama. Perayaan ini diselenggarakan secara khidmat di Candi Borobudur dengan berbagai rangkaian acara spiritual dan budaya yang melibatkan umat Buddha dari seluruh dunia.\n\nAcara dimulai dari dini hari dengan prosesi Pindapata (keliling mengumpulkan dana), dilanjutkan dengan meditasi bersama saat matahari terbit. Puncak acara adalah upacara Waisak di malam hari yang diakhiri dengan pelepasan lampion sebagai simbol pencerahan dan harapan.',
        'date': '9 Mei 2025',
        'day': '9',
        'month': 'MEI',
        'time': '05:00 - 22:00 WIB',
        'location': 'Kompleks Candi Borobudur',
        'category': 'Keagamaan',
        'capacity': '10.000 orang',
      },
      {
        'title': 'Festival Budaya Jawa Tengah',
        'shortDescription': 'Festival yang menampilkan keragaman budaya Jawa Tengah dengan berbagai pertunjukan seni tradisional dan modern',
        'description': 'Festival Budaya Jawa Tengah adalah event tahunan yang menampilkan kekayaan budaya dari berbagai daerah di Jawa Tengah. Festival ini menampilkan pertunjukan tari tradisional, musik gamelan, wayang kulit, dan berbagai kesenian daerah lainnya.\n\nSelain pertunjukan, festival ini juga menampilkan pameran kerajinan tradisional, kuliner khas Jawa Tengah, dan workshop untuk mempelajari berbagai kesenian tradisional. Acara ini menjadi wadah pelestarian budaya sekaligus promosi pariwisata daerah.',
        'date': '15 Juni 2025',
        'day': '15',
        'month': 'JUN',
        'time': '08:00 - 17:00 WIB',
        'location': 'Taman Lumbini Borobudur',
        'category': 'Budaya',
        'capacity': '5.000 orang',
      },
      {
        'title': 'Konser Musik Etnik Nusantara',
        'shortDescription': 'Pertunjukan musik etnik dari berbagai daerah di Indonesia dengan latar belakang Candi Borobudur yang megah',
        'description': 'Konser Musik Etnik Nusantara menghadirkan pertunjukan musik tradisional dari berbagai suku dan daerah di Indonesia. Konser ini menampilkan alat musik tradisional seperti gamelan, angklung, sasando, dan berbagai alat musik etnik lainnya.\n\nDengan latar belakang Candi Borobudur yang megah di malam hari, konser ini menawarkan pengalaman musikal yang tak terlupakan. Acara ini juga menjadi ajang apresiasi terhadap kekayaan budaya musik Indonesia.',
        'date': '20 Juli 2025',
        'day': '20',
        'month': 'JUL',
        'time': '19:00 - 22:00 WIB',
        'location': 'Halaman Candi Borobudur',
        'category': 'Musik',
        'capacity': '3.000 orang',
      },
      {
        'title': 'Workshop Fotografi Heritage',
        'shortDescription': 'Workshop fotografi untuk mengabadikan keindahan warisan budaya Candi Borobudur dengan teknik profesional',
        'description': 'Workshop Fotografi Heritage adalah program edukasi untuk fotografer pemula hingga mahir yang ingin mempelajari teknik fotografi arsitektur dan heritage. Workshop ini dipandu oleh fotografer profesional yang berpengalaman dalam fotografi warisan budaya.\n\nPeserta akan belajar teknik komposisi, pencahayaan, dan editing khusus untuk fotografi bangunan bersejarah. Workshop ini juga memberikan akses khusus untuk mengambil foto di area tertentu Candi Borobudur pada golden hour.',
        'date': '10 Agustus 2025',
        'day': '10',
        'month': 'AGT',
        'time': '06:00 - 12:00 WIB',
        'location': 'Kompleks Candi Borobudur',
        'category': 'Edukasi',
        'capacity': '50 orang',
      },
    ];
  }
}