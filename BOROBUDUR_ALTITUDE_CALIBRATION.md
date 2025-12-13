# Kalibrasi Ketinggian Candi Borobudur

## 📏 Implementasi Auto-Calibration untuk Candi Borobudur

### Ringkasan
Sistem barometer telah dikonfigurasi dengan **auto-calibration khusus Candi Borobudur** untuk memberikan pengalaman optimal bagi pengunjung turis.

---

## 🏛️ Spesifikasi Teknis

### Base Altitude Borobudur
- **Elevasi dari permukaan laut (mdpl)**: 265 meter
- **Ground Level (Lantai Dasar)**: 0 meter (relatif)
- **Tinggi total candi**: ~35-40 meter dari lantai dasar hingga puncak stupa

### Konfigurasi Level (10 Lantai)

| Lantai | Nama | Range Altitude | Deskripsi |
|--------|------|----------------|-----------|
| 1 | Alas Candi | -2m to 4m | Dasar dan jalan masuk utama |
| 2 | Kamadhatu Bawah | 4m to 8m | Tingkat Kamadhatu (alam keinginan) |
| 3 | Kamadhatu Atas | 8m to 12m | Relief Lalitavistara & Jataka |
| 4 | Rupadhatu Bawah | 12m to 16m | Tingkat Rupadhatu (alam bentuk) |
| 5 | Rupadhatu Tengah | 16m to 20m | Relief Gandavyuha, candi-candi Buddha |
| 6 | Rupadhatu Atas | 20m to 24m | Lanjutan Gandavyuha, stupa-stupa kecil |
| 7 | Arupadhatu Pertama | 24m to 28m | Tingkat Arupadhatu (alam tanpa bentuk) |
| 8 | Arupadhatu Kedua | 28m to 32m | Stupa berlubang, menuju puncak |
| 9 | Arupadhatu Ketiga | 32m to 36m | Teras puncak, stupa utama |
| 10 | Puncak Stupa | 36m to 50m | Puncak tertinggi - Stupa Utama |

---

## 🔧 Cara Kerja

### 1. Auto-Calibration (Default)
Saat aplikasi pertama kali dijalankan di lokasi Candi Borobudur:

```dart
// Otomatis set base altitude = 265m mdpl
await barometerService.calibrateForBorobudur();
```

**Hasil:**
- Base altitude: 265m mdpl
- Relative altitude: 0m = lantai dasar candi
- User tidak perlu kalibrasi manual

### 2. Deteksi Level Otomatis
Sistem secara real-time mendeteksi lantai berdasarkan ketinggian relatif:

```dart
// Contoh: User di lantai 5 (16-20m)
double currentAltitude = 18.5; // meter dari lantai dasar
int detectedLevel = 5; // Lantai 5 - Rupadhatu Tengah
```

### 3. Metode Kalibrasi

#### A. Auto Borobudur (Recommended)
- **Kapan**: Untuk pengunjung turis di Candi Borobudur
- **Base Altitude**: 265m mdpl (fixed)
- **Display**: Ketinggian relatif dari lantai dasar (0m, 5m, 10m, dst)

#### B. Kalibrasi Manual
- **Kapan**: Untuk testing atau lokasi lain
- **Base Altitude**: Posisi saat ini = 0m
- **Display**: Ketinggian relatif dari titik kalibrasi

---

## 📱 User Interface

### Level Configuration Screen
```
┌─────────────────────────────────────┐
│ 🔧 Level Configuration              │
├─────────────────────────────────────┤
│ Status:                             │
│ ✅ Tracking Active                  │
│ 🏛️ Kalibrasi Borobudur (265m mdpl) │
│                                     │
│ Current Altitude: 18.5m             │
│ Detected Level: Lantai 5            │
├─────────────────────────────────────┤
│ [🔄 Calibrate]  [♻️ Reset Default] │
└─────────────────────────────────────┘
```

### Calibration Dialog
```
Pilih metode kalibrasi:

🏛️ Auto Borobudur
   Set base altitude 265m mdpl (lantai dasar candi)

📍 Lokasi Saat Ini
   Set posisi sekarang sebagai 0m referensi
```

---

## 🎯 Use Cases

### Skenario 1: Turis Masuk Candi (Lantai Dasar)
```
Pressure: 975 hPa
Absolute Altitude: 265m mdpl
Relative Altitude: 0m ← Ditampilkan ke user
Detected Level: Lantai 1 (Alas Candi)
```

### Skenario 2: Turis di Lantai Tengah
```
Pressure: 973 hPa
Absolute Altitude: 283m mdpl
Relative Altitude: 18m ← Ditampilkan ke user
Detected Level: Lantai 5 (Rupadhatu Tengah)
```

### Skenario 3: Turis di Puncak Stupa
```
Pressure: 971 hPa
Absolute Altitude: 300m mdpl
Relative Altitude: 35m ← Ditampilkan ke user
Detected Level: Lantai 10 (Puncak Stupa)
```

---

## 🔬 Akurasi Sensor

### Android (Barometer)
- **Akurasi**: ±1-2 meter
- **Update Rate**: Real-time (continuous)
- **Best for**: Deteksi lantai dengan presisi tinggi

### iOS (CMAltimeter)
- **Akurasi**: ±1-3 meter
- **Update Rate**: Real-time (continuous)
- **Best for**: Tracking pergerakan vertikal

### iOS (GPS Fallback)
- **Akurasi**: ±5-10 meter
- **Update Rate**: Per second
- **Best for**: Fallback jika CMAltimeter tidak tersedia

---

## 💡 Best Practices untuk Pengunjung

### ✅ DO:
1. **Biarkan auto-calibration berjalan** saat pertama kali masuk area candi
2. **Tunggu 2-3 detik** setelah app dibuka untuk stabilisasi sensor
3. **Gunakan mode "Auto Borobudur"** untuk pengalaman optimal
4. **Perhatikan indikator level** yang berubah saat naik/turun tangga

### ❌ DON'T:
1. Jangan kalibrasi ulang kecuali ada masalah teknis
2. Jangan menggunakan mode manual calibration untuk turis umum
3. Jangan reset konfigurasi level tanpa alasan

---

## 🧪 Testing Guide

### Test Case 1: Ground Level Detection
```bash
# Expected: Lantai 1, altitude ~0-4m
# Actual reading should show relative altitude close to 0m
```

### Test Case 2: Level Transition
```bash
# Start at Lantai 1 → Walk up stairs → Should detect Lantai 2
# Transition should trigger within 2-3 seconds of crossing threshold
```

### Test Case 3: Calibration Persistence
```bash
# Close app → Reopen → Calibration should persist
# Base altitude should remain at 265m mdpl
```

---

## 📊 Data Flow

```
┌──────────────────┐
│  Barometer/GPS   │
│     Sensor       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Raw Altitude     │
│ (e.g. 283m mdpl) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Calibration     │
│  (Base: 265m)    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Relative Alt.    │
│  (283-265=18m)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Level Detection  │
│  (Lantai 5)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│   Display to     │
│      User        │
└──────────────────┘
```

---

## 🔐 Persistence

### Saved Data (SharedPreferences)
```dart
'barometer_base_pressure': 975.2,  // hPa
'barometer_base_altitude': 265.0,  // meters mdpl
'barometer_calibrated': true,
'temple_level_configs': [...],     // 10 level configs
```

---

## 🚀 Future Enhancements

1. **GPS Location Detection**: Auto-detect jika user berada di area Borobudur
2. **Multi-Temple Support**: Tambah konfigurasi untuk candi lain (Prambanan, dll)
3. **Weather Compensation**: Adjust untuk perubahan tekanan atmosfer
4. **Historical Data**: Track riwayat perjalanan user di candi
5. **AR Integration**: Overlay informasi level di camera view

---

## 📞 Troubleshooting

### Problem: Altitude tidak akurat
**Solution**: 
1. Buka Level Configuration screen
2. Tap tombol refresh (🔄)
3. Pilih "Auto Borobudur"

### Problem: Level detection lambat
**Solution**:
1. Check barometer sensor availability
2. Kurangi hysteresis buffer (default 2m)
3. Restart tracking

### Problem: Kalibrasi hilang setelah restart
**Solution**:
1. Check SharedPreferences permission
2. Re-calibrate manual jika perlu
3. Pastikan app tidak di-clear cache

---

## 👨‍💻 Developer Notes

### File Changes
- `lib/services/barometer_service.dart`
  - Added `BOROBUDUR_BASE_ELEVATION` constant
  - Added `calibrateForBorobudur()` method
  - Added `getTempleLevelDescription()` helper
  - Added `getEstimatedLevel()` helper

- `lib/services/level_detection_service.dart`
  - Updated `_getDefaultBorobudurConfig()` with accurate altitude ranges
  - Changed from 9 levels to 10 levels
  - Adjusted altitude ranges (0-40m instead of 0-100m)

- `lib/screens/navigation/level_config_screen.dart`
  - Enhanced `_calibrateHere()` with dialog options
  - Added Borobudur calibration status indicator
  - Improved UI with calibration type display

### Constants
```dart
static const double BOROBUDUR_BASE_ELEVATION = 265.0; // mdpl
static const double BOROBUDUR_GROUND_LEVEL = 0.0;     // reference
static const bool AUTO_CALIBRATE_BOROBUDUR = true;    // enabled
```

---

## ✅ Implementation Checklist

- [x] Add Borobudur base elevation constant
- [x] Implement `calibrateForBorobudur()` method
- [x] Update level configurations (10 levels, 0-40m range)
- [x] Add calibration status indicator in UI
- [x] Add calibration method selection dialog
- [x] Test auto-calibration on app start
- [x] Add helper methods for level description
- [x] Document implementation
- [ ] Test with real device at Borobudur
- [ ] Collect user feedback
- [ ] Fine-tune altitude ranges based on actual measurements

---

**Last Updated**: December 13, 2025  
**Version**: 1.0  
**Status**: ✅ Implemented and Ready for Testing
