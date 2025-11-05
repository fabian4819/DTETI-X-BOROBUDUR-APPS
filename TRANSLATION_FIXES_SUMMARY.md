# Translation Fixes Summary

## Overview
This document tracks all hardcoded text that has been found and needs to be translated across all screen files.

## Files with Hardcoded Text Found

### PROFILE SCREENS
1. **profile_screen.dart** - ✅ FIXED
   - "Loading..." → 'common.loading'.tr()
   - Stats labels (Kunjungan, Favorit, Review) → translated
   - Menu items (Riwayat Kunjungan, Tempat Favorit, etc.) → translated
   - "Versi 1.0.0" → '${'common.version'.tr()} 1.0.0'

2. **favorites_screen.dart** - NEEDS TRANSLATION
   - "Fitur edit akan segera hadir!" → 'profile_detail.edit_coming_soon'.tr()
   - "5 Tempat Favorit" → 'favorites_detail.total_favorites'.tr().replaceAll('{}', '5')
   - "Tempat yang telah Anda simpan" → 'favorites_detail.saved_places'.tr()
   - "Daftar Favorit" → 'favorites_detail.favorite_list'.tr()
   - "${favorite['name']} dihapus dari favorit" → needs .tr()
   - Place descriptions → needs .tr()

3. **visit_history_screen.dart** - NEEDS TRANSLATION
   - "Total Kunjungan", "Bulan Ini", "Jam Total" → needs .tr()
   - "Kunjungan Terakhir" → 'visit_history_detail.recent_visits'.tr()
   - "aktivitas" → 'common.activities'.tr()
   - "Selesai" → 'common.completed'.tr()
   - "jam", "menit" → needs .tr()

### NEWS SCREENS
4. **news_screen.dart** - NEEDS TRANSLATION
   - "Penemuan Baru di Kompleks Borobudur" → 'news_detail.featured_news'.tr()
   - "Tim arkeolog menemukan struktur baru..." → 'news_detail.featured_desc'.tr()
   - "Berita Borobudur {}" → 'news_detail.news_title'.tr()
   - "Deskripsi singkat..." → 'news_detail.news_description'.tr()
   - "{} hari yang lalu" → 'news_detail.days_ago'.tr()

### AGENDA SCREENS
5. **agenda_screen.dart** - NEEDS TRANSLATION
   - "Kalender Acara" → 'agenda_detail.event_calendar'.tr()
   - "Acara Mendatang" → 'agenda_detail.upcoming_events'.tr()
   - "Segera" → 'agenda_detail.event_soon'.tr()
   - All event data (hardcoded event titles, descriptions, etc.)

6. **agenda_detail_screen.dart** - NEEDS TRANSLATION
   - "Acara ditandai!" → 'agenda_detail.event_bookmarked'.tr()
   - "Fitur berbagi akan segera hadir!" → 'agenda_detail.share_coming_soon'.tr()
   - "Tanggal", "Waktu", "Lokasi", "Kapasitas" → needs .tr()
   - "Deskripsi Acara" → 'agenda_detail.event_description'.tr()
   - "Kegiatan" → 'agenda_detail.event_activities'.tr()
   - "Acara" → 'agenda_detail.event_category'.tr()
   - "Daftar Acara" → 'agenda_detail.register_dialog_title'.tr()
   - Dialog messages → needs .tr()

### BOROBUDURPEDIA SCREENS
7. **borobudurpedia_main_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - "Cari di sini" → 'borobudurpedia.search_placeholder'.tr()
   - "0" stats labels (Ensiklopedia, Ebook, Video, Gallery) → needs .tr()
   - "Popular Categories" → 'borobudurpedia_detail.popular_categories'.tr()
   - "Lihat semua" → 'borobudurpedia.see_all'.tr()
   - "Berbagai kategori..." → 'borobudurpedia_detail.categories_subtitle'.tr()
   - "Popular Link" → 'borobudurpedia_detail.popular_link'.tr()
   - "Jelajahi berbagai sumber..." → 'borobudurpedia_detail.popular_link_subtitle'.tr()
   - Category counts → needs .tr()

8. **borobudurpedia_categories_screen.dart** - NEEDS TRANSLATION
   - "Selamat Datang," → 'borobudurpedia_detail.welcome'.tr()
   - "Apa yang ingin kamu pelajari?" → 'borobudurpedia_detail.what_to_learn'.tr()
   - "Lihat apa yang ada di sekitar kamu" → 'borobudurpedia_detail.look_around'.tr()
   - "{} Ensiklopedia" → 'borobudurpedia_detail.encyclopedia_count'.tr()
   - "Pelajari" → 'borobudurpedia_detail.learn_button'.tr()
   - "Gagal membuka artikel..." → 'borobudurpedia_detail.failed_to_open'.tr()

### FACILITIES SCREEN
9. **facilities_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - "Fasilitas Borobudur" → 'facilities_detail.facilities_title'.tr()
   - All facility names and descriptions
   - "Lokasi:" → 'facilities_detail.location_label'.tr()
   - "Informasi Penting" → 'facilities_detail.important_info'.tr()
   - All info bullets → needs .tr()

### NAVIGATION SCREENS
10. **temple_navigation_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - "Navigasi Candi Borobudur" → 'navigation_detail.temple_title'.tr()
   - "Cari lokasi..." → 'navigation_detail.search_placeholder'.tr()
   - "Navigasi" → 'navigation_detail.navigation_button'.tr()
   - Error messages → needs .tr()

11. **api_map_navigation_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - Multiple permission dialog texts
   - "Izin Lokasi Diperlukan" → needs .tr()
   - "Buka Pengaturan Aplikasi" → needs .tr()
   - Navigation button labels → needs .tr()

12. **enhanced_navigation_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - Button labels (Set as Tujuan, Set as Start, etc.)
   - Dialog messages
   - "Selamat!" → 'navigation_detail.congratulations'.tr()

13. **free_navigation_screen.dart** - NEEDS TRANSLATION (NO IMPORT)
   - Missing: import 'package:easy_localization/easy_localization.dart';
   - Map layer names (OpenStreetMap, Satellite, Terrain)
   - All button labels and dialogs
   - "Navigasi Dimulai" → 'navigation_detail.navigation_started_title'.tr()

## Translation Keys Added

All necessary translation keys have been added to:
- `/Users/fabian/Code/borobudur/DTETI-X-BOROBUDUR-APPS/assets/translations/id.json`
- `/Users/fabian/Code/borobudur/DTETI-X-BOROBUDUR-APPS/assets/translations/en.json`

New key groups added:
- `profile_detail.*` - Profile screen specific translations
- `favorites_detail.*` - Favorites screen translations
- `visit_history_detail.*` - Visit history translations
- `news_detail.*` - News screen translations
- `agenda_detail.*` - Agenda screen translations
- `borobudurpedia_detail.*` - Borobudurpedia translations
- `facilities_detail.*` - Facilities screen translations
- `navigation_detail.*` - Navigation screen translations

## Next Steps
All remaining screens need to:
1. Add `import 'package:easy_localization/easy_localization.dart';` if missing
2. Replace hardcoded text with .tr() calls using the new keys
3. Test language switching to verify all text changes properly
