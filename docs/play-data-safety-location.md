# Play Data safety — location

Filled in when the coarse-location feature shipped. Google checks these answers
against the manifest and against the privacy policy; a mismatch on any of the
three fails review, and the failure arrives days later as a rejection rather
than immediately as an error.

## What the app actually does

- One permission: `ACCESS_COARSE_LOCATION`. The merged **release** manifest was
  checked, not just the source file — `geolocator_android` declares
  `ACCESS_FINE_LOCATION` in its own manifest and manifest merging is a union, so
  `android/app/src/main/AndroidManifest.xml` removes it with
  `tools:node="remove"`. Verified with `aapt2 dump permissions` on the built
  release APK: COARSE present, FINE absent.
- No `ACCESS_BACKGROUND_LOCATION`, and there must never be one. Adding it puts
  the app into Play's background-location review, which nothing here is worth.
- The coordinate is read only from a press: the pin beside the home search
  field, the "use my current location" button on the publish form, and the
  seller-hub backfill. Nothing reads it on launch or on a timer.
- It is rounded to **three decimals (~110 m)** twice: in the app before it goes
  into a query string (`core-api` logs request URLs), and again on the server in
  `pointWkt()` before it is stored. Buyers are shown a distance; the coordinate
  itself is never rendered anywhere.

## The answers

| Question | Answer |
|---|---|
| Does your app collect or share location? | Yes — collected, not shared |
| Type | **Approximate location** only. Not precise location. |
| Collected or shared? | Collected |
| Processed ephemerally? | No — it is stored on the listing |
| Required or optional? | **Optional**: the app works fully without it |
| Purpose | **App functionality** only. Not analytics, not advertising, not personalisation. |
| Is data encrypted in transit? | Yes |
| Can users request deletion? | Yes — editing a listing removes it, and account deletion removes the row |

## Privacy policy

`mambandamarket-site/legal-content.js` carries the matching wording in all three
locales (en/fr/de) under "What we collect". It says: approximate, from the phone
only when the button is pressed and permission granted, rounded to ~110 m,
foreground only, refusable, and that buyers see a distance rather than
coordinates. **The policy must be deployed before the Play submission** — the
reviewer reads the live page, not the repository.
