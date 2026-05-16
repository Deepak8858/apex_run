#!/bin/bash
# ApexRun Mobile Build Script
# Run this on a machine with Flutter SDK installed.

# 1. Configuration
SUPABASE_URL="https://voddddmmiarnbvwmgzgo.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvZGRkZG1taWFybmJ2d21nemdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTE3OTcsImV4cCI6MjA4NjIyNzc5N30.i7Ni-NHsmbwaXEoyOut_26PH1PK_Xycw3ChzkvPtklM"
MAPBOX_TOKEN="pk.eyJ1IjoiZGVlcGFrNzIzOCIsImEiOiJjbWxnZjAwMTMwOWo5M2xzaHF3eTd1eTd6In0.cNbgPuE749GMnCztExzPgg"
ML_SERVICE_URL="http://134.199.187.2:8001" # Update with your public server IP

echo "🚀 Building ApexRun for Android (APK)..."

flutter build apk \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=MAPBOX_ACCESS_TOKEN=$MAPBOX_TOKEN \
  --dart-define=ML_SERVICE_URL=$ML_SERVICE_URL \
  --dart-define=ENABLE_AI_COACHING=true \
  --dart-define=ENABLE_FORM_ANALYSIS=true

echo "✅ Build complete. APK found in build/app/outputs/flutter-apk/app-release.apk"
