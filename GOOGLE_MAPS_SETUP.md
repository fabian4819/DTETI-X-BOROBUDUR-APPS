# Google Maps Setup Guide

This guide will help you configure Google Maps API for the enhanced navigation features.

## Prerequisites

1. **Google Cloud Console Account**: Create an account at https://console.cloud.google.com
2. **Enable Billing**: Google Maps API requires billing to be enabled

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Click "New Project"
3. Name your project (e.g., "Borobudur Explorer")
4. Click "Create"

## Step 2: Enable Required APIs

Navigate to "APIs & Services" > "Library" and enable:

- **Maps SDK for Android**
- **Maps SDK for iOS** (if building for iOS)
- **Geocoding API** (optional, for address lookup)
- **Places API** (optional, for location search)
- **Directions API** (optional, for advanced routing)

## Step 3: Create API Key

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "API Key"
3. Copy the generated API key
4. Click "Restrict Key" to configure restrictions

## Step 4: Configure API Key Restrictions

**For Security, configure these restrictions:**

### Application Restrictions
- **Android apps**: Add your app's package name and SHA-1 certificate fingerprint
- **iOS apps**: Add your app's bundle identifier

### API Restrictions
Select "Restrict key" and choose the APIs you enabled above.

## Step 5: Configure Flutter App

### Android Configuration

1. Open `android/app/src/main/AndroidManifest.xml`
2. Add this inside the `<application>` tag:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

### iOS Configuration

1. Open `ios/Runner/AppDelegate.swift`
2. Add this import at the top:

```swift
import GoogleMaps
```

3. Add this inside the `application` method:

```swift
GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
```

### Environment Variables (Recommended)

Instead of hardcoding API keys, use environment variables:

1. Create a `.env` file in the project root:

```bash
GOOGLE_MAPS_API_KEY=your_api_key_here
```

2. Add `.env` to your `.gitignore` file
3. Use a package like `flutter_dotenv` to load the key

## Step 6: Test the Integration

1. Run `flutter pub get` to install dependencies
2. Run the app: `flutter run`
3. Navigate to the Enhanced Navigation screen
4. Verify that:
   - Map loads properly
   - Custom markers appear
   - Satellite/terrain switching works
   - Navigation features function

## Troubleshooting

### Common Issues

1. **Map not loading**
   - Check API key is correct
   - Verify billing is enabled
   - Check API restrictions

2. **Markers not appearing**
   - Ensure custom marker service is working
   - Check location data format

3. **Voice not working**
   - Check TTS permissions
   - Verify language support

### API Quotas

Monitor your API usage in Google Cloud Console:
- Maps SDK: 28,000 loads per month (free tier)
- Geocoding: 40,000 requests per month (free tier)

### Cost Optimization

1. **Enable API restrictions** to prevent unauthorized usage
2. **Set billing alerts** to monitor costs
3. **Implement caching** for frequently accessed data
4. **Use local data** when possible (like your existing Borobudur coordinates)

## Security Best Practices

1. **Never commit API keys** to version control
2. **Use application restrictions** to limit key usage
3. **Rotate keys regularly**
4. **Monitor usage** for unusual activity
5. **Use separate keys** for development and production

## Testing

Test your implementation with these scenarios:

1. **Different map types**: Satellite, terrain, normal, hybrid
2. **Voice guidance**: Enable/disable functionality
3. **Custom markers**: Selection states, different location types
4. **Navigation**: Start/stop, route visualization
5. **Real-time updates**: Position tracking, instruction updates

## Additional Resources

- [Google Maps Platform Documentation](https://developers.google.com/maps/documentation)
- [Flutter Google Maps Plugin](https://pub.dev/packages/google_maps_flutter)
- [Flutter TTS Documentation](https://pub.dev/packages/flutter_tts)
- [Geolocator Plugin](https://pub.dev/packages/geolocator)

---

**Note**: The enhanced navigation system gracefully falls back to the original 3D visualization if Google Maps is not configured, ensuring your app remains functional during setup.