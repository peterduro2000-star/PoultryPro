@echo off
echo ============================================
echo  Building PALMSTORE apk (.apk)
echo  PaymentServiceFactory -^> PaystackPaymentService
echo ============================================

call flutter clean
call flutter pub get

call flutter build apk --release --dart-define=PLAY_STORE_BUILD=false

echo.
echo Done.
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo   Billing: Paystack (PaystackPaymentService)
pause
