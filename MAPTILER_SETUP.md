# MapTiler Setup Guide

This app uses MapTiler for high-quality map tiles. Follow these steps to configure it:

## 1. Get a Free MapTiler API Key

1. Visit [MapTiler](https://maptiler.com/)
2. Click "Sign Up" to create a free account
3. Go to your [Account Dashboard](https://cloud.maptiler.com/account/)
4. Copy your API key from the "Keys" section

**Free Tier Includes:**
- 100,000 map loads per month
- High-quality map styles
- Satellite imagery
- No credit card required

## 2. Configure the API Key

1. Open `lib/config/map_config.dart`
2. Replace `'your_maptiler_api_key_here'` with your actual API key:

```dart
static const String mapTilerApiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

## 3. Available Map Styles

Once configured, you'll have access to:

- **MapTiler Streets** - Clean street map with high detail
- **MapTiler Satellite** - Hybrid satellite imagery with labels
- **MapTiler Outdoor** - Topographic style for outdoor activities
- **MapTiler Topo** - Detailed topographic maps

## 4. Fallback Behavior

If no API key is configured, the app will automatically fall back to OpenStreetMap tiles.

## 5. Usage Monitoring

Monitor your usage at [MapTiler Cloud Dashboard](https://cloud.maptiler.com/) to ensure you stay within the free tier limits.

## Security Note

Never commit your actual API key to version control. Consider using environment variables or Flutter's `--dart-define` for production builds.