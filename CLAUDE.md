# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter mobile application called "Borobudur Explorer" - a tourism and heritage app for exploring the Borobudur World Heritage site. The app provides interactive navigation, cultural encyclopedia (Borobudurpedia), news, events, and user profiles.

## Development Commands

### Essential Commands
```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device-id>

# Build for release (Android)
flutter build apk --release

# Build for release (iOS)  
flutter build ios --release

# Check for issues
flutter doctor

# Clean build artifacts
flutter clean
```

### Code Quality
```bash
# Run linting (uses flutter_lints)
flutter analyze

# Format code
dart format .

# Run tests (if tests exist)
flutter test
```

## Architecture & Code Organization

### Project Structure
```
lib/
├── main.dart                    # App entry point with theme configuration
├── data/                        # Static data and location coordinates
│   └── borobudur_data.dart     # LocationPoint data for temple foundations
├── models/                      # Data models
│   ├── category.dart           # Category model for Borobudurpedia
│   └── location_point.dart     # Location model for navigation
├── screens/                     # All UI screens organized by feature
│   ├── splash_screen.dart      # App startup screen
│   ├── onboarding_screen.dart  # User introduction
│   ├── main_navigation.dart    # Bottom navigation controller
│   ├── auth/                   # Authentication flow
│   ├── home/                   # Dashboard and main features
│   ├── navigation/             # Interactive temple navigation
│   ├── borobudurpedia/        # Cultural encyclopedia
│   ├── news/                   # News and articles
│   ├── agenda/                 # Events calendar
│   └── profile/                # User profile and settings
└── utils/                      # Shared utilities
    └── app_colors.dart         # Centralized color constants
```

### Key Architecture Patterns

**State Management**: Currently uses StatefulWidget with setState. Architecture supports future migration to Provider/Bloc/Riverpod.

**Navigation**: Single MaterialApp with bottom tab navigation via MainNavigation widget. Each tab loads a different screen.

**Theme System**: Centralized theme configuration in main.dart using AppColors constants. Custom Poppins font family throughout.

**Data Models**: Simple data classes with named constructors. LocationPoint model contains geographic coordinates for temple foundations and pathways.

## Important Implementation Details

### Color System
All colors are defined in `lib/utils/app_colors.dart`:
- Primary: `#2563EB` (blue)
- Secondary: `#64748B` (gray) 
- Accent: `#EAB308` (gold)
- Includes gradient definitions for cultural theming

### Location Data & Navigation
The app contains detailed coordinate data for Borobudur temple in `lib/data/borobudur_data.dart`:
- Foundation points (F1-F36) with exact GPS coordinates
- Pathway markers (JALAN_1-4) for navigation
- Each LocationPoint has id, name, coordinates, type, and description

**Navigation Service** (`lib/services/navigation_service.dart`):
- Real-time GPS tracking using `geolocator` package
- Dijkstra pathfinding algorithm for optimal routes
- Turn-by-turn navigation with direction instructions
- Distance and time estimation (walking speed: 1.4 m/s)
- Stream-based position and navigation updates

### Screen Architecture
- MainNavigation handles bottom tab switching
- Each major feature has its own screen directory
- Screens use consistent theming from main.dart
- Indonesian language labels in navigation ("Navigasi", "Berita", "Agenda", "Profil")

### Assets Organization
```
assets/
├── images/          # App images and temple photography
└── icons/           # Custom icons and graphics

fonts/              # Poppins font family (Regular, Medium, SemiBold, Bold)
```

## Development Guidelines

### Dependencies
The project uses the following key dependencies:
- `cupertino_icons` - iOS-style icons
- `font_awesome_flutter` - Icon library
- `collection` - Dart utilities for data structures
- `flutter_lints` - Dart linting rules
- `geolocator` - GPS location services for real-time navigation
- `permission_handler` - Managing location permissions

### Coding Conventions
- Use named constructors for models
- Organize screens by feature in subdirectories  
- Centralize colors in AppColors class
- Use const constructors where possible
- Follow Flutter/Dart naming conventions (PascalCase for classes, camelCase for variables)

### Adding New Features
1. Create models in `lib/models/` if new data structures needed
2. Add screens in appropriate `lib/screens/` subdirectory
3. Update MainNavigation if adding new top-level tab
4. Use existing AppColors for consistent theming
5. Follow existing StatefulWidget patterns for state management

### Navigation System Usage
The navigation screen provides Google Maps-like functionality:
- **Location Selection**: Tap map points or use search to select start/end points
- **Real-time Tracking**: Requires location permissions for GPS tracking
- **Turn-by-turn Guidance**: Voice-like instructions (belok kiri/kanan, lurus)
- **Distance & Time**: Real-time updates during navigation
- **Route Visualization**: Blue path lines showing optimal route

**Key Components**:
- `NavigationService`: Singleton service handling GPS and pathfinding
- `BorobudurMapPainter`: Custom painter for map visualization
- Location permission handling with user-friendly dialogs