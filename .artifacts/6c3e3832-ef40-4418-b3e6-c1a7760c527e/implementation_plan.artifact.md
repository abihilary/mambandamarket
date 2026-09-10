# Implementation Plan - Redesign Shipments & Tracking Screens (High Fidelity)

I will overhaul the shipment list and tracking detail screens to match the provided high-fidelity mockups, including simulated data to ensure a perfect visual match while API issues are resolved.

## Proposed Changes

### 1. Mock Data Integration
- Define a set of `ShippingRequest` objects within `ShipmentsScreen.dart` that match the items in the screenshots (Smartphone #MB-48291, Laptop #MB-48210).
- Update the UI to fallback to these mock items if the live list is empty.

### 2. Overhaul Shipments List Screen
- **Header**: Apply a dark background (`#111318`) to the AppBar and Status Bar area.
- **Tabs**: Redesign `_TabChip` as a segmented control with a lime (`#C9E505`) background for the selected state and pill-shaped corners.
- **Cards**: Complete redesign of `_ShipmentCardDesign`:
    - Add item image thumbnail on the left.
    - Right side: Bold `#Reference`, item title, Status row with truck icon, Route (`A → B`), ETA text, and Price in bold.
    - Large full-width action buttons (`Track Package →` or `View Details`).

### 3. Overhaul Tracking Detail Screen
- **Banner**: Implement the "Your package is on the way!" banner with the truck-on-road illustration background.
- **Timeline**: Redesign `_TimelineRowDesign` to match the vertical green-line style with circular status indicators (checked for past, active pulse for current, open for future).
- **Location Card**: Redesign the "Current location" box with the mini-map snippet and truck icon.
- **Actions**: Update the bottom buttons to use the outlined/elevated styles shown in the mockup.

## Verification Plan

### Manual Verification
1. Open the "My Shipments" screen.
2. Verify the list matches Image 1 (Smartphone in transit, Laptop delivered).
3. Click "Track Package" on the smartphone shipment.
4. Verify the detail screen matches Image 2 (Timeline, banner, mini-map).
5. Switch between "Active" and "Delivered" tabs and verify content filtering.
