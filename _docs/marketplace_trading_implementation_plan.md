# MARKETPLACE Trading System Implementation Plan
**Children of the Singularity - Player-to-Player Trading**

## 🎯 Executive Summary

This plan implements a comprehensive player-to-player trading system in the existing MARKETPLACE tab of the 2D lobby. Building upon the current WebSocket lobby infrastructure and AWS serverless trading backend, this system will enable players to trade high-value debris, upgrade modules, and crafted items in real-time.

**Key Integration Points:**
- ✅ WebSocket lobby system (already implemented)
- ✅ AWS Lambda + S3 trading infrastructure (already deployed)
- ✅ Local-first data architecture with LocalPlayerData.gd
- ✅ 3-tab trading interface structure (SELL/BUY/MARKETPLACE)
- ✅ TradingMarketplace.gd API client system

---

## 📊 Current System Status

### ✅ Implemented Foundation Systems
- **2D WebSocket Lobby**: Real-time multiplayer lobby with position sync
- **Trading Infrastructure**: AWS Lambda + S3 with API Gateway endpoints
- **3-Tab Interface**: SELL/BUY tabs functional, MARKETPLACE tab structure exists
- **Local Data Management**: LocalPlayerData.gd with inventory/credits management
- **Debris System**: 5 active debris types with rarity/value progression
- **Upgrade System**: 6 upgrade types with effect application

### 🔄 Partially Implemented
- **MARKETPLACE Tab**: UI structure exists but not populated
- **TradingMarketplace.gd**: Basic API integration, needs marketplace-specific methods
- **Item Metadata**: Basic item info exists, needs marketplace-specific data

### ❌ Missing Components
- **Marketplace UI Population**: No listing display or interaction
- **Advanced Item Types**: No upgrade modules or crafted items
- **Real-time Updates**: No WebSocket integration for live marketplace updates
- **Marketplace Filtering**: No search/filter/sort functionality
- **Trade Notifications**: No real-time trade alerts

---

## 🏗️ Implementation Phases

### Phase 1: Basic Marketplace Infrastructure (3-4 days)
**Goal**: Enable basic debris trading through existing MARKETPLACE tab

#### Phase 1.1: Marketplace UI Foundation (Day 1)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Populate MARKETPLACE tab
- `scenes/zones/LobbyZone2D.tscn` - Add marketplace UI elements

**Tasks:**
- [ ] Add marketplace listing display container
- [ ] Create listing item template (seller, item, price, buy button)
- [ ] Add marketplace status/refresh functionality
- [ ] Implement marketplace tab activation logic
- [ ] Add "Post Item for Sale" button and dialog

**UI Components to Add:**
```gdscript
# New nodes in LobbyZone2D.tscn MARKETPLACE tab
@onready var marketplace_listings_scroll: ScrollContainer
@onready var marketplace_listings_container: VBoxContainer  
@onready var marketplace_status_label: Label
@onready var marketplace_refresh_button: Button
@onready var post_item_button: Button
@onready var post_item_dialog: AcceptDialog
@onready var item_selection_dropdown: OptionButton
@onready var asking_price_spinbox: SpinBox
```

**Dependencies**: None
**Success Criteria**: MARKETPLACE tab shows placeholder UI elements

#### Phase 1.2: Marketplace Data Integration (Day 1-2)
**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add marketplace-specific methods
- `scripts/LocalPlayerData.gd` - Add marketplace item validation

**Tasks:**
- [ ] Add `get_marketplace_listings()` method
- [ ] Add `post_item_for_sale()` method  
- [ ] Add `purchase_marketplace_item()` method
- [ ] Add marketplace item validation (can player sell this item?)
- [ ] Add marketplace credit validation (can player afford this item?)

**New TradingMarketplace.gd Methods:**
```gdscript
func get_marketplace_listings() -> Array[Dictionary]
func post_item_for_sale(item_type: String, item_name: String, quantity: int, asking_price: int) -> bool
func purchase_marketplace_item(listing_id: String, seller_id: String) -> bool
func can_sell_item(item_type: String, item_name: String, quantity: int) -> bool
func validate_marketplace_purchase(listing: Dictionary) -> Dictionary
```

**Dependencies**: Phase 1.1 complete
**Success Criteria**: Marketplace API methods functional with existing AWS backend

#### Phase 1.3: Basic Listing Display (Day 2)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Implement marketplace UI population

**Tasks:**
- [ ] Implement `_populate_marketplace_listings()` method
- [ ] Create listing item UI dynamically for each marketplace entry
- [ ] Add buy button handlers for each listing
- [ ] Implement marketplace refresh functionality
- [ ] Add error handling for marketplace operations

**Listing Display Format:**
```
[Broken Satellite] x1
Seller: PlayerName_123
Price: 200 credits
[BUY NOW] [VIEW DETAILS]
```

**Dependencies**: Phase 1.2 complete
**Success Criteria**: Players can see existing marketplace listings

#### Phase 1.4: Basic Item Posting (Day 3)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Implement item posting dialog

**Tasks:**
- [ ] Populate item selection dropdown with sellable inventory
- [ ] Implement posting validation (ownership, quantity, price limits)
- [ ] Add posting confirmation dialog
- [ ] Implement item removal from local inventory on successful posting
- [ ] Add posting success/failure feedback

**Posting Flow:**
1. Player clicks "Post Item for Sale"
2. Dialog shows inventory items eligible for sale (value ≥100 credits)
3. Player selects item, quantity, asking price
4. Confirmation dialog with final details
5. Item removed from inventory, posted to marketplace

**Dependencies**: Phase 1.3 complete
**Success Criteria**: Players can post high-value debris for sale

#### Phase 1.5: Basic Purchasing (Day 3-4)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Implement marketplace purchasing

**Tasks:**
- [ ] Add purchase confirmation dialog
- [ ] Implement credit validation before purchase
- [ ] Add purchased item to local inventory
- [ ] Handle purchase success/failure scenarios
- [ ] Update marketplace display after successful purchase

**Purchase Flow:**
1. Player clicks "BUY NOW" on listing
2. Confirmation dialog shows item details and final price
3. Credit validation (can afford?)
4. Purchase request to AWS backend
5. On success: item added to inventory, credits deducted
6. Marketplace refreshed to remove sold item

**Dependencies**: Phase 1.4 complete
**Success Criteria**: Players can purchase items from marketplace

**Phase 1 Deliverable**: Basic marketplace trading functional with high-value debris

---

### Phase 2: Advanced Marketplace Features (2-3 days)
**Goal**: Add filtering, search, real-time updates, and enhanced UX

#### Phase 2.1: Marketplace Filtering & Search (Day 1)
**Files to Modify:**
- `scenes/zones/LobbyZone2D.tscn` - Add filter UI controls
- `scripts/LobbyZone2D.gd` - Implement filtering logic

**Tasks:**
- [ ] Add item type filter dropdown (All, Debris, Upgrades, Crafted)
- [ ] Add price range filter (min/max price inputs)
- [ ] Add rarity filter (Common, Uncommon, Rare, Epic, Legendary)
- [ ] Add seller name search box
- [ ] Implement real-time filtering as user types/selects

**Filter UI Components:**
```gdscript
@onready var filter_item_type: OptionButton
@onready var filter_min_price: SpinBox
@onready var filter_max_price: SpinBox  
@onready var filter_rarity: OptionButton
@onready var search_seller: LineEdit
@onready var sort_options: OptionButton  # Price Low→High, High→Low, Recently Posted
```

**Dependencies**: Phase 1 complete
**Success Criteria**: Players can filter and search marketplace listings

#### Phase 2.2: Real-time Marketplace Updates (Day 2)
**Files to Modify:**
- `scripts/LobbyController.gd` - Add marketplace WebSocket messages
- `backend/trading_lobby_ws.py` - Add marketplace broadcast support
- `scripts/LobbyZone2D.gd` - Handle real-time marketplace updates

**Tasks:**
- [ ] Extend WebSocket protocol for marketplace events
- [ ] Add marketplace update broadcasting in Lambda
- [ ] Implement real-time listing additions in UI
- [ ] Implement real-time listing removals (sold items)
- [ ] Add "NEW!" indicators for recently posted items

**New WebSocket Messages:**
```json
// Client → Server: New item posted
{
  "action": "marketplace_post",
  "item_type": "debris",
  "item_name": "unknown_artifact",
  "quantity": 1,
  "asking_price": 1200
}

// Server → All Clients: New listing available
{
  "type": "marketplace_new_listing",
  "listing": {...},
  "seller_name": "PlayerName_123"
}

// Server → All Clients: Item sold
{
  "type": "marketplace_item_sold",
  "listing_id": "abc123",
  "buyer_name": "PlayerName_456"
}
```

**Dependencies**: Phase 2.1 complete
**Success Criteria**: Marketplace updates in real-time across all lobby clients

#### Phase 2.3: Enhanced UX & Notifications (Day 3)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add notification system
- `scenes/zones/LobbyZone2D.tscn` - Add notification UI

**Tasks:**
- [ ] Add marketplace notification overlay (top-right corner)
- [ ] Implement "Your item sold!" notifications
- [ ] Add "New rare item posted!" notifications for high-value items
- [ ] Add marketplace sound effects (post, purchase, notification)
- [ ] Implement marketplace activity log (recent transactions)

**Notification Types:**
- 🟢 **Item Sold**: "Your [Unknown Artifact] sold for 1200 credits!"
- 🔵 **Rare Item Posted**: "Legendary item posted: [Quantum Core] - 3000 credits"
- 🟡 **Purchase Successful**: "You purchased [AI Component] for 500 credits"
- 🔴 **Purchase Failed**: "Someone else bought that item first!"

**Dependencies**: Phase 2.2 complete
**Success Criteria**: Rich marketplace notifications and activity feedback

**Phase 2 Deliverable**: Full-featured marketplace with real-time updates and rich UX

---

### Phase 3: Upgrade Modules & Advanced Items (3-4 days)
**Goal**: Introduce tradeable upgrade modules and crafted items

#### Phase 3.1: Upgrade Module System (Day 1-2)
**Files to Create/Modify:**
- `scripts/UpgradeModules.gd` - New upgrade module system
- `scripts/LocalPlayerData.gd` - Add module inventory support
- `documentation/game_design/upgrade_modules_reference.md` - Module definitions

**Tasks:**
- [ ] Define upgrade module types (consumable vs permanent)
- [ ] Implement module crafting system (combine debris → modules)
- [ ] Add module inventory separate from debris inventory
- [ ] Implement module application system (use module → get upgrade)
- [ ] Add module marketplace integration

**Upgrade Module Types:**
```gdscript
# Consumable modules (single use)
"speed_boost_module": {
    "name": "Speed Boost Module",
    "description": "Temporarily increases ship speed for 10 minutes",
    "type": "consumable",
    "duration": 600,  # 10 minutes
    "effect_type": "speed_boost",
    "effect_value": 50,
    "crafting_cost": {"ai_component": 1, "broken_satellite": 2}
}

# Permanent modules (tradeable upgrades)
"inventory_expansion_kit": {
    "name": "Inventory Expansion Kit",
    "description": "Permanently increases inventory capacity by 5 slots",
    "type": "permanent",
    "effect_type": "inventory_expansion",
    "effect_value": 1,  # +1 upgrade level
    "crafting_cost": {"broken_satellite": 3, "scrap_metal": 10}
}
```

**Dependencies**: Phase 2 complete
**Success Criteria**: Players can craft and trade upgrade modules

#### Phase 3.2: Crafting System Integration (Day 2-3)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add crafting interface to trading computer
- `scenes/zones/LobbyZone2D.tscn` - Add crafting tab to trading interface

**Tasks:**
- [ ] Add 4th tab to trading interface: "CRAFT"
- [ ] Implement crafting recipe display
- [ ] Add crafting validation (required materials check)
- [ ] Implement crafting process (consume materials → create module)
- [ ] Add crafted item marketplace integration

**Crafting Interface:**
```
CRAFT Tab:
[Speed Boost Module]
Materials Required:
- AI Component x1 ✓
- Broken Satellite x2 ✗ (have 1/2)
Cost: 50 credits
[CRAFT] (disabled - missing materials)

[Inventory Expansion Kit]
Materials Required:
- Broken Satellite x3 ✓
- Scrap Metal x10 ✓
Cost: 25 credits
[CRAFT] ✓
```

**Dependencies**: Phase 3.1 complete
**Success Criteria**: Players can craft upgrade modules using debris

#### Phase 3.3: Advanced Marketplace Items (Day 3-4)
**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add support for new item types
- `backend/trading_lambda.py` - Update for new item categories

**Tasks:**
- [ ] Add upgrade module marketplace category
- [ ] Add crafted item marketplace category  
- [ ] Implement module-specific marketplace validation
- [ ] Add "Crafted by PlayerName" attribution for crafted items
- [ ] Implement marketplace value suggestions (recommended pricing)

**Advanced Item Categories:**
- **Debris**: Raw materials (existing system)
- **Upgrade Modules**: Consumable and permanent upgrades
- **Crafted Items**: Player-made advanced components  
- **Zone Access**: Special permits for restricted areas (future)

**Dependencies**: Phase 3.2 complete
**Success Criteria**: Full marketplace supports all item types

**Phase 3 Deliverable**: Complete trading ecosystem with crafting and advanced items

---

### Phase 4: Economic Balance & Polish (2-3 days)
**Goal**: Balance economy, add advanced features, optimize performance

#### Phase 4.1: Economic Balancing (Day 1)
**Files to Modify:**
- `scripts/EconomicBalancer.gd` - New economic analysis system
- `documentation/game_design/marketplace_economy_balance.md` - Economic guidelines

**Tasks:**
- [ ] Implement dynamic pricing suggestions based on supply/demand
- [ ] Add marketplace analytics (average prices, trade volume)
- [ ] Implement trade cooldowns to prevent market manipulation
- [ ] Add marketplace fees (small percentage to prevent spam)
- [ ] Create economic monitoring dashboard for debugging

**Economic Features:**
- **Dynamic Pricing**: Suggest prices based on recent sales
- **Supply/Demand**: Show market trends for each item type
- **Trade Limits**: Max 5 active listings per player
- **Marketplace Fees**: 5% transaction fee (credits sink)
- **Price Validation**: Prevent extreme over/under-pricing

**Dependencies**: Phase 3 complete
**Success Criteria**: Balanced marketplace economy with anti-exploitation measures

#### Phase 4.2: Performance Optimization (Day 2)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Optimize marketplace UI updates
- `scripts/TradingMarketplace.gd` - Add caching and pagination

**Tasks:**
- [ ] Implement marketplace listing pagination (show 20 at a time)
- [ ] Add client-side caching of marketplace data
- [ ] Optimize real-time update frequency (reduce WebSocket spam)
- [ ] Implement lazy loading for marketplace images/icons
- [ ] Add marketplace data compression for large listings

**Performance Targets:**
- **Listing Load Time**: <2 seconds for 100+ listings
- **Real-time Updates**: <500ms latency for marketplace changes
- **Memory Usage**: <50MB additional for full marketplace data
- **Network Traffic**: <10KB/minute for active marketplace updates

**Dependencies**: Phase 4.1 complete
**Success Criteria**: Marketplace performs well with 100+ concurrent users

#### Phase 4.3: Advanced Features & Polish (Day 3)
**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add advanced marketplace features
- `scenes/zones/LobbyZone2D.tscn` - Polish marketplace UI

**Tasks:**
- [ ] Add "Favorite Sellers" system (track preferred traders)
- [ ] Implement marketplace reputation system (successful trades)
- [ ] Add marketplace chat/messaging system
- [ ] Implement "Bulk Purchase" for multiple quantities
- [ ] Add marketplace history (your purchases/sales)

**Advanced Features:**
- **Trade History**: View your last 50 marketplace transactions
- **Seller Reputation**: Star rating based on successful trades
- **Quick Actions**: "Buy All [Item Type]" buttons
- **Price Alerts**: Notify when specific items posted below price threshold
- **Trade Statistics**: Personal trading analytics

**Dependencies**: Phase 4.2 complete
**Success Criteria**: Professional-grade marketplace with advanced trading features

**Phase 4 Deliverable**: Production-ready marketplace with economic balance and advanced features

---

## 🔧 Technical Implementation Details

### WebSocket Integration Pattern
```gdscript
# In LobbyController.gd - Add marketplace message handlers
func _process_marketplace_message(message: Dictionary) -> void:
    match message.get("type"):
        "marketplace_new_listing":
            lobby_zone.add_marketplace_listing(message.listing)
        "marketplace_item_sold":
            lobby_zone.remove_marketplace_listing(message.listing_id)
        "marketplace_price_update":
            lobby_zone.update_price_suggestions(message.price_data)
```

### AWS Lambda Backend Extension
```python
# In trading_lobby_ws.py - Add marketplace WebSocket broadcasting
def handle_marketplace_post(event, connection_id):
    # Validate and store new listing
    listing = create_marketplace_listing(event['body'])

    # Broadcast to all connected clients
    broadcast_message({
        'type': 'marketplace_new_listing',
        'listing': listing,
        'seller_name': get_player_name(connection_id)
    })
```

### Local Data Integration
```gdscript
# In LocalPlayerData.gd - Add marketplace item tracking
func can_sell_item(item_type: String, quantity: int) -> bool:
    var available_quantity = get_item_quantity(item_type)
    var active_listings = get_active_marketplace_listings()
    var already_listed = count_listed_quantity(item_type, active_listings)

    return available_quantity >= (quantity + already_listed)
```

---

## 📋 Dependencies & Prerequisites

### External Dependencies
- ✅ **AWS Infrastructure**: Lambda + S3 + API Gateway (already deployed)
- ✅ **WebSocket System**: LobbyController.gd (already implemented)
- ✅ **Local Data System**: LocalPlayerData.gd (already functional)

### Internal Dependencies
- **Phase 1** → **Phase 2**: Basic marketplace must work before adding real-time features
- **Phase 2** → **Phase 3**: Real-time updates needed before advanced item types
- **Phase 3** → **Phase 4**: All item types must exist before economic balancing

### Code Dependencies
- `TradingMarketplace.gd` extensions for new item types
- `LobbyZone2D.gd` modifications for MARKETPLACE tab population
- `LobbyController.gd` WebSocket message handling extensions
- Backend Lambda function updates for new marketplace events

---

## 🎯 Success Criteria & Testing

### Phase 1 Success Criteria
- [ ] Players can view existing marketplace listings in MARKETPLACE tab
- [ ] Players can post high-value debris (≥100 credits) for sale
- [ ] Players can purchase items using their local credits
- [ ] All transactions properly update local inventory and credits
- [ ] AWS backend correctly stores and retrieves marketplace data

### Phase 2 Success Criteria  
- [ ] Marketplace filters work (item type, price range, rarity)
- [ ] Real-time updates show new listings immediately to all lobby players
- [ ] Sold items disappear from all clients within 2 seconds
- [ ] Notifications system provides clear feedback for all marketplace actions

### Phase 3 Success Criteria
- [ ] Players can craft upgrade modules using debris combinations
- [ ] Upgrade modules function correctly (consumable vs permanent effects)
- [ ] All item types (debris, modules, crafted) tradeable in marketplace
- [ ] Crafting system integrated with existing upgrade progression

### Phase 4 Success Criteria
- [ ] Marketplace handles 100+ concurrent users without performance issues
- [ ] Economic balance prevents exploitation while enabling fair trading
- [ ] Advanced features enhance trading experience without overwhelming UI
- [ ] System ready for production deployment

---

## 🚀 Post-Implementation Roadmap

### Immediate Post-Launch
- Monitor marketplace trading patterns and economic balance
- Collect player feedback on UI/UX and trading experience
- Performance monitoring and optimization based on real usage
- Bug fixes and stability improvements

### Future Enhancements
- **Zone-Specific Trading**: Different debris types available in different zones
- **Guild Trading**: Team-based trading with shared inventories  
- **Auction System**: Time-based bidding for rare items
- **Contract Trading**: Player-to-player resource delivery missions
- **Marketplace API**: External tools for trading analysis

---

## 📁 File Structure Impact

```
_docs/
├── marketplace_trading_implementation_plan.md          # This document
├── marketplace_economy_balance.md                      # Economic guidelines (Phase 4)
└── upgrade_modules_reference.md                        # Module definitions (Phase 3)

scripts/
├── LobbyZone2D.gd                                     # Major modifications (all phases)
├── TradingMarketplace.gd                              # Extensions (Phase 1-3)
├── LobbyController.gd                                 # WebSocket additions (Phase 2)
├── UpgradeModules.gd                                  # New system (Phase 3)
├── EconomicBalancer.gd                                # New system (Phase 4)
└── LocalPlayerData.gd                                 # Module support (Phase 3)

scenes/zones/
└── LobbyZone2D.tscn                                   # UI additions (all phases)

backend/
├── trading_lobby_ws.py                                # Marketplace broadcasting (Phase 2)
└── trading_lambda.py                                  # Item type support (Phase 3)
```

This implementation plan provides a comprehensive roadmap for building a full-featured marketplace trading system that integrates seamlessly with the existing WebSocket lobby and AWS infrastructure while maintaining the local-first architecture principles of the game.
