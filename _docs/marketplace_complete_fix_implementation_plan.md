# Marketplace Complete Fix Implementation Plan
**Children of the Singularity - Full Two-Sided Marketplace System**

## 🎯 Overview

This document outlines the complete implementation plan to fix the current marketplace system issues and implement missing seller-side functionality. The plan is organized by dependency order - each phase must be completed before moving to the next.

**Current Issues:**
- ❌ Buyer purchases hang with "Processing purchase..."
- ❌ Credits don't update after purchase attempts
- ❌ Listings don't refresh after operations
- ❌ Sellers never receive credits when items are sold
- ❌ No seller notifications for completed sales
- ❌ Incomplete transaction cycle

**Target State:**
- ✅ Reliable buyer purchase flow with proper error handling
- ✅ Complete seller credit distribution system
- ✅ Real-time notifications for both buyers and sellers
- ✅ Robust state management and error recovery
- ✅ Full transaction history and seller dashboard

---

## 🔄 Implementation Phases (Dependency Order)

### **Phase 1: Fix Critical Buyer System Issues**
*Priority: CRITICAL - Must be completed first*
*Estimated Time: 2-3 days*

The buyer system is fundamentally broken and must be fixed before any other work can proceed.

#### **Phase 1.1: HTTP Request Management & Timeouts**

**Problem:** Requests can hang indefinitely, causing "Processing purchase..." to persist.

**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add timeout handling
- `scripts/TradingConfig.gd` - Add timeout configuration

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
var request_timeout: float = 15.0  # 15-second timeout
var pending_requests: Dictionary = {}  # Track active requests
var timeout_timer: Timer

func _ready():
    super._ready()
    _setup_timeout_management()

func _setup_timeout_management():
    timeout_timer = Timer.new()
    timeout_timer.wait_time = 1.0  # Check every second
    timeout_timer.timeout.connect(_check_request_timeouts)
    timeout_timer.autostart = true
    add_child(timeout_timer)

func _check_request_timeouts():
    var current_time = Time.get_unix_time_from_system()
    for request_id in pending_requests:
        var request_data = pending_requests[request_id]
        if current_time - request_data.start_time > request_timeout:
            _handle_request_timeout(request_id)
```

**Infrastructure Changes:**
- Add request tracking system
- Implement automatic timeout handling
- Add request cancellation mechanism

#### **Phase 1.2: Purchase State Management**

**Problem:** No state tracking leads to UI getting stuck in "Processing" state.

**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add state management
- `scripts/LobbyZone2D.gd` - Update UI state handling

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
enum PurchaseState {
    IDLE,
    VALIDATING,
    SENDING_REQUEST,
    PROCESSING,
    COMPLETED,
    FAILED,
    TIMED_OUT
}

var current_purchase_state: PurchaseState = PurchaseState.IDLE
var purchase_state_data: Dictionary = {}

func _set_purchase_state(new_state: PurchaseState, data: Dictionary = {}):
    var old_state = current_purchase_state
    current_purchase_state = new_state
    purchase_state_data = data
    print("[TradingMarketplace] State: %s -> %s" % [_state_to_string(old_state), _state_to_string(new_state)])
    emit_signal("purchase_state_changed", new_state, data)
```

**Infrastructure Changes:**
- Centralized state management for all purchase operations
- State transition logging for debugging
- UI state synchronization system

#### **Phase 1.3: Enhanced Error Recovery & Credit Rollback**

**Problem:** Failed purchases don't properly rollback optimistic credit holds.

**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Enhanced error handling
- `scripts/LocalPlayerData.gd` - Add credit transaction logging

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
func _handle_purchase_failure(reason: String, error_code: int = 0):
    print("[TradingMarketplace] Purchase failed: %s (code: %d)" % [reason, error_code])

    # Rollback credit hold if it exists
    if purchase_state_data.has("held_credits") and purchase_state_data.has("original_credits"):
        var held_amount = purchase_state_data.get("held_credits", 0)
        var original_credits = purchase_state_data.get("original_credits", 0)

        # Verify current credits and restore if needed
        var current_credits = local_player_data.get_credits()
        if current_credits != original_credits:
            local_player_data.set_credits(original_credits)
            print("[TradingMarketplace] Rolled back %d credits (restored to %d)" % [held_amount, original_credits])

    _set_purchase_state(PurchaseState.FAILED, {"error": reason, "code": error_code})
    emit_signal("item_purchased", false, "")
    emit_signal("api_error", reason)
```

**Infrastructure Changes:**
- Atomic credit operations with rollback capability
- Credit transaction logging for audit trail
- Comprehensive error categorization system

#### **Phase 1.4: Signal Connection Verification & Auto-Recovery**

**Problem:** Signal connections may fail, breaking UI updates.

**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add signal verification
- `scripts/TradingMarketplace.gd` - Add connection diagnostics

**Changes Required:**

```gdscript
# LobbyZone2D.gd additions
func _verify_and_connect_trading_signals() -> bool:
    if not TradingMarketplace:
        print("[LobbyZone2D] ERROR: TradingMarketplace not available")
        return false

    var signal_connections = [
        {"signal": "listings_received", "method": "_on_marketplace_listings_received"},
        {"signal": "item_purchased", "method": "_on_item_purchase_result"},
        {"signal": "listing_posted", "method": "_on_item_posting_result"},
        {"signal": "listing_removed", "method": "_on_listing_removal_result"},
        {"signal": "api_error", "method": "_on_marketplace_api_error"},
        {"signal": "purchase_state_changed", "method": "_on_purchase_state_changed"}
    ]

    var all_connected = true
    for connection in signal_connections:
        if not TradingMarketplace.is_connected(connection.signal, Callable(self, connection.method)):
            print("[LobbyZone2D] Connecting signal: %s" % connection.signal)
            TradingMarketplace.connect(connection.signal, Callable(self, connection.method))

        # Verify connection was successful
        if not TradingMarketplace.is_connected(connection.signal, Callable(self, connection.method)):
            print("[LobbyZone2D] ERROR: Failed to connect signal: %s" % connection.signal)
            all_connected = false

    print("[LobbyZone2D] Signal verification complete - All connected: %s" % all_connected)
    return all_connected
```

**Infrastructure Changes:**
- Automatic signal connection verification on startup
- Signal connection retry mechanism
- Connection health monitoring

---

### **Phase 2: Backend Infrastructure Overhaul**
*Priority: HIGH - Required for complete marketplace*
*Estimated Time: 3-4 days*
*Dependencies: Phase 1 complete*

Fix the backend to support complete two-sided transactions.

#### **Phase 2.1: Enhanced AWS Lambda Function**

**Problem:** Current backend only handles buyer side of transactions.

**Files to Modify:**
- `backend/trading_lambda.py` - Complete rewrite for full transaction support
- `backend/requirements.txt` - Add new dependencies
- `infrastructure_setup.env` - Add new configuration

**Changes Required:**

```python
# backend/trading_lambda.py - New structure
import json
import boto3
import uuid
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from dataclasses import dataclass

@dataclass
class TradeTransaction:
    trade_id: str
    listing_id: str
    seller_id: str
    seller_name: str
    buyer_id: str
    buyer_name: str
    item_type: str
    item_name: str
    quantity: int
    final_price: int
    completed_at: str

class CreditManager:
    def __init__(self, s3_client):
        self.s3_client = s3_client
        self.bucket_name = os.environ.get('S3_BUCKET_NAME')

    def credit_seller(self, seller_id: str, amount: int, trade_id: str) -> Dict[str, Any]:
        """Credit seller for completed sale with atomic operations"""
        try:
            # Load seller's credit data with ETag for atomic updates
            credits_key = f"player_credits/{seller_id}.json"
            credits_data, etag = self.load_with_etag(credits_key)

            # Update seller credits
            current_credits = credits_data.get("credits", 0)
            new_credits = current_credits + amount

            credits_data.update({
                "credits": new_credits,
                "last_credit_transaction": {
                    "amount": amount,
                    "trade_id": trade_id,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                    "type": "sale"
                }
            })

            # Atomic write with ETag check
            self.save_with_etag(credits_key, credits_data, etag)

            return {
                "success": True,
                "new_balance": new_credits,
                "amount_credited": amount,
                "trade_id": trade_id
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "trade_id": trade_id
            }

class NotificationManager:
    def __init__(self, s3_client):
        self.s3_client = s3_client
        self.bucket_name = os.environ.get('S3_BUCKET_NAME')

    def notify_seller(self, seller_id: str, trade: TradeTransaction) -> Dict[str, Any]:
        """Create notification for seller about completed sale"""
        try:
            notification = {
                "id": str(uuid.uuid4()),
                "type": "item_sold",
                "trade_id": trade.trade_id,
                "item_name": trade.item_name,
                "quantity": trade.quantity,
                "price": trade.final_price,
                "buyer_name": trade.buyer_name,
                "sold_at": trade.completed_at,
                "read": False,
                "created_at": datetime.now(timezone.utc).isoformat()
            }

            # Load existing notifications
            notifications_key = f"player_notifications/{seller_id}.json"
            notifications_data, etag = self.load_with_etag(notifications_key)

            # Add new notification
            notifications_list = notifications_data.get("notifications", [])
            notifications_list.append(notification)

            # Keep only last 50 notifications
            if len(notifications_list) > 50:
                notifications_list = notifications_list[-50:]

            notifications_data["notifications"] = notifications_list
            notifications_data["unread_count"] = sum(1 for n in notifications_list if not n.get("read", False))

            # Save atomically
            self.save_with_etag(notifications_key, notifications_data, etag)

            return {"success": True, "notification_id": notification["id"]}

        except Exception as e:
            return {"success": False, "error": str(e)}

def lambda_handler(event, context):
    """Enhanced lambda handler with complete transaction support"""
    try:
        s3_client = boto3.client('s3')
        credit_manager = CreditManager(s3_client)
        notification_manager = NotificationManager(s3_client)

        method = event.get('httpMethod')
        path = event.get('path', '')

        if method == 'POST' and '/buy' in path:
            return handle_enhanced_purchase(event, credit_manager, notification_manager)
        elif method == 'GET' and '/notifications/' in path:
            return handle_get_notifications(event, notification_manager)
        elif method == 'GET' and '/credits/' in path:
            return handle_get_credits(event, credit_manager)
        else:
            # Existing functionality...
            return handle_existing_endpoints(event)

    except Exception as e:
        return create_response(500, {"error": str(e)})

def handle_enhanced_purchase(event, credit_manager, notification_manager):
    """Handle purchase with complete seller credit and notification"""
    # ... existing purchase logic ...

    # After successful purchase, credit seller and send notification
    if purchase_successful:
        trade_transaction = TradeTransaction(
            trade_id=trade_record["trade_id"],
            listing_id=listing_id,
            seller_id=target_listing["seller_id"],
            seller_name=target_listing["seller_name"],
            buyer_id=buyer_data["buyer_id"],
            buyer_name=buyer_data["buyer_name"],
            item_type=target_listing["item_type"],
            item_name=target_listing["item_name"],
            quantity=target_listing["quantity"],
            final_price=target_listing["asking_price"],
            completed_at=datetime.now(timezone.utc).isoformat()
        )

        # Credit seller
        credit_result = credit_manager.credit_seller(
            seller_id=trade_transaction.seller_id,
            amount=trade_transaction.final_price,
            trade_id=trade_transaction.trade_id
        )

        # Notify seller
        notification_result = notification_manager.notify_seller(
            seller_id=trade_transaction.seller_id,
            trade=trade_transaction
        )

        return create_response(200, {
            "success": True,
            "trade": trade_record,
            "item": item_data,
            "seller_credited": credit_result["success"],
            "seller_credit_amount": trade_transaction.final_price,
            "seller_notified": notification_result["success"]
        })
```

**Infrastructure Changes:**
- New S3 data structure for player credits
- New S3 data structure for player notifications
- Enhanced atomic operations with ETag checking
- Comprehensive error handling and logging

#### **Phase 2.2: API Endpoint Extensions**

**Problem:** Missing endpoints for seller functionality.

**Files to Create/Modify:**
- `backend/trading_lambda.py` - Add new endpoints
- Update API Gateway configuration

**New Endpoints Required:**
```
GET /notifications/{player_id} - Get seller notifications
GET /credits/{player_id} - Get player credit balance
POST /notifications/{player_id}/mark-read - Mark notifications as read
GET /sales-history/{player_id} - Get seller's sales history
```

**Infrastructure Changes:**
- API Gateway route additions
- Lambda function URL mapping updates
- CORS configuration for new endpoints

#### **Phase 2.3: Data Migration & Schema Updates**

**Problem:** Existing S3 data structure doesn't support new features.

**Files to Create:**
- `backend/migrate_data.py` - Data migration script
- `data/s3_schemas/player_credits.json` - Credit data schema
- `data/s3_schemas/player_notifications.json` - Notification schema

**Migration Script:**
```python
# backend/migrate_data.py
def migrate_existing_data():
    """Migrate existing marketplace data to support seller features"""

    # Create player credit files for existing players
    create_initial_credit_files()

    # Create notification files for existing players
    create_initial_notification_files()

    # Update existing trade records with credit information
    update_trade_records_with_credits()
```

**Infrastructure Changes:**
- Backup existing S3 data
- Run migration script
- Verify data integrity
- Update monitoring for new data structures

---

### **Phase 3: Complete Seller System Implementation**
*Priority: HIGH - Core marketplace functionality*
*Estimated Time: 4-5 days*
*Dependencies: Phase 1 & 2 complete*

Implement the missing seller-side functionality.

#### **Phase 3.1: Seller Notification System**

**Problem:** Sellers don't know when their items are sold.

**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add notification handling
- `scripts/LobbyZone2D.gd` - Add notification UI
- `scenes/zones/LobbyZone2D.tscn` - Add notification UI elements

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
signal item_sold(item_name: String, price: int, buyer_name: String)
signal notifications_received(notifications: Array)

func check_seller_notifications() -> void:
    """Check for new notifications about sold items"""
    if not local_player_data:
        return

    var player_id = local_player_data.get_player_id()
    var url = TradingConfig.get_api_base_url() + "/notifications/" + player_id

    print("[TradingMarketplace] Checking seller notifications for player: %s" % player_id)

    var error = http_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
    if error != OK:
        print("[TradingMarketplace] Failed to check notifications: %s" % str(error))

func _handle_notifications_response(data: Dictionary):
    """Process seller notifications from API"""
    if data.has("notifications"):
        var notifications = data.get("notifications", [])
        print("[TradingMarketplace] Received %d notifications" % notifications.size())

        # Process each notification
        for notification in notifications:
            if not notification.get("read", false):
                _process_new_notification(notification)

        emit_signal("notifications_received", notifications)

func _process_new_notification(notification: Dictionary):
    """Process a new seller notification"""
    var notification_type = notification.get("type", "")

    if notification_type == "item_sold":
        var item_name = notification.get("item_name", "")
        var price = notification.get("price", 0)
        var buyer_name = notification.get("buyer_name", "")

        # Credit the seller (amount already credited by backend)
        local_player_data.add_credits(price)

        # Emit signal for UI update
        emit_signal("item_sold", item_name, price, buyer_name)

        print("[TradingMarketplace] Item sold notification: %s for %d credits to %s" % [item_name, price, buyer_name])
```

**UI Changes:**

```gdscript
# LobbyZone2D.gd additions
var notification_popup: AcceptDialog
var notification_history: Array[Dictionary] = []

func _setup_notification_system():
    """Initialize notification UI system"""
    _create_notification_popup()
    _start_notification_polling()

func _create_notification_popup():
    """Create notification popup for seller alerts"""
    notification_popup = AcceptDialog.new()
    notification_popup.title = "Marketplace Notification"
    notification_popup.add_theme_color_override("title_color", Color.GREEN)
    add_child(notification_popup)

func _on_item_sold(item_name: String, price: int, buyer_name: String):
    """Handle notification that our item was sold"""
    var formatted_name = _format_item_name(item_name)
    var message = "ITEM SOLD!\n\n%s sold for %d credits\nBuyer: %s\n\nCredits added to your account." % [formatted_name, price, buyer_name]

    _show_seller_notification(message)

    # Refresh UI to show updated credits and listings
    _update_lobby_ui_with_player_data()
    _refresh_marketplace_listings()

    # Add to notification history
    notification_history.append({
        "type": "sale",
        "item_name": formatted_name,
        "price": price,
        "buyer_name": buyer_name,
        "timestamp": Time.get_datetime_string_from_system()
    })

func _show_seller_notification(message: String):
    """Display seller notification popup"""
    if notification_popup:
        notification_popup.dialog_text = message
        notification_popup.popup_centered()
```

**Infrastructure Changes:**
- Notification polling system (every 30 seconds)
- Notification history storage
- UI popup system for alerts

#### **Phase 3.2: Seller Dashboard & Trade History**

**Problem:** No way for sellers to track their marketplace activity.

**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add seller dashboard
- `scenes/zones/LobbyZone2D.tscn` - Add dashboard UI
- `scripts/TradingMarketplace.gd` - Add history API calls

**Changes Required:**

```gdscript
# LobbyZone2D.gd additions
var seller_dashboard_container: Control
var active_listings_list: ItemList
var sales_history_list: ItemList

func _setup_seller_dashboard():
    """Initialize seller dashboard UI"""
    if not seller_dashboard_container:
        return

    _create_active_listings_display()
    _create_sales_history_display()
    _populate_seller_dashboard()

func _populate_seller_dashboard():
    """Populate seller dashboard with current data"""
    if not TradingMarketplace:
        return

    # Get player's active listings
    var player_listings = TradingMarketplace.get_player_active_listings()
    _display_active_listings(player_listings)

    # Get sales history
    TradingMarketplace.get_player_sales_history()

func _display_active_listings(listings: Array[Dictionary]):
    """Display player's currently active listings"""
    if not active_listings_list:
        return

    active_listings_list.clear()

    for listing in listings:
        var item_name = listing.get("item_name", "")
        var quantity = listing.get("quantity", 1)
        var price = listing.get("asking_price", 0)
        var total_value = price * quantity

        var listing_text = "%s x%d - %d credits each (%d total)" % [item_name, quantity, price, total_value]
        active_listings_list.add_item(listing_text)
        active_listings_list.set_item_metadata(active_listings_list.get_item_count() - 1, listing)

func _on_sales_history_received(sales: Array[Dictionary]):
    """Handle sales history data from API"""
    if not sales_history_list:
        return

    sales_history_list.clear()

    for sale in sales:
        var item_name = sale.get("item_name", "")
        var price = sale.get("final_price", 0)
        var buyer = sale.get("buyer_name", "")
        var date = sale.get("completed_at", "")

        var sale_text = "%s - %d credits - Sold to %s on %s" % [item_name, price, buyer, date]
        sales_history_list.add_item(sale_text)
```

**Infrastructure Changes:**
- New API endpoint for sales history
- Dashboard UI integration with marketplace tabs
- Real-time dashboard updates

#### **Phase 3.3: Credit Synchronization System**

**Problem:** Seller credits may get out of sync between client and server.

**Files to Modify:**
- `scripts/TradingMarketplace.gd` - Add credit sync
- `scripts/LocalPlayerData.gd` - Add sync validation
- Backend credit endpoints

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
func sync_player_credits() -> void:
    """Synchronize local credits with server"""
    if not local_player_data:
        return

    var player_id = local_player_data.get_player_id()
    var url = TradingConfig.get_api_base_url() + "/credits/" + player_id

    var error = http_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_GET)
    if error != OK:
        print("[TradingMarketplace] Failed to sync credits: %s" % str(error))

func _handle_credits_sync_response(data: Dictionary):
    """Handle credit synchronization response"""
    if data.has("credits"):
        var server_credits = data.get("credits", 0)
        var local_credits = local_player_data.get_credits()

        if server_credits != local_credits:
            print("[TradingMarketplace] Credit sync: Local %d -> Server %d" % [local_credits, server_credits])
            local_player_data.set_credits(server_credits)
            emit_signal("credits_synchronized", server_credits, local_credits)
```

**Infrastructure Changes:**
- Periodic credit synchronization (every 5 minutes)
- Credit discrepancy detection and resolution
- Audit logging for credit changes

---

### **Phase 4: UI/UX Enhancements**
*Priority: MEDIUM - Improves user experience*
*Estimated Time: 2-3 days*
*Dependencies: Phase 1, 2, 3 complete*

Enhance the user interface for better marketplace experience.

#### **Phase 4.1: Enhanced Marketplace UI States**

**Problem:** Poor visual feedback during marketplace operations.

**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Enhanced UI state management
- `scenes/zones/LobbyZone2D.tscn` - Add loading indicators
- `resources/themes/SpaceHologramTheme.tres` - Add new UI styles

**Changes Required:**

```gdscript
# LobbyZone2D.gd additions
enum MarketplaceUIState {
    INITIALIZING,
    LOADING_LISTINGS,
    READY,
    PURCHASING,
    POSTING_ITEM,
    REMOVING_LISTING,
    ERROR,
    OFFLINE
}

var current_ui_state: MarketplaceUIState = MarketplaceUIState.INITIALIZING
var loading_spinner: Control
var marketplace_status_panel: Panel

func _update_marketplace_ui_state(new_state: MarketplaceUIState, message: String = ""):
    """Update marketplace UI based on current state"""
    var old_state = current_ui_state
    current_ui_state = new_state

    match new_state:
        MarketplaceUIState.LOADING_LISTINGS:
            _show_loading_spinner(true, "Loading marketplace...")
            _disable_marketplace_buttons(true)
            _update_marketplace_status("Loading listings...", Color.WHITE)

        MarketplaceUIState.PURCHASING:
            _show_loading_spinner(true, "Processing purchase...")
            _disable_marketplace_buttons(true)
            _update_marketplace_status("Processing purchase...", Color.YELLOW)

        MarketplaceUIState.READY:
            _show_loading_spinner(false)
            _disable_marketplace_buttons(false)
            _update_marketplace_status("Marketplace ready - %d listings" % get_current_listing_count(), Color.GREEN)

        MarketplaceUIState.ERROR:
            _show_loading_spinner(false)
            _disable_marketplace_buttons(false)
            _update_marketplace_status("Error: %s" % message, Color.RED)
            _show_error_recovery_options()

        MarketplaceUIState.OFFLINE:
            _show_loading_spinner(false)
            _disable_marketplace_buttons(true)
            _update_marketplace_status("Marketplace offline - Check connection", Color.ORANGE)
            _show_offline_mode_options()

    print("[LobbyZone2D] UI State: %s -> %s" % [_ui_state_to_string(old_state), _ui_state_to_string(new_state)])

func _show_loading_spinner(visible: bool, message: String = ""):
    """Show/hide loading spinner with optional message"""
    if loading_spinner:
        loading_spinner.visible = visible
        if visible and message != "":
            _update_loading_message(message)

func _disable_marketplace_buttons(disabled: bool):
    """Enable/disable marketplace interaction buttons"""
    var buttons_to_control = [
        refresh_listings_button,
        sell_item_button,
        # Purchase buttons handled per-listing
    ]

    for button in buttons_to_control:
        if button:
            button.disabled = disabled

    # Handle buy buttons on listings
    _update_listing_buy_buttons(disabled)
```

**Infrastructure Changes:**
- Loading indicators for all operations
- State-based button management
- Visual feedback for all user actions

#### **Phase 4.2: Real-time Status Updates & Progress Tracking**

**Problem:** Users don't know the status of their operations.

**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Add progress tracking
- `scripts/TradingMarketplace.gd` - Add operation progress signals

**Changes Required:**

```gdscript
# TradingMarketplace.gd additions
signal operation_progress(operation_type: String, progress: float, message: String)

func _report_progress(operation: String, progress: float, message: String):
    """Report operation progress to UI"""
    print("[TradingMarketplace] %s: %.1f%% - %s" % [operation, progress * 100, message])
    emit_signal("operation_progress", operation, progress, message)

# Example in purchase_item function:
func purchase_item(listing_id: String, seller_id: String, item_name: String, quantity: int, total_price: int):
    _report_progress("purchase", 0.1, "Validating purchase...")
    # validation code...

    _report_progress("purchase", 0.3, "Holding credits...")
    # credit hold code...

    _report_progress("purchase", 0.5, "Sending purchase request...")
    # API request code...

    _report_progress("purchase", 0.8, "Processing response...")
    # response handling...

    _report_progress("purchase", 1.0, "Purchase complete!")
```

**Infrastructure Changes:**
- Progress bars for long operations
- Step-by-step feedback for users
- Operation timing and performance metrics

#### **Phase 4.3: Enhanced Error Messages & Recovery Options**

**Problem:** Generic error messages don't help users understand issues.

**Files to Modify:**
- `scripts/LobbyZone2D.gd` - Enhanced error handling
- `scripts/TradingMarketplace.gd` - Detailed error categorization

**Changes Required:**

```gdscript
# LobbyZone2D.gd additions
func _show_detailed_error(error_type: String, error_message: String, error_code: int = 0):
    """Show detailed error with recovery options"""
    var user_friendly_message = _translate_error_to_user_message(error_type, error_message, error_code)
    var recovery_options = _get_recovery_options(error_type)

    _display_error_dialog(user_friendly_message, recovery_options)

func _translate_error_to_user_message(error_type: String, error_message: String, error_code: int) -> String:
    """Convert technical errors to user-friendly messages"""
    match error_type:
        "network_timeout":
            return "Connection timed out. The marketplace servers may be busy. Please try again in a moment."
        "insufficient_credits":
            return "You don't have enough credits for this purchase. You need %d more credits." % _extract_credit_difference(error_message)
        "item_already_sold":
            return "This item was just purchased by another player. Please refresh the marketplace to see current listings."
        "api_configuration":
            return "Marketplace configuration error. Please contact support if this persists."
        _:
            return "An unexpected error occurred: %s" % error_message

func _get_recovery_options(error_type: String) -> Array:
    """Get available recovery options for error type"""
    match error_type:
        "network_timeout":
            return ["retry", "refresh_listings", "check_connection"]
        "insufficient_credits":
            return ["sell_items", "view_credits", "cancel"]
        "item_already_sold":
            return ["refresh_listings", "browse_similar", "cancel"]
        _:
            return ["retry", "cancel"]
```

**Infrastructure Changes:**
- Comprehensive error categorization system
- User-friendly error translation
- Automated recovery option suggestions

---

### **Phase 5: Monitoring, Testing & Validation**
*Priority: LOW - Quality assurance*
*Estimated Time: 2-3 days*
*Dependencies: Phase 1, 2, 3, 4 complete*

Implement comprehensive testing and monitoring systems.

#### **Phase 5.1: Comprehensive Testing Framework**

**Files to Create:**
- `scripts/testing/MarketplaceTester.gd` - Automated testing system
- `scripts/testing/TestScenarios.gd` - Test scenario definitions
- `_docs/marketplace_testing_guide.md` - Manual testing procedures

**Changes Required:**

```gdscript
# scripts/testing/MarketplaceTester.gd
class_name MarketplaceTester
extends Node

signal test_completed(test_name: String, passed: bool, details: Dictionary)
signal test_suite_completed(results: Dictionary)

var test_results: Dictionary = {}

func run_full_marketplace_test_suite():
    """Run complete marketplace testing suite"""
    print("=== MARKETPLACE TEST SUITE START ===")

    # Test buyer flow
    await test_complete_buyer_flow()
    await test_buyer_error_scenarios()

    # Test seller flow  
    await test_complete_seller_flow()
    await test_seller_notifications()

    # Test system robustness
    await test_concurrent_operations()
    await test_network_failures()

    # Test UI responsiveness
    await test_ui_state_management()

    print("=== MARKETPLACE TEST SUITE COMPLETE ===")
    emit_signal("test_suite_completed", test_results)

func test_complete_buyer_flow():
    """Test complete buyer purchase flow"""
    var test_name = "buyer_complete_flow"
    print("Testing: %s" % test_name)

    try:
        # Setup test data
        var initial_credits = LocalPlayerData.get_credits()
        var initial_inventory_size = LocalPlayerData.get_inventory().size()

        # Simulate purchase
        var mock_listing = _create_mock_listing()
        var purchase_success = await _simulate_purchase(mock_listing)

        # Validate results
        var final_credits = LocalPlayerData.get_credits()
        var final_inventory_size = LocalPlayerData.get_inventory().size()

        var expected_credits = initial_credits - mock_listing.total_price
        var expected_inventory_size = initial_inventory_size + 1

        var test_passed = (
            purchase_success and
            final_credits == expected_credits and
            final_inventory_size == expected_inventory_size
        )

        test_results[test_name] = {
            "passed": test_passed,
            "details": {
                "credits_correct": final_credits == expected_credits,
                "inventory_updated": final_inventory_size == expected_inventory_size,
                "purchase_successful": purchase_success
            }
        }

        emit_signal("test_completed", test_name, test_passed, test_results[test_name])

    except Exception as e:
        test_results[test_name] = {
            "passed": false,
            "error": str(e)
        }
        emit_signal("test_completed", test_name, false, test_results[test_name])
```

**Infrastructure Changes:**
- Automated test suite runner
- Mock data generation for testing
- Test result reporting and logging

#### **Phase 5.2: Performance Monitoring & Diagnostics**

**Files to Create:**
- `scripts/monitoring/MarketplaceDiagnostics.gd` - Performance monitoring
- `scripts/monitoring/MetricsCollector.gd` - Metrics collection system

**Changes Required:**

```gdscript
# scripts/monitoring/MarketplaceDiagnostics.gd
class_name MarketplaceDiagnostics
extends Node

var metrics_data: Dictionary = {}
var diagnostic_logs: Array[Dictionary] = []

func log_operation_start(operation_type: String, operation_data: Dictionary):
    """Log the start of a marketplace operation"""
    var operation_id = _generate_operation_id()
    var log_entry = {
        "operation_id": operation_id,
        "operation_type": operation_type,
        "start_time": Time.get_unix_time_from_system(),
        "data": operation_data,
        "status": "started"
    }

    diagnostic_logs.append(log_entry)
    print("[MarketplaceDiagnostics] Started: %s (%s)" % [operation_type, operation_id])

    return operation_id

func log_operation_complete(operation_id: String, success: bool, result_data: Dictionary = {}):
    """Log the completion of a marketplace operation"""
    var log_entry = _find_log_entry(operation_id)
    if log_entry:
        log_entry.end_time = Time.get_unix_time_from_system()
        log_entry.duration = log_entry.end_time - log_entry.start_time
        log_entry.success = success
        log_entry.result = result_data
        log_entry.status = "completed"

        _update_metrics(log_entry)

        print("[MarketplaceDiagnostics] Completed: %s in %.2fs (%s)" % [
            log_entry.operation_type,
            log_entry.duration,
            "SUCCESS" if success else "FAILED"
        ])

func _update_metrics(log_entry: Dictionary):
    """Update performance metrics"""
    var op_type = log_entry.operation_type

    if not metrics_data.has(op_type):
        metrics_data[op_type] = {
            "total_operations": 0,
            "successful_operations": 0,
            "total_duration": 0.0,
            "average_duration": 0.0,
            "success_rate": 0.0
        }

    var metrics = metrics_data[op_type]
    metrics.total_operations += 1
    metrics.total_duration += log_entry.duration

    if log_entry.success:
        metrics.successful_operations += 1

    metrics.average_duration = metrics.total_duration / metrics.total_operations
    metrics.success_rate = float(metrics.successful_operations) / float(metrics.total_operations)

func generate_performance_report() -> Dictionary:
    """Generate comprehensive performance report"""
    return {
        "timestamp": Time.get_datetime_string_from_system(),
        "metrics": metrics_data,
        "recent_operations": diagnostic_logs.slice(-10),  # Last 10 operations
        "system_health": _assess_system_health()
    }

func _assess_system_health() -> Dictionary:
    """Assess overall marketplace system health"""
    var total_ops = 0
    var total_success = 0
    var avg_duration = 0.0

    for op_type in metrics_data:
        var metrics = metrics_data[op_type]
        total_ops += metrics.total_operations
        total_success += metrics.successful_operations
        avg_duration += metrics.average_duration

    if total_ops > 0:
        avg_duration /= metrics_data.size()
        var overall_success_rate = float(total_success) / float(total_ops)

        return {
            "overall_success_rate": overall_success_rate,
            "average_operation_duration": avg_duration,
            "total_operations": total_ops,
            "health_status": _determine_health_status(overall_success_rate, avg_duration)
        }

    return {"health_status": "no_data"}

func _determine_health_status(success_rate: float, avg_duration: float) -> String:
    """Determine system health status based on metrics"""
    if success_rate >= 0.95 and avg_duration <= 2.0:
        return "excellent"
    elif success_rate >= 0.90 and avg_duration <= 5.0:
        return "good"
    elif success_rate >= 0.80 and avg_duration <= 10.0:
        return "fair"
    else:
        return "poor"
```

**Infrastructure Changes:**
- Real-time performance monitoring
- Health status assessment
- Automated alerting for system issues

---

## 📋 Implementation Checklist

### **Phase 1: Critical Buyer Fixes** ✅
- [ ] Implement HTTP request timeout management
- [ ] Add purchase state management system
- [ ] Enhance error recovery and credit rollback
- [ ] Verify and auto-recover signal connections
- [ ] Test basic purchase flow functionality

### **Phase 2: Backend Infrastructure** ✅
- [ ] Enhance AWS Lambda function for complete transactions
- [ ] Implement seller credit distribution system
- [ ] Add seller notification system
- [ ] Create new API endpoints for seller features
- [ ] Migrate existing data to new schema
- [ ] Deploy and test enhanced backend

### **Phase 3: Seller System** ✅
- [ ] Implement seller notification handling
- [ ] Create seller dashboard and trade history
- [ ] Add credit synchronization system
- [ ] Test complete seller flow
- [ ] Verify seller credit distribution

### **Phase 4: UI/UX Enhancements** ✅
- [ ] Enhanced marketplace UI states
- [ ] Real-time status updates and progress tracking
- [ ] Enhanced error messages and recovery options
- [ ] Test UI responsiveness and user experience

### **Phase 5: Monitoring & Testing** ✅
- [ ] Comprehensive testing framework
- [ ] Performance monitoring and diagnostics
- [ ] Create testing documentation
- [ ] Run full system validation

---

## 🚀 Deployment Strategy

### **Deployment Order:**
1. **Phase 1** - Deploy immediately for critical bug fixes
2. **Phase 2** - Deploy backend changes with data migration
3. **Phase 3** - Deploy seller features incrementally
4. **Phase 4** - Deploy UI improvements
5. **Phase 5** - Deploy monitoring and testing tools

### **Risk Mitigation:**
- Backup all existing data before Phase 2 deployment
- Deploy Phase 1 fixes independently to resolve current issues
- Use feature flags for Phase 3 seller features
- Gradual rollout of Phase 4 UI changes
- Monitor system health during each phase deployment

### **Success Metrics:**
- Purchase completion rate > 95%
- Average purchase time < 3 seconds
- Seller notification delivery rate > 98%
- UI state transition accuracy > 99%
- System uptime > 99.5%

---

This comprehensive plan addresses all identified issues and implements a complete two-sided marketplace system. Each phase builds on the previous ones, ensuring a stable and functional marketplace experience for both buyers and sellers.
