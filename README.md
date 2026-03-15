# 🍽️ Catering Ops

> A production-grade mobile operations platform for catering and event-service businesses — built with Flutter & Supabase.

---

## 🚨 Problem Context

Catering businesses run on WhatsApp messages, phone calls, and physical notebooks. As orders grow, this informal system causes missed details, payment leakage, and operational chaos.

**Catering Ops replaces all of that with one app.**

---

## 📱 App Overview

Catering Ops is a **multi-tenant SaaS mobile app** with two roles:
- **Owner** — Creates and manages orders, assigns staff, tracks payments.
- **Staff** — Receives assignments, claims deliveries, shares live location.

---

## ✨ Core Features

### 👑 Owner Features

| Feature | Description |
|---|---|
| **Order Hub** | Create orders with event date, menu, pricing, venue, and middleman |
| **Smart Dashboard** | Orders auto-sorted by time. NEXT UP banner highlights the urgent one |
| **Staff Assignment** | Assign to specific staff, open for bidding, or fastest claim |
| **Delivery Bidding** | Staff can place bids; owner picks the best offer |
| **Venue Sharing** | Paste any Google Maps or WhatsApp location link — auto-parsed |
| **Khata (Ledger)** | Track middleman / client balances automatically |
| **Payment Tracking** | Mark orders as paid; runs a live outstanding balance |
| **Staff Management** | Approve/reject join requests from staff via unique company code |
| **Signature Capture** | Collect digital signatures for completed deliveries |

### 👷 Staff Features

| Feature | Description |
|---|---|
| **Assigned Orders** | See all orders assigned to you, sorted by urgency |
| **Live Location Share** | One-tap location sharing with owner during delivery |
| **Claim/Bid Delivery** | Claim open deliveries instantly or place competitive bids |
| **Order Reminders** | Auto-alerts 6 hours and 2 hours before every event |

### 🔔 Notification System

| Trigger | Who Gets It |
|---|---|
| New Order Assigned | Specific Staff Member |
| Open for Bidding | All Staff in Company |
| Fastest Claim Available | All Staff in Company |
| Staff Join Request | Owner |
| Order Reminder (6h / 2h) | Assigned Staff |

All notifications are secured via **Supabase Edge Functions** — no API keys are exposed in the app.

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) |
| Backend / Database | Supabase (PostgreSQL) |
| Authentication | Supabase Auth |
| Push Notifications | OneSignal (via Supabase Edge Function) |
| Realtime Updates | Supabase Realtime (WebSockets) |
| Location | Geolocator |
| Cloud Functions | Supabase Edge Functions (Deno/TypeScript) |
| CI/CD | GitHub Actions |

---

## 🔒 Security Architecture

- **Row Level Security (RLS):** Every database table is protected. Owners can only ever access their own company's data.
- **Multi-Tenancy:** Strict company-level data isolation enforced at the database layer.
- **Secret Management:** All API keys (OneSignal, Supabase) are stored in Supabase Vault Secrets — never bundled in the APK.
- **Zero-Trust Notifications:** Notification triggers are handled server-side via Edge Functions.

---

## 🗂️ Project Structure

```
/
├── apps/
│   └── mobile_app/         # Flutter application
│       ├── lib/
│       │   ├── core/        # Env, constants
│       │   ├── features/    # Orders, Bidding, Khata, Profile
│       │   ├── role_views/  # Owner & Staff specific screens
│       │   └── services/    # NotificationService, Location
│       └── android/         # Native Android config
├── backend/
│   ├── migrations/          # 33+ SQL migration files
│   └── functions/
│       └── send-notification/ # Secure OneSignal Edge Function
└── supabase/                # Supabase CLI config
```

---

## 🚀 Deployment

### Prerequisites
- Flutter SDK
- Supabase project
- OneSignal App
- Firebase project (for FCM on Android)

### 1. Set Supabase Secrets
```bash
supabase secrets set ONESIGNAL_APP_ID="your_app_id"
supabase secrets set ONESIGNAL_REST_API_KEY="your_rest_key"
```

### 2. Deploy Edge Function
```bash
supabase functions deploy send-notification
```

### 3. Run Migrations
Apply all SQL files from `backend/migrations/` in order via the Supabase SQL Editor.

### 4. Build App
```bash
flutter build apk --release
```

---

## 🌍 Who Is This For?

Any service business that manages **multiple client orders and staff deliveries**:

- Catering companies & function hall vendors
- Beverage / ice-cream suppliers for events
- Corporate meal suppliers
- Equipment rental services
- Small logistics & delivery businesses

---

## 🔭 Future Roadmap

- **AI Order Parsing** — Convert WhatsApp messages into structured orders automatically.
- **Inventory Prediction** — AI-powered ingredient forecasting based on past orders.
- **Client Portal** — Allow clients to place orders directly via a web interface.
- **Analytics Dashboard** — Revenue, staff performance, and inventory insights.
- **Multi-Country Support** — Expand beyond India with currency and language localization.

---

## 📄 License

This project is proprietary. All rights reserved.