# Catering Ops

Catering Ops is a mobile operations platform built for catering and event-service businesses that still manage their daily workflow using calls, WhatsApp messages, and notebooks.

The goal of this project is simple:
make catering operations faster, cleaner, and easier to manage from one place.

Built with Flutter and Supabase, the platform helps owners manage orders, staff assignments, deliveries, payments, and realtime communication through a single mobile application.

---

# Why Catering Ops?

Many small and medium catering businesses struggle with:

- Missing order details
- Confusing delivery coordination
- Manual payment tracking
- No centralized system
- Last-minute communication issues

Catering Ops solves these problems by giving both owners and staff a structured workflow inside one app.

---

# User Roles

## Owner

Owners can:

- Create and manage orders
- Assign deliveries to staff
- Track pending payments
- Manage staff requests
- Monitor delivery progress
- Handle customer and middleman records

## Staff

Staff members can:

- View assigned deliveries
- Claim available delivery tasks
- Participate in delivery bidding
- Share live location
- Receive delivery reminders and updates

---

# Features

## Order Management

Create detailed catering orders with:

- Event date and time
- Venue details
- Pricing
- Menu information
- Customer details
- Middleman details

Orders are automatically organized based on urgency so important events stay visible.

---

## Delivery Assignment System

Owners can choose different delivery workflows:

- Direct assignment
- Open claim system
- Delivery bidding system

This gives flexibility depending on how the business operates.

---

## Live Location Sharing

Staff can share their live location during deliveries so owners can track delivery progress in realtime.

---

## Payment Tracking

The platform includes a simple ledger system for:

- Outstanding balances
- Payment history
- Client records
- Middleman tracking

---

## Notification System

Automatic notifications are sent for:

- New delivery assignments
- Open delivery requests
- Staff join requests
- Upcoming events and reminders

All notification handling is done securely through backend functions.

---

# Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| Notifications | OneSignal |
| Realtime Updates | Supabase Realtime |
| Location Services | Geolocator |
| Cloud Functions | Supabase Edge Functions |
| CI/CD | GitHub Actions |

---

# Security

The project follows a secure multi-tenant architecture.

Key security measures include:

- Row Level Security (RLS)
- Company-level data isolation
- Secure secret management
- Server-side notification handling
- Protected database access rules

Every company only has access to its own data.

---

# Project Structure

```txt
/
├── apps/
│   └── mobile_app/
│       ├── lib/
│       ├── services/
│       ├── features/
│       └── role_views/
│
├── backend/
│   ├── migrations/
│   └── functions/
│
└── supabase/
```

---

# Deployment

## Requirements

- Flutter SDK
- Supabase Project
- OneSignal App
- Firebase Project

---

## Configure Secrets

```bash
supabase secrets set ONESIGNAL_APP_ID="your_app_id"
supabase secrets set ONESIGNAL_REST_API_KEY="your_rest_key"
```

---

## Deploy Edge Functions

```bash
supabase functions deploy send-notification
```

---

## Run Database Migrations

Apply all migration files from:

```txt
backend/migrations/
```

using the Supabase SQL Editor.

---

## Build Release APK

```bash
flutter build apk --release
```

---

# Use Cases

Catering Ops can be used for:

- Catering businesses
- Event suppliers
- Corporate food delivery
- Equipment rental services
- Small logistics teams
- Event management operations

---

# Future Improvements

Planned features include:

- AI-based WhatsApp order parsing
- Inventory forecasting
- Customer web portal
- Analytics dashboard
- Multi-language support
- Multi-country support

---

# License

This project is proprietary and all rights are reserved.
