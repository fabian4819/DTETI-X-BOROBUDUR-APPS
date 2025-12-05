#!/bin/bash
BAROMETER_BUILD_FILE="$HOME/.pub-cache/hosted/pub.dev/flutter_barometer-0.1.0/android/build.gradle"

if [ -f "$BAROMETER_BUILD_FILE" ]; then
    # Check if namespace already exists
    if grep -q "namespace" "$BAROMETER_BUILD_FILE"; then
        echo "✅ Namespace already exists in flutter_barometer"
    else
        # Add namespace after 'android {' line
        sed -i.backup '/^android {/a\
    namespace "com.hemanthraj.flutterbarometer"
' "$BAROMETER_BUILD_FILE"
        echo "✅ Namespace added to flutter_barometer build.gradle"
    fi
else
    echo "❌ flutter_barometer build.gradle not found at: $BAROMETER_BUILD_FILE"
fi

