# Borobudur Explorer App

A beautiful Flutter application for exploring the Borobudur World Heritage site with navigation, encyclopedia, and cultural information.

## Features

### 🏛️ Core Features
- **Interactive Navigation**: Explore Borobudur temple complex with detailed maps
- **Borobudurpedia**: Comprehensive encyclopedia with 12+ categories
- **Cultural Information**: News, events, and cultural heritage content
- **User Profiles**: Personal journey tracking and favorites
- **Multi-language Support**: Indonesian interface with expansion capability

### 📱 Screens Included
1. **Splash Screen** - Animated welcome with brand identity
2. **Onboarding** - Beautiful introduction with temple imagery
3. **Authentication** - Login/Register with social media options
4. **Home Dashboard** - Quick access to all features
5. **Interactive Navigation** - Map-based temple exploration
6. **Borobudurpedia** - Educational encyclopedia
7. **News & Articles** - Latest updates and discoveries
8. **Events Calendar** - Cultural events and festivals
9. **User Profile** - Personal dashboard and settings

### 🎨 Design Highlights
- **Modern UI/UX**: Clean, intuitive interface with smooth animations
- **Cultural Theme**: Colors and imagery reflecting Borobudur's heritage
- **Responsive Design**: Optimized for various screen sizes
- **Accessibility**: Proper contrast and semantic structure
- **Performance**: Optimized image loading and smooth transitions

### 🛠️ Technical Stack
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **State Management**: StatefulWidget (expandable to Provider/Bloc)
- **Architecture**: Clean separation of concerns
- **Design System**: Custom color palette and typography

## Getting Started

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / VS Code
- Android/iOS device or simulator

### Installation
1. Clone the repository
```bash
git clone [repository-url]
cd borobudur_app
```

2. Install dependencies
```bash
flutter pub get
```

3. Add required assets
```
assets/
  images/
    splash-screen.png
  icons/
fonts/
  Poppins-Regular.ttf
  Poppins-Medium.ttf
  Poppins-SemiBold.ttf
  Poppins-Bold.ttf
```

4. Run the application
```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   └── category.dart
├── screens/                  # All app screens
│   ├── splash_screen.dart
│   ├── onboarding_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── main_navigation.dart
│   ├── home/
│   │   └── home_screen.dart
│   ├── navigation/
│   │   └── navigation_screen.dart
│   ├── borobudurpedia/
│   │   ├── borobudurpedia_main_screen.dart
│   │   └── borobudurpedia_categories_screen.dart
│   ├── news/
│   │   └── news_screen.dart
│   ├── agenda/
│   │   └── agenda_screen.dart
│   └── profile/
│       └── profile_screen.dart
└── utils/
    └── app_colors.dart       # Color constants
```

## Features Detail

### 🏠 Home Screen
- Personalized greeting for logged-in users
- Quick access grid with 8 main features
- Popular destinations carousel
- Latest events showcase
- Beautiful gradient design with temple imagery

### 🗺️ Navigation Screen
- Interactive map interface
- Search functionality with voice input
- Quick location buttons (Area Stupa, Gates)
- Location markers with contextual information
- Category filters (Temple, Museum, Garden, etc.)

### 📚 Borobudurpedia
- Main encyclopedia hub with search
- 12 categories with item counts:
  - Tools (156 items)
  - Temple Architecture (80 items)
  - Materials (80 items)
  - Buddha (51 items)
  - Fauna (7 items)
  - Flora (39 items)
  - Area (72 items)
  - Conservation (113 items)
  - Regulations (28 items)
  - Stakeholders (6 items)
  - Figures (26 items)
  - Others (60 items)

### 📰 News & Events
- Featured articles with rich media
- Event calendar integration
- Cultural festival information
- Archaeological discoveries
- Tourism updates

### 👤 User Profile
- Personal statistics tracking
- Visit history and favorites
- Review and rating system
- Settings and preferences
- Multi-language support

## Customization

### Colors
The app uses a carefully crafted color palette in `utils/app_colors.dart`:
- Primary Blue: `#2563EB`
- Secondary Gray: `#64748B`
- Accent Gold: `#EAB308`
- Cultural gradients for temple imagery

### Typography
Poppins font family for modern, readable text:
- Regular (400)
- Medium (500)
- SemiBold (600)
- Bold (700)

### Images
Replace placeholder images in `assets/images/`:
- `splash-screen.png` - App logo/icon
- Add temple photography
- Cultural artifacts images
- User interface icons

## Future Enhancements

### Phase 1 (Current)
- ✅ Core UI/UX implementation
- ✅ Navigation structure
- ✅ Authentication flow
- ✅ Basic information architecture

### Phase 2 (Planned)
- 🔄 Real map integration (Google Maps/Mapbox)
- 🔄 Database integration (Firebase/Supabase)
- 🔄 Offline content caching
- 🔄 Push notifications

### Phase 3 (Future)
- 📍 GPS-based temple navigation
- 🔊 Audio guide integration
- 📱 AR (Augmented Reality) features
- 🌐 Multi-language content
- 📊 Advanced analytics
- 🎫 Ticket booking integration

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Indonesian Ministry of Education, Culture, Research, and Technology
- Borobudur World Heritage Management
- Flutter community for excellent documentation
- Design inspiration from modern tourism applications