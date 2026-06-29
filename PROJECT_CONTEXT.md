# PROJECT_CONTEXT.md

# Poultry Pro - AI Project Context

## Project Overview

Poultry Pro is an offline-first Flutter application for poultry farm management.

The application allows poultry farmers to manage:

* Flocks
* Daily records
* Expenses
* Sales
* Inventory/Stock
* Health events
* Cloud backup and synchronization
* Pro subscriptions

The application must continue working without internet access.

---

# Technology Stack

Frontend

* Flutter
* Provider for state management
* Material Design

Local Storage

* SQLite (sqflite)

Backend

* Supabase

Authentication

* Anonymous accounts
* Email/password accounts

Payments

* Paystack
* Google Play Billing

Synchronization

* Custom SyncService
* SQLite Outbox Pattern
* Background synchronization

---

# Core Architecture

The application is Offline First.

SQLite is always the source of truth.

The client never treats Supabase as the primary database.

Every business operation must be written locally first.

Synchronization happens later.

Flow:

UI

↓

Provider

↓

DatabaseService

↓

SQLite

↓

Sync Queue

↓

SyncService

↓

Supabase

Never bypass this architecture.

---

# Database

DatabaseService is the only class responsible for local persistence.

Current database version:

9

Business tables

* flocks
* expenses
* sales
* daily_records
* stock
* health_events

Infrastructure tables

* sync_queue
* sync_logs
* sync_locks
* meta

The app uses soft deletes.

Records are never immediately removed.

deleted = 1 marks deleted records.

---

# Sync Architecture

Database writes must be atomic.

Every insert/update/delete creates a corresponding sync_queue entry inside the same SQLite transaction.

Never create business records without creating the queue record.

Never write directly to Supabase from Providers.

SyncService is responsible for

* Uploading pending changes
* Downloading server updates
* Conflict handling
* Retry logic
* Exponential backoff

Current queue priority

Delete
Highest

Flocks
Medium

Other tables
Normal

---

# Subscription System

IMPORTANT

The application is migrating from the old subscription system to a new license system.

Old system

subscriptions table

SubscriptionProvider.isPro

Deprecated.

Do not introduce new code that depends on it.

New system

licenses table

SubscriptionService

SubscriptionEntitlement

FeatureGate

New features should use the new license system.

Any remaining uses of SubscriptionProvider are technical debt that should be migrated carefully.

---

# Payments

Supported providers

* Paystack
* Google Play Billing

Payment verification must happen server-side.

Client code must never grant Pro access directly.

The client only reacts to successful verification.

The activate_license_from_iap RPC is intended to create/update licenses after verified purchases.

Never bypass server verification.

---

# Security Rules

Never trust client input for licenses.

Never grant Pro access from Flutter code.

Never bypass authentication.

Never expose service role keys.

Never remove Row Level Security protections.

---

# Offline Requirements

Offline functionality is a core feature.

The following must continue working offline:

* Creating flocks
* Recording expenses
* Daily records
* Health events
* Sales
* Stock management

Only cloud synchronization requires internet.

---

# Coding Rules

Prefer existing architecture over introducing new patterns.

Avoid duplicate logic.

Keep backwards compatibility whenever practical.

Do not rename database columns without migrations.

Do not increase database version unless schema changes.

When changing synchronization logic:

* preserve atomic writes
* preserve retry logic
* preserve queue ordering

---

# Error Handling

Never silently ignore exceptions.

Prefer descriptive custom exceptions.

Avoid crashing the application.

Gracefully handle network failures.

---

# Project Structure

lib/

models/

providers/

services/

database_service.dart

sync_service.dart

subscription_service.dart

payment/

screens/

widgets/

constants/

theme/

supabase/

functions/

migrations/

---

# Current Technical Debt

Known items that still need work

* Remaining SubscriptionProvider usage should migrate to the license system.
* SyncService should become entitlement-aware without treating blocked sync as an error.
* Feature gating should use cached entitlement where offline support is required.
* Remove legacy subscription logic once migration is complete.

---

# When Making Changes

Before modifying code:

1. Understand existing architecture.
2. Search for related implementations.
3. Minimize breaking changes.
4. Preserve offline-first behavior.
5. Explain why changes are needed.

Never rewrite large files unless necessary.

Prefer focused, minimal edits.

When unsure, ask before making architectural changes.

---

# Code Quality

Prefer readable code over clever code.

Avoid duplication.

Keep methods small.

Follow existing project style.

Add comments only where they improve understanding.

---

# Goal

Maintain a stable, offline-first poultry management application with reliable synchronization, secure subscription handling, and minimal regressions.
