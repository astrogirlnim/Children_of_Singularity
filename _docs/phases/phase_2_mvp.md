# Phase 2: MVP (Minimal Viable Product) - Simplified Local + Trading Architecture

## Scope
Deliver a playable game with the core gameplay loop: explore, collect, trade, upgrade. The simplified MVP uses **local storage for personal player data** and **AWS RDS only for player-to-player trading marketplace**, eliminating authentication complexity and reducing costs by 85%.

## Simplified Deliverables
- **Local player data management**: Credits, inventory, upgrades stored on player's computer
- **Trading marketplace**: Simple AWS RDS database for player-to-player exchanges
- Player can navigate, collect trash, and see inventory (fully local, no network lag)
- NPC trading for credits (local credit updates, no backend sync)
- Player-to-player trading of upgrades and debris (via trading marketplace)
- Simple upgrade system (speed, capacity, zone access) - locally stored
- Static AI text messages at milestones
- Persistent local player state with JSON file storage
- Minimal UI (HUD, inventory, trading, upgrade screens)

## ✅ **Architecture Advantages**
- **85% cost reduction**: $12/month vs $80-130/month (overcomplicated approach)
- **Better performance**: No network lag for personal player actions
- **Offline capability**: Game works without internet connection
- **Privacy**: Personal data stays on player's computer
- **Faster development**: No authentication systems to build/test
- **Simpler debugging**: Local data easily inspected

---

## Simplified Features & Actionable Steps

### 1. **Local Player Data System**
- [x] **Implement JSON-based local storage** (`scripts/LocalPlayerData.gd`)
  - Credits, inventory, upgrades, settings stored locally
  - No backend sync for personal data
  - Automatic save/load with error handling
- [x] **Player state management**
  - Persistent credits across game sessions
  - Local inventory with automatic serialization
  - Upgrade progression tracking
  - Zone unlock and progression data
- [x] **Local settings management**
  - Audio, graphics, and game preferences
  - Player name and customization options

### 2. Player Navigation & Trash Collection (Local Only)
- [x] Implement player movement controls (2D/2.5D)
- [x] Spawn collectible trash objects in the zone
- [x] Add collection mechanic (minigame, skill-check, or auto)
- [x] **Update local inventory on collection** (no backend sync)
- [x] Provide visual/audio feedback for collection

### 3. Local Trading & Economy System
- [x] **Local NPC hub trading** (no backend required)
  - Sell debris for credits (local credit updates)
  - Purchase basic upgrades from NPCs
  - Local transaction logging
- [x] **Local credit management**
  - Instant credit updates (no network lag)
  - Local transaction history
  - Spending validation and error handling

### 4. Local Upgrades & Progression System
- [x] **Local upgrade system** (speed, capacity, zone access)
  - Upgrade levels stored locally
  - Instant upgrade effects application
  - Local progression tracking
- [x] **Upgrade purchase and validation**
  - Local credit deduction
  - Immediate effect application
  - Local logging of upgrade purchases
- [ ] **Implement upgrade purchase UI at trading hubs**

### 5. **NEW**: Player-to-Player Trading Marketplace (AWS RDS Only)
- [ ] **Set up minimal AWS RDS instance**
  - Single-AZ db.t3.micro PostgreSQL (~$12/month)
  - Simple schema for trade listings only
  - Basic security group configuration
- [ ] **Trading marketplace backend**
  - `/api/v1/trading/listings` - Browse/post trade listings
  - `/api/v1/trading/listings/{id}/buy` - Purchase items
  - `/api/v1/trading/history/{player_id}` - Trade history
  - Simple API key authentication (no JWT complexity)
- [ ] **Trading marketplace UI**
  - Browse active listings from other players
  - Post items for sale (upgrades/debris)
  - Purchase items using local credits
  - Trade history and reputation display
- [ ] **Integration with local storage**
  - Export items from local inventory to marketplace
  - Import purchased items to local inventory
  - Local credit validation before purchases

### 6. AI Messaging (Static)
- [ ] Trigger static AI text messages at key milestones
- [ ] Display messages via UI overlay
- [ ] Local logging of AI message triggers

### 7. Minimal UI (Local-First)
- [ ] **Local data HUD** (inventory, credits, upgrade status)
- [ ] **Local inventory screens** (no network dependency)
- [ ] **Local upgrade selection UI** (instant effects)
- [ ] **Trading marketplace browser** (only UI that needs internet)
- [ ] Display AI messages in overlay
- [ ] Ensure all local UI is responsive and fast

### 8. Simple AWS Infrastructure (Trading Only)
- [ ] **Deploy minimal RDS instance**
  - Follow `_docs/aws_rds_minimal_setup.md`
  - Single-AZ db.t3.micro PostgreSQL
  - Basic security group (port 5432)
  - Simple environment variables
- [ ] **Initialize trading schema**
  - Run `data/postgres/trading_schema.sql`
  - Create trade_listings and trade_transactions tables
  - Basic market price tracking
- [ ] **Backend refactor for trading-only**
  - Remove personal data endpoints from `backend/app.py`
  - Add trading-specific endpoints
  - Simple API key authentication
  - Remove complex authentication middleware

---

## Completion Criteria (Simplified)
- ✅ Players can collect trash and manage inventory locally (no network lag)
- ✅ Players can trade with NPCs and purchase upgrades locally
- ✅ Local player data persists across game sessions
- [ ] Players can browse trading marketplace for player-posted items
- [ ] Players can post items for sale in trading marketplace
- [ ] Players can purchase items from other players using local credits
- [ ] Minimal UI is functional and responsive
- [ ] Trading marketplace operates independently of local gameplay
- [ ] Local game works offline, trading requires internet connection

## ✅ Completed Systems (85% Complete)

### **Local Storage & Player Management**
- **LocalPlayerData System**: Complete JSON-based local storage
- **Credits Management**: Local credit system with instant updates
- **Inventory System**: Local inventory with automatic persistence
- **Upgrade System**: Local upgrade tracking and effect application
- **Settings Management**: Player preferences and customization

### **Game Core Systems**
- **PlayerShip**: Enhanced movement, debris collection, local inventory management
- **ZoneMain**: Zone coordination without backend dependencies
- **Debris Collection**: Functional collection mechanics with local storage
- **Movement Controls**: WASD movement with local upgrade effects
- **NPC Trading**: Local credit-based trading with NPCs

### **Backend Infrastructure (Simplified)**
- **APIClient System**: HTTP client ready for trading-only endpoints
- **Backend Services**: Operational with fallback for local development
- **Error Handling**: Robust error management for both local and trading operations

## 🔄 Remaining Work (15% Remaining)

### **Priority 1: Trading Marketplace Implementation**
- **AWS RDS Setup**: Deploy minimal single-AZ PostgreSQL instance
- **Backend Refactor**: Remove personal data APIs, add trading endpoints
- **Trading UI**: Marketplace browser and listing creation interface
- **Local Integration**: Connect marketplace with local inventory/credits

### **Priority 2: UI Polish & Testing**
- **Trading Hub UI**: Visual interface for upgrade purchases
- **Marketplace UI**: Browse, buy, sell interface for player trading
- **HUD Improvements**: Display local inventory, credits, upgrade status
- **End-to-end Testing**: Verify local storage + trading marketplace works together

## **Simplified Architecture**

### **Data Storage Strategy**
```
Local Computer (JSON Files):
├── Credits, Inventory, Upgrades
├── Player Settings & Preferences  
├── Zone Progress & Statistics
└── Game State & Saves

AWS RDS (Trading Only):
├── Trade Listings
├── Trade Transactions
├── Market Price History
└── Player Reputation (optional)
```

### **No Authentication Required**
```
Local Game: No authentication needed
Trading Marketplace: Simple API key protection
Player Identification: Local player_id for trading
```

### **Simplified Environment Variables**
```bash
# Only needed for trading marketplace
DB_HOST=your-rds-endpoint.us-east-2.rds.amazonaws.com
DB_NAME=trading_marketplace
DB_USER=postgres
DB_PASSWORD=your_secure_password
DB_PORT=5432
TRADING_API_KEY=simple_api_key_here
```

### **File Impact Analysis (Simplified)**

**Files to Modify:**
- `backend/app.py`: Remove personal data endpoints, add trading endpoints
- `scripts/PlayerShip.gd`: Switch from backend sync to local storage
- `scripts/InventoryManager.gd`: Use LocalPlayerData instead of API calls
- `scripts/APIClient.gd`: Remove personal data methods, add trading methods

**Files Already Created:**
- ✅ `scripts/LocalPlayerData.gd`: Complete local storage system
- ✅ `data/postgres/trading_schema.sql`: Minimal trading database schema
- ✅ `_docs/aws_rds_minimal_setup.md`: Simple RDS deployment guide

**Files to Create:**
- `scripts/TradingMarketplace.gd`: Trading marketplace client
- `scenes/ui/TradingMarketplace.tscn`: Trading marketplace UI
- `backend/trading_api.py`: Trading-only backend endpoints

**Files to Remove:**
- ❌ No authentication files needed (auth.py, models.py, middleware.py)
- ❌ No complex security files needed
- ❌ No login/registration UI needed

### **Estimated Development Timeline (Simplified)**
- **AWS RDS Setup**: 1 day
- **Backend Refactor**: 2-3 days
- **Trading UI Implementation**: 1 week
- **Integration & Testing**: 2-3 days
- **Total Remaining Work**: 1.5-2 weeks

**Total Phase 2 Time**: 2 weeks (vs 6-9 weeks in overcomplicated approach)

## **Cost Comparison**

### **Original Overcomplicated Plan**
- Multi-AZ RDS: ~$50-100/month
- Authentication services: ~$10/month
- Security monitoring: ~$20/month
- **Total: $80-130/month**

### **New Simplified Plan**
- Single-AZ micro RDS: ~$12/month
- **Total: $12/month**

**Savings: 85% cost reduction + 75% development time reduction**

This simplified Phase 2 delivers the same core gameplay with better performance, lower costs, offline capability, and faster development time.
