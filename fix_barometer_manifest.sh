#!/bin/bash
BAROMETER_MANIFEST="$HOME/.pub-cache/hosted/pub.dev/flutter_barometer-0.1.0/android/src/main/AndroidManifest.xml"

if [ -f "$BAROMETER_MANIFEST" ]; then
    # Remove package attribute from manifest tag
    sed -i.backup 's/<manifest xmlns:android="http:\/\/schemas.android.com\/apk\/res\/android" package="[^"]*">/<manifest xmlns:android="http:\/\/schemas.android.com\/apk\/res\/android">/' "$BAROMETER_MANIFEST"
    echo "✅ Removed package attribute from flutter_barometer AndroidManifest.xml"
else
    echo "❌ flutter_barometer AndroidManifest.xml not found"
fi
