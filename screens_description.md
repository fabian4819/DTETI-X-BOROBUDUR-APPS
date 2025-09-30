# Deskripsi dan Spesifikasi Layar Aplikasi Borobudur

Berikut adalah deskripsi dan spesifikasi untuk setiap layar dalam aplikasi seluler Borobudur:

## 1. Layar Awal (Splash & Onboarding)
*   **Splash Screen (`splash_screen.dart`):** Layar pertama yang muncul saat aplikasi dibuka. Berisi logo atau gambar pembuka untuk memberikan kesan pertama yang menarik.
*   **Onboarding Screen (`onboarding_screen.dart`):** Layar perkenalan yang muncul setelah splash screen (biasanya saat pertama kali membuka aplikasi). Berisi panduan singkat tentang fitur-fitur utama aplikasi untuk membantu pengguna baru memahami cara kerja aplikasi.

## 2. Otentikasi Pengguna (Auth)
*   **Login Screen (`auth/login_screen.dart`):** Halaman ini digunakan pengguna untuk masuk ke dalam aplikasi menggunakan email dan kata sandi yang sudah terdaftar.
*   **Register Screen (`auth/register_screen.dart`):** Halaman ini memungkinkan pengguna baru untuk membuat akun dengan mendaftarkan email dan kata sandi.
*   **Email Verification Screen (`auth/email_verification_screen.dart`):** Setelah registrasi, pengguna akan diarahkan ke layar ini untuk memverifikasi alamat email mereka.
*   **Forgot Password Screen (`auth/forgot_password_screen.dart`):** Jika pengguna lupa kata sandi, mereka dapat menggunakan layar ini untuk meminta tautan reset kata sandi melalui email.
*   **Reset Password Screen (`auth/reset_password_screen.dart`):** Halaman untuk mengatur ulang kata sandi setelah pengguna mengikuti tautan dari email.
*   **Auth Wrapper (`auth_wrapper.dart`):** Komponen ini berfungsi sebagai pembungkus yang memeriksa status login pengguna. Jika sudah login, pengguna akan diarahkan ke halaman utama. Jika belum, akan diarahkan ke halaman login.

## 3. Halaman Utama dan Navigasi
*   **Home Screen (`home/home_screen.dart`):** Halaman utama setelah pengguna berhasil login. Berisi ringkasan fitur-fitur utama seperti Borobudurpedia, Agenda, Berita, dan menu navigasi lainnya.
*   **Main Navigation (`main_navigation.dart`):** Kerangka utama aplikasi yang berisi bottom navigation bar untuk berpindah antar menu utama seperti Home, Borobudurpedia, Agenda, dan Profil.

## 4. Borobudurpedia
*   **Borobudurpedia Main Screen (`borobudurpedia/borobudurpedia_main_screen.dart`):** Halaman utama fitur Borobudurpedia yang menampilkan kategori-kategori informasi yang tersedia.
*   **Borobudurpedia Categories Screen (`borobudurpedia/borobudurpedia_categories_screen.dart`):** Menampilkan daftar artikel atau konten berdasarkan kategori yang dipilih pengguna.
*   **Article Details Screen (`borobudurpedia/article_details_screen.dart`):** Menampilkan isi lengkap dari artikel yang dipilih, termasuk teks, gambar, dan mungkin audio atau video.

## 5. Navigasi Candi
*   **Navigation Selection Screen (`navigation/navigation_selection_screen.dart`):** Halaman di mana pengguna dapat memilih jenis navigasi yang diinginkan, seperti Navigasi Gratis, Navigasi Candi, atau lainnya.
*   **Free Navigation Screen (`navigation/free_navigation_screen.dart`):** Fitur navigasi bebas di sekitar area Candi Borobudur dengan peta interaktif.
*   **Temple Navigation Screen (`navigation/temple_navigation_screen.dart`):** Mode navigasi terpandu yang membawa pengguna menjelajahi bagian-bagian penting dari struktur candi.
*   **Enhanced Navigation Screen (`navigation/enhanced_navigation_screen.dart`):** Versi navigasi yang lebih canggih, kemungkinan dengan fitur Augmented Reality (AR) atau panduan suara yang lebih detail.
*   **API Map Navigation Screen (`navigation/api_map_navigation_screen.dart`):** Layar navigasi yang terintegrasi dengan API peta eksternal (seperti Google Maps) untuk fungsionalitas yang lebih kaya.

## 6. Agenda dan Berita
*   **Agenda Screen (`agenda/agenda_screen.dart`):** Menampilkan daftar acara atau agenda kegiatan yang akan berlangsung di Borobudur.
*   **Agenda Detail Screen (`agenda/agenda_detail_screen.dart`):** Menampilkan informasi rinci tentang suatu acara, termasuk waktu, lokasi, dan deskripsi.
*   **News Screen (`news/news_screen.dart`):** Berisi daftar berita atau artikel terkini terkait Borobudur dan sekitarnya.

## 7. Fasilitas
*   **Facilities Screen (`facilities/facilities_screen.dart`):** Menampilkan informasi mengenai fasilitas yang tersedia di kawasan Candi Borobudur, seperti toilet, area parkir, tempat ibadah, dan lain-lain.

## 8. Profil Pengguna
*   **Profile Screen (`profile/profile_screen.dart`):** Halaman yang menampilkan informasi profil pengguna, seperti nama dan email. Dari sini, pengguna dapat mengakses menu lain seperti Favorit, Riwayat Kunjungan, dan Pengaturan.
*   **Favorites Screen (`profile/favorites_screen.dart`):** Menampilkan daftar artikel atau item lain yang telah ditandai sebagai favorit oleh pengguna.
*   **Visit History Screen (`profile/visit_history_screen.dart`):** Berisi riwayat kunjungan atau aktivitas navigasi yang pernah dilakukan pengguna.
*   **Settings Screen (`profile/settings_screen.dart`):** Halaman di mana pengguna dapat mengubah pengaturan aplikasi, seperti bahasa, notifikasi, atau tema.
