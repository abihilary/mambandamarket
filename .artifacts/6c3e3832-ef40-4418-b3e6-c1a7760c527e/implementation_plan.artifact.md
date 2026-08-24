# Implementation Plan - Fix App Redirects and Enable Image Sharing

This plan addresses two issues:
1. **Redirect Issue**: Clicking a shared link opens the browser instead of the app.
2. **Image Sharing**: Shared listings only contain text, not the item's image.

## User Review Required

> [!IMPORTANT]
> **Android Configuration**: For App Links (deep links) to work, you MUST host a file at `https://mambandamarket.com/.well-known/assetlinks.json`. I will provide the content for this file.
>
> **iOS Configuration**: You will need to add the `Associated Domains` entitlement in Xcode (`applinks:mambandamarket.com`).

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///C:/Users/tardz/Desktop/marketplace/mambandamarket/pubspec.yaml)
- Add `path_provider: ^2.1.2`
- Add `path: ^1.9.0`

### Android Platform

#### [MODIFY] [AndroidManifest.xml](file:///C:/Users/tardz/Desktop/marketplace/mambandamarket/android/app/src/main/AndroidManifest.xml)
- Add an `intent-filter` to the `.MainActivity` activity to handle `https://mambandamarket.com/listing/*`.
- Set `android:autoVerify="true"` for automatic deep link verification.

### Flutter Navigation

#### [MODIFY] [navigation.dart](file:///C:/Users/tardz/Desktop/marketplace/mambandamarket/lib/navigation.dart)
- Update `DeepLinkGuard` to allow `/listing/` paths to pass through to the Navigator, while continuing to swallow Supabase auth callbacks.

#### [MODIFY] [main.dart](file:///C:/Users/tardz/Desktop/marketplace/mambandamarket/lib/main.dart)
- Import `ItemDetailScreen.dart`.
- Update `onGenerateRoute` to handle incoming `/listing/<id>` deep links.

### Item Detail Screen

#### [MODIFY] [ItemDetailScreen.dart](file:///C:/Users/tardz/Desktop/marketplace/mambandamarket/lib/Components/ItemDetailScreen.dart)
- Implement `_downloadImage(String url)` using `http` and `path_provider`.
- Update `_shareListing` to download the primary image and use `Share.shareXFiles`.
- Add a loading state for the share operation so the user knows the image is being prepared.

## Verification Plan

### Manual Verification
1. **Sharing**:
    - Open an item.
    - Tap Share.
    - Verify that the share sheet includes the item's image.
2. **Deep Linking**:
    - Build and install the app on Android.
    - Click a link like `https://mambandamarket.com/listing/some-id` from a text message or notes app.
    - Verify the app opens directly to that listing. (Note: verification requires `assetlinks.json` on the server).

## AssetLinks.json Content
```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.mabanda.mambandamarket",
      "sha256_cert_fingerprints": ["YOUR_APP_FINGERPRINT"]
    }
  }
]
```
*(You will need to replace `YOUR_APP_FINGERPRINT` with your actual SHA-256 fingerprint from the Google Play Console or keytool).*
