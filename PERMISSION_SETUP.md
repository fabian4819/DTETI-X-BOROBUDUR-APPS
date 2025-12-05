# Permission Setup untuk iPhone

## Masalah yang Muncul
```
flutter: Current geolocator permission status: LocationPermission.denied
```

## Solusi: Enable Location Permission di iPhone

### Cara 1: Melalui Settings iPhone

1. **Buka Settings** di iPhone
2. **Scroll ke bawah** dan cari app **"DTETI X BOROBUDUR"** (atau nama app Anda)
3. **Tap app name**
4. **Tap "Location"**
5. **Pilih "While Using the App"** atau **"Always"**
6. **Enable "Precise Location"** (toggle switch ke hijau)
7. **Restart app**

### Cara 2: Saat App Pertama Kali Dibuka

Saat pertama kali membuka app, akan muncul popup:
```
"DTETI X BOROBUDUR" would like to use your location
[ Don't Allow ]  [ Allow While Using App ]  [ Allow Once ]
```

**Pilih**: **"Allow While Using App"**

### Cara 3: Reset Permission (Jika Sudah Deny)

1. **Buka Settings** → **Privacy & Security**
2. **Tap "Location Services"**
3. **Scroll dan cari app Anda**
4. **Tap app name**
5. **Pilih "While Using the App"**
6. **Enable "Precise Location"**
7. **Hapus app dari iPhone**
8. **Install ulang** dari Xcode
9. **Buka app** → popup permission muncul lagi

### Verify Permission Berhasil

Setelah enable permission, log seharusnya berubah menjadi:
```
flutter: Current geolocator permission status: LocationPermission.whileInUse
✅ Permission berhasil!
```

## Barometer Error (FIXED)

Error berikut sudah diperbaiki di code:
```
flutter: Error handling barometer event: Bad state: Cannot add new events after calling close
```

**Fix**: Menambahkan check `isClosed` sebelum add event ke stream controller.

## Testing di Physical Device

1. **Connect iPhone** ke Mac
2. **Trust computer** di iPhone (popup pertama kali connect)
3. **Run command**:
   ```bash
   flutter run -d <device-id>
   ```
4. **Check log** untuk confirm permission:
   ```
   flutter: Current geolocator permission status: LocationPermission.whileInUse
   ```

## Troubleshooting

### Permission masih denied setelah allow?
- **Force quit app** (swipe up dari app switcher)
- **Relaunch app**

### App tidak muncul di Location Services?
- Install ulang app
- Pastikan `Info.plist` punya key yang benar:
  - `NSLocationWhenInUseUsageDescription`
  - `NSLocationAlwaysUsageDescription`

### Barometer tidak terdeteksi?
- iPhone 6 dan lebih baru punya barometer
- iPhone 5s dan lebih lama tidak punya barometer
- Check dengan log:
  ```
  flutter: Barometer not available
  ```
