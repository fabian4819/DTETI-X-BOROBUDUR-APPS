# Development Notes - DTETI x Borobudur Apps

## ⚠️ Important: Hot Restart Issue with MapView

### Problem
The app uses Mapbox Maps Flutter SDK which has a known issue with iOS Platform Views and Hot Restart.

**Error Message:**
```
PlatformException(recreating_view, trying to create an already created view, view id: '0', null)
```

### Solution

#### ✅ DO:
- Use **Hot Reload** (`r` in terminal or VS Code) for UI changes
- Use **Full Restart** (Stop → `flutter run` again) for major changes
- Use `q` to quit, then `flutter run` to restart

#### ❌ DON'T:
- **NEVER use Hot Restart** (`R` in terminal)
- Avoid VS Code "Restart" button (use Stop → Run instead)

### Why This Happens
- iOS MapView doesn't support recreation during hot restart
- GlobalKey prevents this in normal operation
- Hot restart forces MapWidget recreation, causing the error

### For New Developers
If you see the `recreating_view` error:
1. Press `q` in the terminal to quit
2. Run `flutter run` again
3. The error will NOT appear on fresh launch

---

## Development Workflow

### Making UI Changes
```bash
# 1. Make your code changes
# 2. Use hot reload
r

# If hot reload doesn't work, full restart:
q
flutter run
```

### Debugging MapView Issues
- Always do full restart after changing map configuration
- Use `flutter clean` if map doesn't render properly
- Check iOS Simulator console for native errors

---

## Project Structure

### Navigation System
- **Borobudur Backend API**: On-temple navigation (nodes inside temple)
- **Mapbox Directions API**: Off-temple navigation (routes outside)
- **Fallback**: Dashed straight line when no route found

### Map Features
- **Node Markers**: Green circles (TANGGA, STUPA only)
- **Feature Markers**: Blue (stupa), Orange (relief, etc)
- **External Facilities**: Deep orange (toilet, museum, parking, etc)

### Map Center Modes
- 🏯 **Borobudur Mode** (default): Map centered on temple
- 📍 **Current Location Mode**: Map follows user's GPS

---

## Common Issues & Solutions

### 1. White Screen on Map
**Cause**: MapWidget not initialized properly
**Solution**: Check GlobalKey is applied to MapWidget

### 2. Markers Not Visible
**Cause**: Filter or building opacity
**Solution**: Check `_addNodeMarkers()` filter logic

### 3. Route Not Found
**Cause**: No road connection between points
**Solution**: App shows dashed red line as fallback

### 4. Location Permission Denied
**Cause**: iOS/Android permissions not granted
**Solution**: Check `Info.plist` and `AndroidManifest.xml`

---

## Testing Checklist

- [ ] Test with real device (GPS accuracy)
- [ ] Test with simulator (custom location)
- [ ] Test all facility types (27 facilities)
- [ ] Test route finding (success & failure cases)
- [ ] Test map mode switching (Borobudur ↔ Current Location)
- [ ] Test marker tap detection (nodes, features, facilities)
- [ ] Test 3D building visibility
- [ ] Test level detection (if barometer available)

---

## Performance Tips

- Minimize hot restarts (use hot reload)
- Clear old route layers before adding new ones
- Use appropriate marker clustering for large datasets
- Optimize GeoJSON size for better performance

---

## Contact & Resources

- Mapbox Documentation: https://docs.mapbox.com/
- Flutter Mapbox Plugin: https://pub.dev/packages/mapbox_maps_flutter
- Borobudur Backend API: https://borobudurbackend.context.my.id/

---

**Last Updated**: December 5, 2025
