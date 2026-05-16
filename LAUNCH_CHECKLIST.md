# Launch Checklist

Run top-to-bottom before submitting to TestFlight / Play Console internal track.

## 1. Credentials rotated (SECURITY_ROTATION.md)
- [ ] Supabase anon + service + JWT secret rolled
- [ ] Mapbox public + downloads tokens rolled
- [ ] Gemini API key rolled, in Edge Function secrets only
- [ ] Redis password rolled, instance behind firewall / VPC
- [ ] Firebase API key restricted by Android package + SHA-1
- [ ] Git history scrubbed; force-pushed to remote

## 2. Database
- [ ] All migrations applied: `supabase db push`
- [ ] RLS enabled on every public table — verified via SQL audit
- [ ] Cross-user query test in CI passes (user A cannot read user B's rows)
- [ ] Indexes present: `activities(user_id, started_at)`, `friendships(friend_id)`, `kudos(activity_id)`, segments GIST

## 3. Edge Functions deployed
- [ ] `delete-account`
- [ ] `coach-insight`
- [ ] `process-coaching`
- [ ] `revenuecat-webhook`
- [ ] Function secrets set: `GEMINI_API_KEY`, `RC_WEBHOOK_AUTH_TOKEN`

## 4. Client config
- [ ] `.env.json` populated from `.env.example.json` (not committed)
- [ ] `SENTRY_DSN` valid; sample event lands in Sentry dashboard
- [ ] `BACKEND_CERT_SHA256_FINGERPRINTS` populated (two pins for rotation)
- [ ] `REVENUECAT_IOS_KEY` + `REVENUECAT_ANDROID_KEY` set
- [ ] `flutter pub get` succeeds without resolution errors
- [ ] `dart run build_runner build --delete-conflicting-outputs` succeeds (freezed)
- [ ] `flutter gen-l10n` succeeds (AppLocalizations generated)
- [ ] `flutter analyze` reports zero errors / warnings

## 5. Build signing
- [ ] Android: production keystore in `~/.android/apexrun-release.keystore`
- [ ] `android/key.properties` populated (gitignored)
- [ ] `signingConfigs.release` references production keystore
- [ ] `isMinifyEnabled = true` and `isShrinkResources = true` for release
- [ ] iOS: distribution certificate + provisioning profile in App Store Connect
- [ ] iOS: bundle id `com.apexrun.app` matches Firebase + Mapbox config

## 6. Permissions + capabilities (iOS)
- [ ] All `NS*UsageDescription` strings present in `ios/Runner/Info.plist`
- [ ] `UIBackgroundModes` contains `location`, `audio`, `processing`
- [ ] HealthKit capability added in Xcode (Signing & Capabilities)
- [ ] Push Notifications capability added
- [ ] Associated Domains capability + `applinks:apexrun.app` for universal links
- [ ] App Tracking Transparency: NOT applicable (no IDFA collection)

## 7. Permissions + capabilities (Android)
- [ ] All permissions in `android/app/src/main/AndroidManifest.xml`
- [ ] `FOREGROUND_SERVICE_LOCATION` declared (Android 14+ requirement)
- [ ] Play Console Sensitive Permissions form completed (location + background)
- [ ] App Link verification: `https://apexrun.app/.well-known/assetlinks.json` deployed

## 8. Subscriptions
- [ ] RevenueCat project created at app.revenuecat.com
- [ ] Products in Apple App Store Connect + Google Play Console:
      `apex_pro_monthly`, `apex_pro_annual`, `apex_pro_plus_monthly`, `apex_pro_plus_annual`
- [ ] Entitlement identifiers: `pro`, `pro_plus`
- [ ] Webhook URL configured: `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`
- [ ] Webhook auth header: `Authorization: Bearer <RC_WEBHOOK_AUTH_TOKEN>`
- [ ] Sandbox purchase tested end-to-end → `subscriptions` row updates

## 9. Auth + accounts
- [ ] Google OAuth client IDs configured in Supabase Auth + GCP Console
- [ ] Sign-In with Apple service enabled (Apple Developer + Supabase)
- [ ] Email confirmation template branded
- [ ] Password reset deep-link `apexrun://reset-password` tested
- [ ] Account deletion tested end-to-end → row purged in Supabase + RevenueCat

## 10. Push
- [ ] FCM project linked; `google-services.json` + `GoogleService-Info.plist` present
- [ ] APNS key uploaded to Firebase Cloud Messaging
- [ ] Test notification arrives in foreground + background + killed states

## 11. App Store / Play Store assets
- [ ] App icon 1024×1024 (no alpha for iOS)
- [ ] iOS screenshots (6.7", 6.5", iPad 12.9")
- [ ] Android screenshots (phone, 7" tablet, 10" tablet)
- [ ] App preview video (15s, optional)
- [ ] Promo graphic 1024×500 (Play Store)
- [ ] Store description (`STORE_LISTING.md` → copy into both portals)
- [ ] Privacy policy URL live: `https://apexrun.app/privacy`
- [ ] Terms of service URL live
- [ ] Support URL live with at least an email contact

## 12. Compliance
- [ ] Privacy policy lists all third parties: Supabase, Mapbox, Google (Gemini, OAuth, FCM), Apple, Sentry, RevenueCat
- [ ] Data processing addenda signed with Supabase + RevenueCat (if EU users)
- [ ] App Store / Play Store privacy questionnaires completed (STORE_LISTING.md)
- [ ] Account deletion flow visible in-app (Profile → Delete Account)
- [ ] Data export endpoint or manual support process documented

## 13. Performance smoke test
- [ ] Cold-start to home screen < 3s on iPhone 12 / Pixel 6
- [ ] Record screen at 60fps during 30-minute test run
- [ ] Background tracking survives 1-hour test run with screen off
- [ ] Battery drain < 8%/hour during recording (target)
- [ ] APK / IPA size < 80 MB
- [ ] No crashes during a 30-minute smoke test (Sentry confirms)

## 14. Beta distribution
- [ ] TestFlight build uploaded; internal testers added
- [ ] Play Console internal track build uploaded
- [ ] 20+ external testers identified for closed-beta phase
- [ ] Feedback channel set up (Discord / Telegram / in-app `mailto:` link)
