#!/usr/bin/env bash
set -euo pipefail

echo "============================================"
echo " Building PALMSTORE apk (.apk)"
echo " PaymentServiceFactory -> PaystackPaymentService"
echo "============================================"

# flutter clean avoids any stale build cache mixing up dart-define
# constants between this build and a previous Play Store build.
flutter clean
flutter pub get

flutter build apk --release \
  --dart-define=PLAY_STORE_BUILD=false

echo ""
echo "✅ Done."
echo "   APK: build/app/outputs/flutter-apk/app-release.apk"
echo "   Billing: Paystack (PaystackPaymentService)"