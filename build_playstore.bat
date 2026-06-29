@echo off
echo ============================================
echo  Building PLAY STORE app bundle (.aab)
echo  PaymentServiceFactory -^> PlayBillingPaymentService
echo ============================================

call flutter clean
call flutter pub get

call flutter build appbundle --release --dart-define=PLAY_STORE_BUILD=true

echo.
echo Done.
echo   AAB: build\app\outputs\bundle\release\app-release.aab
echo   Billing: Google Play Billing (PlayBillingPaymentService)
pause
