# poost Media Buying OS — Android app + Supabase backend

هذا الريبو فيه تطبيق Flutter (Android) لإدارة شركة media buying، ومربوط فعليًا بمشروع Supabase حقيقي (auth + database)، وليس UI تجريبي فقط. راجع `PROJECT_STATUS.md` لتفاصيل حالة كل جزء.

## موجود وشغال فعليًا
- Auth حقيقي عبر Supabase (username/password → synthetic email داخليًا)
- توجيه حسب الدور (Owner / Media Buyer / Client) بعد تسجيل الدخول، كل دور بيشوف شاشة مختلفة
- عزل بيانات العمولة عن دور الـ Client بشكل فعلي في الكود (مش بس في التصميم)
- Row Level Security مفعّل على كل جداول قاعدة البيانات (`docs/MIGRATION_RLS_POLICIES.sql`) — كل يوزر بيشوف بيانات وكالته/عملائه فقط
- شاشة إعدادات اتصال Meta Ads (UI فقط، بدون تخزين توكن دائم)
- Edge Function محمي لإنشاء يوزرات جديدة (Media Buyer / Client) بمعرفة الـ Owner فقط

## لسه مش موصول (مقصود، مرحلة قادمة)
- Meta Ads API sync فعلي (الشاشة موجودة، الربط الحقيقي لسه لأ)
- Sales/CRM integration
- Push notifications
- AI Analyst حقيقي
- PDF generation
- شاشات الـ Dashboard الفعلية لسه placeholders ("—") لحد ما يتم بناء استعلامات Supabase للـ KPIs

## أول تشغيل (Setup)
اتبع الترتيب في `docs/CONNECT_NOW.md` بالظبط:
1. طبّق `docs/DATABASE_SCHEMA.sql`
2. طبّق `docs/MIGRATION_AUTH_PERMISSIONS.sql`
3. طبّق `docs/MIGRATION_RLS_POLICIES.sql` — **لازم تتطبق قبل أي استخدام حقيقي**، من غيرها البيانات مكشوفة لأي حد معاه الـ anon key
4. Deploy لـ `supabase/functions/create-app-user`
5. شغّل التطبيق واعمل "تهيئة Owner لأول مرة" باسم مستخدم وباسورد من اختيارك (مفيش بيانات دخول جاهزة في الكود عمدًا)

## Build APK
```
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## أمان — قواعد ثابتة
- ما فيش أي باسورد أو توكن حقيقي بيتكتب في الكود المصدري أبدًا
- ما فيش تخزين دائم لـ Meta access token جوه التطبيق — الربط الحقيقي هيكون عبر OAuth + backend
- كل جدول في قاعدة البيانات لازم يكون عليه RLS policy قبل ما يتفتح استخدامه من التطبيق
