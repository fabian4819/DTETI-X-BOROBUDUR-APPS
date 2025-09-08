import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

class ArticleDetailsScreen extends StatelessWidget {
  final String title;
  final String category;
  
  const ArticleDetailsScreen({
    super.key,
    required this.title,
    required this.category,
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
                onPressed: () {},
                icon: const Icon(Icons.bookmark_border, color: Colors.white),
              ),
              IconButton(
                onPressed: () {},
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
                        child: const Icon(
                          Icons.temple_buddhist,
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
                              category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
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
                  // Article Info
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tim Borobudurpedia',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkGray,
                              ),
                            ),
                            Text(
                              '15 Januari 2024 • 5 min read',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.more_horiz,
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Article Content
                  Text(
                    _getArticleIntro(title),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.mediumGray,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    _getArticleContent(title),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.darkGray,
                      height: 1.7,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Image placeholder
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image,
                          size: 60,
                          color: AppColors.mediumGray,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Ilustrasi terkait artikel',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    _getArticleContent2(title),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.darkGray,
                      height: 1.7,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Tags
                  const Text(
                    'Tags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getArticleTags(category).map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Related Articles
                  const Text(
                    'Artikel Terkait',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(3, (index) {
                    final relatedTitles = _getRelatedArticles(category);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.lightGray.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.article,
                              color: AppColors.mediumGray,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  relatedTitles[index % relatedTitles.length],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.darkGray,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.mediumGray,
                          ),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getArticleIntro(String title) {
    switch (title.toLowerCase()) {
      case 'relief borobudur':
        return 'Setiap panel relief di Candi Borobudur menceritakan kisah spiritual yang mendalam, menggabungkan seni pahat yang indah dengan filosofi Buddha yang agung.';
      case 'stupa utama':
        return 'Stupa utama Borobudur berdiri megah di puncak candi sebagai simbol pencapaian tertinggi dalam perjalanan spiritual manusia menuju pencerahan.';
      case 'batu andesit':
        return 'Batu andesit yang digunakan dalam pembangunan Candi Borobudur menunjukkan keahlian luar biasa para arsitek masa lalu dalam memilih material yang tahan lama.';
      default:
        return 'Artikel ini membahas salah satu aspek penting dari warisan budaya Candi Borobudur yang perlu kita ketahui dan lestarikan untuk generasi mendatang.';
    }
  }
  
  String _getArticleContent(String title) {
    switch (title.toLowerCase()) {
      case 'relief borobudur':
        return '''Candi Borobudur memiliki lebih dari 2.600 panel relief yang tersebar di seluruh dinding candi. Panel-panel ini dibagi menjadi beberapa tingkat, masing-masing menceritakan bagian yang berbeda dari ajaran Buddha.

Relief di tingkat bawah (Kamadhatu) menggambarkan kehidupan duniawi dengan segala hasrat dan nafsu yang melekat pada manusia. Kemudian relief di tingkat Rupadhatu menceritakan kehidupan Sang Buddha dari kelahiran hingga mencapai pencerahan.

Setiap panel dipahat dengan detail yang luar biasa, menampilkan ekspresi wajah, gerakan tubuh, dan ornamen yang hidup. Para pemahat masa lalu berhasil mentransformasi ajaran abstrak Buddha menjadi karya seni visual yang dapat dipahami oleh masyarakat pada masa itu.''';
      case 'stupa utama':
        return '''Stupa utama Candi Borobudur memiliki tinggi sekitar 35 meter dan merupakan puncak dari seluruh struktur candi. Stupa ini dibangun dalam bentuk setengah bola yang melambangkan alam semesta dalam kosmologi Buddha.

Di sekitar stupa utama terdapat 72 stupa kecil yang mengitarinya dalam tiga tingkat melingkar. Setiap stupa kecil ini mengandung arca Buddha dalam posisi dhyana mudra (meditasi). Konsep ini melambangkan perjalanan spiritual dari dunia materi menuju pencerahan tertinggi.

Struktur stupa ini juga berfungsi sebagai mandala tiga dimensi, tempat umat Buddha melakukan ritual parikrama (berjalan mengelilingi stupa) sebagai bentuk meditasi dan penghormatan.''';
      case 'batu andesit':
        return '''Candi Borobudur dibangun menggunakan sekitar 55.000 meter kubik batu andesit yang diambil dari sungai-sungai sekitar lokasi candi. Pemilihan batu andesit bukan tanpa alasan - material ini memiliki sifat yang sangat cocok untuk konstruksi monumental.

Batu andesit memiliki kepadatan yang tinggi dan daya tahan yang luar biasa terhadap cuaca tropis. Sifat ini memungkinkan Candi Borobudur bertahan selama lebih dari seribu tahun meskipun terpapar hujan, panas matahari, dan berbagai kondisi alam ekstrem.

Para ahli batu masa lalu juga memahami teknik pemotongan dan penyusunan batu yang sangat presisi. Setiap blok batu dipotong dengan ukuran yang tepat dan disusun tanpa menggunakan perekat, namun tetap kokoh berkat teknik sambungan yang sempurna.''';
      default:
        return '''Candi Borobudur sebagai warisan dunia UNESCO memiliki nilai historis dan budaya yang tak ternilai. Setiap elemen dari candi ini memiliki cerita dan makna yang mendalam, mencerminkan tingginya peradaban dan spiritualitas masyarakat Jawa kuno.

Pembangunan candi yang dimulai pada abad ke-8 Masehi ini melibatkan ribuan pekerja dan arsitek terbaik pada masanya. Mereka berhasil menciptakan masterpiece arsitektur yang tidak hanya indah secara visual, tetapi juga sarat dengan makna filosofis dan religius.

Hingga kini, Candi Borobudur terus menjadi sumber inspirasi dan pembelajaran bagi generasi masa kini. Setiap kunjungan ke candi ini membawa kita pada perjalanan spiritual yang sama seperti yang dimaksudkan oleh para pembangunnya ratusan tahun yang lalu.''';
    }
  }
  
  String _getArticleContent2(String title) {
    switch (title.toLowerCase()) {
      case 'relief borobudur':
        return '''Proses pembuatan relief Borobudur melibatkan teknik pahatan yang sangat canggih untuk masanya. Para seniman tidak hanya menguasai teknik memahat, tetapi juga memahami dengan baik ajaran Buddha yang akan mereka visualisasikan.

Setiap relief dibuat dengan mempertimbangkan pencahayaan alami, sehingga bayangan yang terbentuk akan memperkuat kesan dramatis dari cerita yang digambarkan. Hal ini menunjukkan betapa matangnya perencanaan artistik dalam pembangunan candi ini.

Kini, upaya konservasi terus dilakukan untuk menjaga keutuhan relief-relief berharga ini. Teknologi modern digunakan untuk membersihkan dan melindungi panel-panel relief dari kerusakan akibat polusi, cuaca, dan faktor alam lainnya.''';
      case 'stupa utama':
        return '''Makna simbolis stupa utama sangat mendalam dalam tradisi Buddha. Bentuk setengah bola melambangkan kubah langit yang melingkupi bumi, sementara bagian dasar persegi melambangkan bumi itu sendiri. Perpaduan ini menggambarkan kesatuan antara dunia materi dan spiritual.

Dalam ritual keagamaan, umat Buddha akan berjalan mengelilingi stupa utama searah jarum jam sambil bermeditasi atau membaca mantra. Aktivitas ini disebut pradaksina dan dipercaya dapat membawa keberkahan serta mempercepat perjalanan spiritual.

Stupa utama juga berfungsi sebagai pusat energi spiritual dari seluruh kompleks Borobudur. Dari titik ini, seluruh struktur candi terpancar dalam pola mandala yang sempurna, menciptakan harmoni arsitektur yang luar biasa.''';
      case 'batu andesit':
        return '''Teknik pengolahan batu andesit pada masa pembangunan Borobudur menunjukkan kemajuan teknologi yang mengagumkan. Para pengrajin menggunakan alat-alat sederhana namun mampu menghasilkan pemotongan yang sangat presisi dan permukaan yang halus.

Sistem transportasi batu dari lokasi penambangan ke lokasi pembangunan juga menjadi tantangan besar. Diperkirakan para pekerja menggunakan sistem rel kayu dan tenaga manusia untuk memindahkan blok-blok batu yang beratnya mencapai beberapa ton.

Analisis modern terhadap struktur batu Borobudur menunjukkan bahwa para arsitek masa lalu telah mempertimbangkan faktor drainase air hujan dengan sangat baik. Sistem saluran air yang terintegrasi dalam struktur batu mencegah kerusakan akibat genangan air dan erosi.''';
      default:
        return '''Pelestarian Candi Borobudur menjadi tanggung jawab bersama seluruh masyarakat Indonesia dan dunia. Berbagai upaya telah dilakukan, mulai dari restorasi fisik hingga digitalisasi untuk dokumentasi dan penelitian.

Program edukasi dan sosialisasi terus digalakkan untuk meningkatkan kesadaran masyarakat tentang pentingnya menjaga warisan budaya ini. Setiap generasi memiliki peran dalam memastikan bahwa keajaiban Borobudur dapat dinikmati oleh anak cucu kita.

Teknologi modern kini memungkinkan kita untuk mempelajari Borobudur dengan cara yang tidak pernah ada sebelumnya. Pemindaian 3D, analisis material, dan rekonstruksi digital membuka wawasan baru tentang teknik pembangunan dan makna filosofis dari candi agung ini.''';
    }
  }
  
  List<String> _getArticleTags(String category) {
    switch (category.toLowerCase()) {
      case 'arsitektur':
        return ['Arsitektur', 'Candi', 'Borobudur', 'Warisan Dunia', 'Struktur'];
      case 'alat':
        return ['Alat', 'Konstruksi', 'Teknologi', 'Sejarah', 'Pembangunan'];
      case 'bahan':
        return ['Bahan', 'Andesit', 'Material', 'Konstruksi', 'Geologi'];
      case 'buddha':
      case 'budha':
        return ['Buddha', 'Spiritualitas', 'Relief', 'Filosofi', 'Agama'];
      default:
        return ['Borobudur', 'Warisan', 'Budaya', 'Sejarah', 'Indonesia'];
    }
  }
  
  List<String> _getRelatedArticles(String category) {
    switch (category.toLowerCase()) {
      case 'arsitektur':
        return [
          'Teknik Konstruksi Candi Borobudur',
          'Sistem Drainase Kuno Borobudur', 
          'Geometri Sakral dalam Arsitektur Candi'
        ];
      case 'alat':
        return [
          'Alat-alat Pahat Tradisional Jawa',
          'Teknologi Pemindahan Batu Raksasa',
          'Peralatan Konstruksi Masa Sailendra'
        ];
      case 'bahan':
        return [
          'Jenis-jenis Batu dalam Candi Borobudur',
          'Proses Pemilihan Material Bangunan',
          'Analisis Mineralogi Batu Andesit'
        ];
      case 'buddha':
      case 'budha':
        return [
          'Ajaran Buddha dalam Relief Borobudur',
          'Simbolisme Stupa dan Arca Buddha',
          'Perjalanan Spiritual Sang Buddha'
        ];
      default:
        return [
          'Sejarah Penemuan Candi Borobudur',
          'Restorasi Besar-besaran Borobudur',
          'Borobudur sebagai Situs Warisan Dunia'
        ];
    }
  }
}