# poost Media Buying OS V4 — Complete Android UI/Business Prototype

هذه النسخة تكمل طبقة التطبيق قبل أي ربط خارجي.

## موجود
- Login UI
- poost brand / dark agency UI
- Owner Command Center
- Clients + add client
- Client details
- Campaign Center
- Creative Center + fatigue indicators
- Finance + 20% spend / 10% sales commission
- Monthly Reports + score
- Alerts
- AI Analyst screen
- Client Portal preview مع عزل معلومات العمولة
- Offline/demo-first data model

## غير موصول بعد (مقصود)
- Supabase / real database
- Real authentication
- Meta Ads API
- Sales/CRM integration
- Push notifications
- Real AI API
- PDF generation
هذه مرحلة الربط الأخيرة بعد اعتماد الواجهة والـ business flow.

## Build APK
flutter pub get
flutter build apk --release


## V5 Meta Ads Settings

Added an in-app Meta Ads connection settings screen with:
- Meta App ID
- Ad Account ID
- masked access-token field for prototype/testing
- connection state
- production architecture note: OAuth + secure backend token storage

Production flow:
Connect Meta -> OAuth -> select authorized ad accounts -> sync campaigns/ad sets/ads -> metrics -> dashboard.

Do NOT hard-code or ship long-lived Meta access tokens in the APK.
