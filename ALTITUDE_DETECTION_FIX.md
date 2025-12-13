# Perbaikan Altitude Detection - 44330.8m Bug

## Masalah
Aplikasi menunjukkan altitude **44330.8m** dan Level 1, padahal pengguna berada di lokasi yang jauh lebih rendah.

## Penyebab
1. **Formula Barometrik Salah**: Eksponen yang digunakan dalam perhitungan altitude menghasilkan nilai yang sangat tinggi ketika:
   - Pressure sensor memberikan nilai 0 atau sangat rendah
   - Barometer belum dikalibrasi dengan benar
   - Menggunakan formula: `h = T0 * (1 - (P/P0)^exp) / L`
   - Ketika P ≈ 0, maka (P/P0) ≈ 0, sehingga (1 - 0) = 1
   - Hasil: `h = 288.15 * 1 / 0.0065 ≈ 44330.8m`

2. **Tidak Ada Validasi**: Tidak ada validasi untuk pressure reading yang tidak valid

3. **Tidak Ada Auto-Calibration**: Jika barometer belum dikalibrasi, sistem tetap menggunakan sea level pressure (1013.25 hPa) sebagai base pressure

## Solusi Implementasi

### 1. Formula Barometrik yang Benar
```dart
// Sebelum (SALAH):
final exponent = (_gasConstant * _temperatureKelvin) / (_molarMass * _gravity);
final ratio = pow(pressure / _seaLevelPressure, exponent);
return _temperatureKelvin * (1.0 - ratio) / _pressureLapseRate;
// Hasil: exp ≈ 8.43, menghasilkan nilai yang salah

// Sesudah (BENAR):
final exponent = 1.0 / 5.255; // Standard atmospheric formula
final ratio = pow(pressure / _seaLevelPressure, exponent);
final altitude = 44330.0 * (1.0 - ratio);
// Hasil: Altitude yang akurat
```

### 2. Validasi Pressure Reading
```dart
// Validate pressure reading
if (pressure <= 0 || pressure > 1100) {
  print('⚠️ Invalid pressure reading: $pressure hPa');
  return 0.0; // atau skip reading
}
```

### 3. Auto-Calibration
```dart
// Auto-calibrate setelah 2 detik jika belum dikalibrasi
if (!_isCalibrated) {
  Future.delayed(const Duration(seconds: 2), () async {
    if (!_isCalibrated && _pressureReadings.isNotEmpty) {
      await calibrateHere();
    }
  });
}
```

## Hasil Perbaikan

### Sebelum
- ❌ Altitude: 44330.8m (SALAH)
- ❌ Level: 1 (tidak akurat)
- ❌ Pressure: 0 hPa atau tidak valid

### Sesudah
- ✅ Altitude: Nilai yang akurat sesuai lokasi (0-35m untuk Borobudur)
- ✅ Level: Deteksi level yang benar (1-6)
- ✅ Pressure: Tervalidasi dan ter-smooth (contoh: 994.56 hPa)
- ✅ Auto-calibration: Otomatis kalibrasi di lokasi awal

## Penjelasan Altitude Detection

### Apa itu Altitude yang Ditampilkan?

**Altitude adalah RELATIVE ALTITUDE (Ketinggian Relatif)**, yaitu:
- ✅ Ketinggian relatif dari titik kalibrasi awal
- ✅ Perubahan ketinggian sejak aplikasi pertama kali dijalankan
- ❌ BUKAN ketinggian MDPL (meter di atas permukaan laut)
- ❌ BUKAN ketinggian absolut

### Contoh Real:
```
📏 Altitude Update: 0.35m | Pressure: 994.56 hPa
```

Artinya:
- **0.35m**: Anda berada 0.35m LEBIH TINGGI dari titik kalibrasi awal
- **994.56 hPa**: Tekanan udara saat ini (menunjukkan Anda berada di ~260-300m MDPL)

### Cara Kerja Auto-Calibration:

1. **Saat aplikasi pertama kali dijalankan** (setelah 2 detik):
   ```
   📍 Lokasi: Lantai 1 Borobudur
   🔧 Auto-calibrating barometer...
   📊 Base Pressure: 994.56 hPa (pressure saat ini)
   📏 Base Altitude: 0.0m (set sebagai referensi)
   ```

2. **Saat Anda naik ke Lantai 2** (naik ~20m):
   ```
   📏 Altitude Update: 20.5m | Pressure: 992.10 hPa
   🏛️ Level changed: 1 → 2
   ```

3. **Saat Anda turun kembali ke Lantai 1**:
   ```
   📏 Altitude Update: 0.2m | Pressure: 994.54 hPa
   🏛️ Level changed: 2 → 1
   ```

### Kenapa Menggunakan Relative Altitude?

1. **Akurasi Tinggi**: ±1-2m untuk perubahan ketinggian relatif
2. **Tidak Bergantung pada Absolute Altitude**: Tidak perlu tahu ketinggian MDPL yang exact
3. **Cocok untuk Indoor Navigation**: Mendeteksi perubahan lantai di dalam gedung
4. **Auto-Calibration**: Otomatis kalibrasi di lokasi mana pun Anda berada

### Pressure vs Altitude:

| Pressure (hPa) | Approximate MDPL |
|----------------|------------------|
| 1013.25        | 0m (sea level)   |
| 1000.00        | ~110m            |
| 994.56         | ~260-300m        |
| 950.00         | ~540m            |
| 900.00         | ~1000m           |

**Catatan**: Borobudur berada di ~260-300m MDPL, jadi pressure normal di sana adalah ~990-995 hPa

## Cara Testing

1. **Build dan Jalankan Aplikasi**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Cek Log Console**
   - Harus muncul: `✅ Altitude tracking started (Barometer, ±1-2m accuracy)`
   - Harus muncul: `🔧 Auto-calibrating barometer at current location...`
   - Tidak boleh muncul: `⚠️ Invalid pressure reading`

3. **Monitoring Altitude**
   - Altitude seharusnya menunjukkan nilai realistis (contoh: 5-15m)
   - Level seharusnya berubah sesuai altitude (Level 1: 0-15m)
   - Tidak boleh ada nilai 44330.8m

## Konfigurasi Level Borobudur

```dart
Level 1: 0-15m    - Lantai 1 - Alas Candi
Level 2: 15-25m   - Lantai 2 - Kamadhatu
Level 3: 25-35m   - Lantai 3 - Kamadhatu
Level 4: 35-45m   - Lantai 4 - Rupadhatu
Level 5: 45-55m   - Lantai 5 - Rupadhatu
Level 6: 55-65m   - Lantai 6 - Arupadhatu
```

## Akurasi Sensor

- **Android Barometer**: ±1-2m (paling akurat)
- **iOS CMAltimeter**: ±1-3m (akurat)
- **iOS GPS Fallback**: ±5-10m (kurang akurat)

## Troubleshooting

### Masih Menunjukkan 44330.8m?
1. Periksa apakah device memiliki barometer sensor
2. Restart aplikasi
3. Reset calibration: Settings > Reset Calibration
4. Cek permission lokasi (untuk iOS GPS fallback)

### Level Tidak Berubah?
1. Pastikan auto-calibration sudah berjalan
2. Coba manual calibration di Settings
3. Periksa hysteresis buffer (default: 2m)

### Pressure Menunjukkan 0 hPa?
1. Device mungkin tidak memiliki barometer
2. Permission sensor denied
3. Restart aplikasi dan cek log

## File yang Dimodifikasi
- `lib/services/barometer_service.dart`
  - `_calculateAbsoluteAltitude()`: Formula diperbaiki
  - `_calculateRelativeAltitude()`: Formula diperbaiki + validasi
  - `_handleBarometerEvent()`: Tambah validasi pressure
  - `startTracking()`: Tambah auto-calibration

## Referensi Formula
- Standard Atmosphere Formula: https://en.wikipedia.org/wiki/Atmospheric_pressure
- Barometric Formula: `h = 44330 * (1 - (P/P0)^(1/5.255))`
- Dimana: P0 = 1013.25 hPa (sea level pressure)
