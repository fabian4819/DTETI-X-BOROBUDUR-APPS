# Mapbox Directions API Setup

## Overview
Aplikasi ini menggunakan Mapbox Directions API untuk menampilkan route navigasi yang mengikuti jalur jalan sebenarnya (bukan garis lurus).

## Mengapa Perlu Directions API?
- ✅ Route mengikuti jalan yang ada
- ✅ Mendapatkan jarak dan waktu tempuh yang akurat
- ✅ Styling route dengan traffic colors
- ✅ Turn-by-turn navigation instructions

## Cara Mendapatkan Mapbox Access Token

### 1. Login ke Mapbox Account
Anda sudah menggunakan Mapbox Maps Flutter, jadi pasti sudah punya account di https://account.mapbox.com

### 2. Buka Tokens Page
- Kunjungi: https://account.mapbox.com/access-tokens/
- Atau dari dashboard, klik "Tokens" di menu samping

### 3. Copy Access Token
Anda bisa menggunakan **Default Public Token** yang sudah ada, atau membuat token baru:

#### Option A: Gunakan Default Public Token (Recommended)
- Token dengan nama "Default public token" sudah ada
- Copy token tersebut (biasanya dimulai dengan `pk.`)
- Token ini sudah memiliki semua permissions yang diperlukan

#### Option B: Buat Token Baru (Opsional)
Jika ingin membuat token khusus untuk Directions API:
1. Click "Create a token"
2. Beri nama, misalnya: "Borobudur App Directions"
3. Pastikan scope berikut aktif:
   - ✅ `styles:read`
   - ✅ `fonts:read`
   - ✅ `datasets:read`
   - ✅ `vision:read`
   - ✅ `navigation:read` (penting untuk Directions API)
4. Click "Create token"
5. Copy token yang baru dibuat

### 4. Tambahkan Token ke Config
Buka file `lib/config/map_config.dart` dan update:

```dart
// Mapbox Access Token for Directions API
static const String mapboxAccessToken = 'pk.eyJ1IjoieW91ci11c2VybmFtZSIsImEiOiJjbHh4eHh4eHgifQ.xxxxxxxxxxxxxxxxxxx';
```

Replace dengan token yang Anda copy dari langkah 3.

### 5. Cari Token yang Sudah Ada (Jika Lupa)
Token yang sama kemungkinan sudah digunakan di konfigurasi Mapbox Maps Flutter. Cek di:

**Android:**
```xml
android/app/src/main/AndroidManifest.xml
```
Cari line seperti:
```xml
<meta-data
    android:name="MAPBOX_ACCESS_TOKEN"
    android:value="pk.eyJ1IjoieW91ci11c2VybmFtZSIsImEiOiJjbHh4eHh4eHgifQ.xxxxxxxxxxxxxxxxxxx" />
```

**iOS:**
```plist
ios/Runner/Info.plist
```
Cari key `MBXAccessToken`:
```xml
<key>MBXAccessToken</key>
<string>pk.eyJ1IjoieW91ci11c2VybmFtZSIsImEiOiJjbHh4eHh4eHgifQ.xxxxxxxxxxxxxxxxxxx</string>
```

## Pricing & Limits

### Mapbox Directions API - Free Tier
- **Free tier:** 100,000 requests per month
- Untuk aplikasi Borobudur yang fokus di satu area kecil, ini sangat cukup
- Hanya digunakan saat user memulai navigasi (bukan realtime)

### Estimasi Usage
- Tiap user start navigation = 1 request
- 100,000 requests = support untuk 3,000+ navigasi per hari
- Lebih dari cukup untuk aplikasi wisata

## Testing

Setelah menambahkan token, coba:

1. Jalankan aplikasi: `flutter run`
2. Pilih mode "Custom Location" dari icon di header
3. Tap lokasi awal di peta
4. Tap destination marker (relief/stupa/node)
5. Preview akan muncul dengan route yang mengikuti jalan
6. Check terminal untuk log:
   ```
   Fetching route from Mapbox Directions API...
   Route fetched successfully!
   Using Directions API route with XXX points
   ```

## Troubleshooting

### Route masih garis lurus?
**Kemungkinan penyebab:**
1. Token belum diisi atau salah
   - Check di `lib/config/map_config.dart`
   - Pastikan token dimulai dengan `pk.`
2. No internet connection
   - API butuh internet untuk fetch route
3. Token tidak memiliki scope `navigation:read`
   - Buat token baru dengan scope yang benar

**Fallback behavior:**
Jika API gagal, aplikasi akan otomatis menggunakan garis lurus (straight line) agar navigasi tetap bisa jalan.

### Error 401 Unauthorized
Token tidak valid atau expired. Generate token baru.

### Error 403 Forbidden
Token tidak memiliki permission untuk Directions API. Pastikan scope `navigation:read` aktif.

### Melihat Error Details
Check terminal logs saat preview navigasi dimulai:
```
Directions API error: 401 - {"message":"Not Authorized - Invalid Token"}
```

## Features

### Route Styling dengan Traffic Colors
Code sudah menggunakan styling seperti contoh San Francisco:
- Line width yang adaptif berdasarkan zoom level
- Black border (casing) untuk kontras
- Blue color untuk route
- Smooth rounded caps dan joins
- Traffic-style interpolation (siap untuk data traffic di masa depan)

### Walking Profile
API menggunakan profile `mapbox/walking`:
- Route mengikuti jalur pejalan kaki
- Menghindari jalan yang tidak bisa dilalui pedestrian
- Cocok untuk area wisata Borobudur

## Dokumentasi API
- Mapbox Directions API: https://docs.mapbox.com/api/navigation/directions/
- Walking profile: https://docs.mapbox.com/api/navigation/directions/#walking-profile
- Route styling: https://docs.mapbox.com/mapbox-gl-js/example/route-line-styling/
