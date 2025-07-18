# Simplified AWS RDS Architecture Plan

## Overview

This document outlines the **dramatically simplified** AWS RDS implementation for Children of the Singularity, replacing the overcomplicated architecture from `phase_2_mvp.md`.

## Core Principle: Data Separation

**AWS RDS is ONLY for player-to-player trading. Everything else stays local.**

```
┌─────────────────────────────────────────────────────────────────┐
│                     SIMPLIFIED ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Player's Computer                     AWS Cloud                │
│  ┌──────────────────┐                ┌──────────────────┐      │
│  │   Godot Client   │                │   Trading API    │      │
│  │                  │                │                  │      │
│  │ ┌──────────────┐ │ ◄──────────────► │ ┌──────────────┐ │      │
│  │ │ Local SQLite │ │  Trading Only   │ │  AWS RDS     │ │      │
│  │ │              │ │                │ │              │ │      │
│  │ │ • Credits    │ │                │ │ • Trade      │ │      │
│  │ │ • Inventory  │ │                │ │   Listings   │ │      │
│  │ │ • Upgrades   │ │                │ │ • Offers     │ │      │
│  │ │ • Progress   │ │                │ │ • History    │ │      │
│  │ └──────────────┘ │                │ └──────────────┘ │      │
│  └──────────────────┘                └──────────────────┘      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## What Changed from Previous Plan

### ❌ REMOVED (Overcomplicated)
- Multi-AZ RDS setup
- JWT authentication system  
- Complex security layers
- All personal player data in cloud
- SQLAlchemy connection pooling
- Environment variable complexity
- User registration/login screens
- Cross-device synchronization

### ✅ SIMPLIFIED TO
- Single-AZ RDS (tiny instance)
- Simple API key authentication
- Only trading data in cloud
- Local SQLite for personal data
- Direct database connections
- Minimal environment config
- No user accounts needed
- Local-first data storage

## Data Split Strategy

| Data Type | Storage | Reasoning |
|-----------|---------|-----------|
| **Personal Data** | **Local SQLite** | **Fast, offline, private** |
| • Player credits | Local | No server lag for spending |
| • Current inventory | Local | Real-time collection feedback |
| • Ship upgrades | Local | Immediate gameplay effects |
| • Zone progress | Local | Single-player progression |
| • Settings/preferences | Local | Personal configuration |
| **Trading Data** | **AWS RDS** | **Shared between players** |
| • Active trade listings | Cloud | Visible to all players |
| • Trade offers/bids | Cloud | Player-to-player communication |
| • Trade history | Cloud | Dispute resolution |
| • Market prices | Cloud | Economic simulation |

## AWS RDS Configuration (Minimal)

### Instance Specifications
```bash
# Development
Instance Class: db.t3.micro (1 vCPU, 1GB RAM)
Storage: 20GB GP2
Backup: 7 days
Multi-AZ: NO (single AZ only)
Encryption: NO (trading data not sensitive)
Cost: ~$12/month

# Production (if needed later)
Instance Class: db.t3.small (2 vCPU, 2GB RAM)  
Storage: 50GB GP2
Backup: 7 days
Multi-AZ: NO (still single AZ)
Cost: ~$25/month
```

### Database Schema (Trading Only)
```sql
-- AWS RDS Schema (minimal)
CREATE DATABASE trading_marketplace;

-- Trade listings posted by players
CREATE TABLE trade_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    seller_id VARCHAR(255) NOT NULL,     -- Player identifier
    item_type VARCHAR(100) NOT NULL,     -- "upgrade" or "debris"
    item_name VARCHAR(255) NOT NULL,     -- "speed_boost_lv3" or "broken_satellite"
    quantity INTEGER NOT NULL DEFAULT 1,
    asking_price INTEGER NOT NULL,
    description TEXT,
    listed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active'  -- active, sold, expired, cancelled
);

-- Trade transactions/history
CREATE TABLE trade_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID REFERENCES trade_listings(id),
    buyer_id VARCHAR(255) NOT NULL,
    seller_id VARCHAR(255) NOT NULL,
    final_price INTEGER NOT NULL,
    completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Simple indexes
CREATE INDEX idx_listings_active ON trade_listings(status, listed_at);
CREATE INDEX idx_listings_seller ON trade_listings(seller_id);
CREATE INDEX idx_transactions_buyer ON trade_transactions(buyer_id);
```

## Local SQLite Schema

```sql
-- Local SQLite Database (user://save_data.db)
-- Stores ALL personal player data

CREATE TABLE player_data (
    key VARCHAR(50) PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Examples of stored data:
-- ('credits', '1500')
-- ('inventory', '[{"type":"scrap_metal","quantity":5}]')
-- ('upgrades', '{"speed_boost":2,"inventory_expansion":1}')
-- ('zone_progress', '{"max_zone":3,"unlocked_areas":["alpha","beta"]}')
-- ('player_name', 'SpaceSalvager42')

CREATE TABLE local_inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_type VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    acquired_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE local_upgrades (
    upgrade_type VARCHAR(100) PRIMARY KEY,
    level INTEGER NOT NULL DEFAULT 0,
    purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints (Simplified)

### Trading API (AWS RDS)
```python
# Only these endpoints needed:

GET  /api/v1/trading/listings              # Browse active listings
POST /api/v1/trading/listings              # Post new listing  
GET  /api/v1/trading/listings/{id}         # Get listing details
POST /api/v1/trading/listings/{id}/buy     # Purchase listing
DELETE /api/v1/trading/listings/{id}       # Cancel own listing

GET  /api/v1/trading/history/{player_id}   # Player's trade history
GET  /api/v1/trading/market-stats          # Price trends, volume
```

### No More Personal Data APIs
```python
# REMOVE these from backend (move to local):
# ❌ GET  /api/v1/players/{id}
# ❌ POST /api/v1/players/{id}  
# ❌ GET  /api/v1/players/{id}/inventory
# ❌ POST /api/v1/players/{id}/inventory
# ❌ POST /api/v1/players/{id}/credits
# ❌ POST /api/v1/players/{id}/upgrades/purchase
```

## Implementation Steps

### Phase 1: Local Storage Implementation
1. **Create SQLite wrapper in Godot**
   - `scripts/LocalDatabase.gd` - SQLite operations
   - `scripts/LocalPlayerData.gd` - Player data manager
   - `scripts/LocalInventory.gd` - Inventory operations

2. **Migrate existing player systems**
   - Update `PlayerShip.gd` to use local storage
   - Update `InventoryManager.gd` for SQLite
   - Remove backend sync from personal data

### Phase 2: Trading Backend (AWS RDS)
1. **Setup minimal RDS instance**
   - Single-AZ db.t3.micro
   - Simple security group (port 5432 from application)
   - Basic connection string

2. **Refactor backend**
   - Remove personal data endpoints
   - Add trading-only endpoints
   - Minimal authentication (API key)

### Phase 3: Trading Integration
1. **Create trading UI in Godot**
   - Trading marketplace browser
   - Listing creation interface  
   - Trade history viewer

2. **Connect trading systems**
   - Local inventory → Trading API
   - Purchase flow with local credit deduction
   - Real-time listing updates

## Cost Analysis

### Original Overcomplicated Plan
- Multi-AZ RDS: ~$50-100/month
- Authentication services: ~$10/month  
- Security monitoring: ~$20/month
- **Total: ~$80-130/month**

### New Simplified Plan
- Single-AZ micro RDS: ~$12/month
- **Total: ~$12/month**

**Savings: ~85% cost reduction**

## Benefits of Simplified Approach

### For Development
- ✅ **Faster iteration**: No complex authentication to test
- ✅ **Offline development**: Game works without internet
- ✅ **Simple debugging**: Local data easily inspected
- ✅ **Reduced complexity**: Fewer moving parts

### For Players  
- ✅ **Better performance**: No network lag for personal actions
- ✅ **Privacy**: Personal data stays local
- ✅ **Offline play**: Can play without internet connection
- ✅ **Faster responsiveness**: Immediate inventory/upgrade feedback

### For Operations
- ✅ **Lower costs**: 85% cost reduction
- ✅ **Simpler deployment**: Single small database
- ✅ **Easier maintenance**: Fewer systems to monitor
- ✅ **Better reliability**: Local data can't be lost to server issues

## Migration from Current System

### Files to Modify
```
backend/app.py              # Remove personal data endpoints, add trading
scripts/APIClient.gd         # Remove personal sync, add trading calls
scripts/PlayerShip.gd        # Switch to local storage
scripts/InventoryManager.gd  # Switch to local storage
data/postgres/schema.sql     # Replace with trading schema
```

### Files to Create
```
scripts/LocalDatabase.gd     # SQLite wrapper
scripts/LocalPlayerData.gd   # Local data manager
scripts/TradingAPI.gd        # Trading-specific API client
scenes/ui/TradingHub.tscn    # Trading marketplace UI
```

### Files to Remove
```
backend/auth.py              # No authentication needed
backend/models.py            # No complex ORM needed
backend/security.py         # Minimal security for trading only
```

## Next Steps

1. **Review this plan** - Confirm this matches your vision
2. **Test current AWS setup** - Check for any existing resources  
3. **Implement local storage** - Start with SQLite integration
4. **Create minimal RDS** - Single instance for trading
5. **Refactor backend** - Remove personal data, add trading
6. **Test end-to-end** - Verify local + trading works together

This approach gives you exactly what you wanted: **AWS RDS only for player trading, everything else local**.
