-- trading_schema.sql
-- Minimal AWS RDS PostgreSQL schema for player-to-player trading marketplace
-- Children of the Singularity - Simplified Architecture

-- Enable UUID extension for generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Trade listings posted by players
CREATE TABLE IF NOT EXISTS trade_listings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    seller_id VARCHAR(255) NOT NULL,          -- Player identifier from local storage
    seller_name VARCHAR(255) NOT NULL,        -- Display name for UI
    item_type VARCHAR(100) NOT NULL,          -- "upgrade" or "debris"
    item_name VARCHAR(255) NOT NULL,          -- "speed_boost" or "broken_satellite"
    item_subtype VARCHAR(255),                -- For upgrades: level info, for debris: condition
    quantity INTEGER NOT NULL DEFAULT 1,
    asking_price INTEGER NOT NULL,
    description TEXT,
    listing_data JSONB,                       -- Additional item metadata
    listed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'active',      -- active, sold, expired, cancelled
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Trade transactions/completed trades
CREATE TABLE IF NOT EXISTS trade_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    listing_id UUID REFERENCES trade_listings(id) ON DELETE CASCADE,
    buyer_id VARCHAR(255) NOT NULL,           -- Player identifier
    buyer_name VARCHAR(255) NOT NULL,         -- Display name
    seller_id VARCHAR(255) NOT NULL,          -- Player identifier
    seller_name VARCHAR(255) NOT NULL,        -- Display name
    item_type VARCHAR(100) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    quantity INTEGER NOT NULL,
    final_price INTEGER NOT NULL,
    transaction_data JSONB,                   -- Additional transaction metadata
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Market price history for economic simulation
CREATE TABLE IF NOT EXISTS market_prices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    item_type VARCHAR(100) NOT NULL,
    item_name VARCHAR(255) NOT NULL,
    average_price DECIMAL(10,2) NOT NULL,
    min_price INTEGER NOT NULL,
    max_price INTEGER NOT NULL,
    total_volume INTEGER NOT NULL DEFAULT 0,
    price_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(item_type, item_name, price_date)
);

-- Player trading reputation (optional - for future features)
CREATE TABLE IF NOT EXISTS player_reputation (
    player_id VARCHAR(255) PRIMARY KEY,
    player_name VARCHAR(255) NOT NULL,
    total_trades_as_seller INTEGER DEFAULT 0,
    total_trades_as_buyer INTEGER DEFAULT 0,
    total_credits_traded BIGINT DEFAULT 0,
    reputation_score DECIMAL(3,2) DEFAULT 5.00,  -- 1.00 to 5.00 scale
    last_trade_date TIMESTAMP WITH TIME ZONE,
    first_trade_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_listings_status_date ON trade_listings(status, listed_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_seller ON trade_listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_listings_item_type ON trade_listings(item_type, item_name);
CREATE INDEX IF NOT EXISTS idx_listings_price ON trade_listings(asking_price);
CREATE INDEX IF NOT EXISTS idx_listings_expires ON trade_listings(expires_at) WHERE expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_buyer ON trade_transactions(buyer_id);
CREATE INDEX IF NOT EXISTS idx_transactions_seller ON trade_transactions(seller_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON trade_transactions(completed_at DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_item ON trade_transactions(item_type, item_name);

CREATE INDEX IF NOT EXISTS idx_prices_item_date ON market_prices(item_type, item_name, price_date DESC);

CREATE INDEX IF NOT EXISTS idx_reputation_score ON player_reputation(reputation_score DESC);

-- Create triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables that need auto-updating timestamps
CREATE TRIGGER update_trade_listings_updated_at BEFORE UPDATE ON trade_listings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_player_reputation_updated_at BEFORE UPDATE ON player_reputation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create a function to automatically expire old listings
CREATE OR REPLACE FUNCTION expire_old_listings()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE trade_listings
    SET status = 'expired', updated_at = CURRENT_TIMESTAMP
    WHERE status = 'active'
      AND expires_at IS NOT NULL
      AND expires_at < CURRENT_TIMESTAMP;

    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ language 'plpgsql';

-- Create a function to update market prices based on completed transactions
CREATE OR REPLACE FUNCTION update_market_prices(p_item_type VARCHAR, p_item_name VARCHAR)
RETURNS VOID AS $$
BEGIN
    INSERT INTO market_prices (item_type, item_name, average_price, min_price, max_price, total_volume, price_date)
    SELECT
        item_type,
        item_name,
        AVG(final_price)::DECIMAL(10,2),
        MIN(final_price),
        MAX(final_price),
        SUM(quantity),
        CURRENT_DATE
    FROM trade_transactions
    WHERE item_type = p_item_type
      AND item_name = p_item_name
      AND completed_at >= CURRENT_DATE
    GROUP BY item_type, item_name
    ON CONFLICT (item_type, item_name, price_date)
    DO UPDATE SET
        average_price = EXCLUDED.average_price,
        min_price = EXCLUDED.min_price,
        max_price = EXCLUDED.max_price,
        total_volume = EXCLUDED.total_volume;
END;
$$ language 'plpgsql';

-- Create a function to update player reputation after trades
CREATE OR REPLACE FUNCTION update_player_reputation_after_trade()
RETURNS TRIGGER AS $$
BEGIN
    -- Update seller reputation
    INSERT INTO player_reputation (player_id, player_name, total_trades_as_seller, total_credits_traded, last_trade_date)
    VALUES (NEW.seller_id, NEW.seller_name, 1, NEW.final_price, NEW.completed_at)
    ON CONFLICT (player_id) DO UPDATE SET
        player_name = EXCLUDED.player_name,
        total_trades_as_seller = player_reputation.total_trades_as_seller + 1,
        total_credits_traded = player_reputation.total_credits_traded + EXCLUDED.total_credits_traded,
        last_trade_date = EXCLUDED.last_trade_date,
        updated_at = CURRENT_TIMESTAMP;

    -- Update buyer reputation
    INSERT INTO player_reputation (player_id, player_name, total_trades_as_buyer, total_credits_traded, last_trade_date)
    VALUES (NEW.buyer_id, NEW.buyer_name, 1, NEW.final_price, NEW.completed_at)
    ON CONFLICT (player_id) DO UPDATE SET
        player_name = EXCLUDED.player_name,
        total_trades_as_buyer = player_reputation.total_trades_as_buyer + 1,
        total_credits_traded = player_reputation.total_credits_traded + EXCLUDED.total_credits_traded,
        last_trade_date = EXCLUDED.last_trade_date,
        updated_at = CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update reputation after completed trades
CREATE TRIGGER update_reputation_after_trade AFTER INSERT ON trade_transactions
    FOR EACH ROW EXECUTE FUNCTION update_player_reputation_after_trade();

-- Insert some sample upgrade types for reference (not required data)
INSERT INTO market_prices (item_type, item_name, average_price, min_price, max_price, total_volume) VALUES
    ('upgrade', 'speed_boost', 150.00, 100, 200, 0),
    ('upgrade', 'inventory_expansion', 300.00, 200, 400, 0),
    ('upgrade', 'collection_efficiency', 250.00, 150, 350, 0),
    ('upgrade', 'cargo_magnet', 500.00, 400, 600, 0),
    ('debris', 'scrap_metal', 10.00, 5, 20, 0),
    ('debris', 'bio_waste', 25.00, 15, 40, 0),
    ('debris', 'broken_satellite', 75.00, 50, 100, 0),
    ('debris', 'ai_component', 200.00, 150, 300, 0),
    ('debris', 'unknown_artifact', 400.00, 300, 500, 0)
ON CONFLICT (item_type, item_name, price_date) DO NOTHING;

-- Create a view for active listings with market context
CREATE OR REPLACE VIEW active_listings_with_market AS
SELECT
    tl.*,
    mp.average_price as market_average,
    mp.min_price as market_min,
    mp.max_price as market_max,
    CASE
        WHEN tl.asking_price <= mp.average_price * 0.8 THEN 'below_market'
        WHEN tl.asking_price >= mp.average_price * 1.2 THEN 'above_market'
        ELSE 'market_rate'
    END as price_category
FROM trade_listings tl
LEFT JOIN market_prices mp ON tl.item_type = mp.item_type
    AND tl.item_name = mp.item_name
    AND mp.price_date = CURRENT_DATE
WHERE tl.status = 'active'
    AND (tl.expires_at IS NULL OR tl.expires_at > CURRENT_TIMESTAMP)
ORDER BY tl.listed_at DESC;

-- Add comments to document the schema
COMMENT ON TABLE trade_listings IS 'Active and historical trade listings posted by players';
COMMENT ON TABLE trade_transactions IS 'Completed trade transactions for history and analytics';
COMMENT ON TABLE market_prices IS 'Daily market price data for economic simulation';
COMMENT ON TABLE player_reputation IS 'Player trading reputation and statistics';
COMMENT ON VIEW active_listings_with_market IS 'Active listings with market price context for buyers';

-- Log schema creation
INSERT INTO trade_transactions (listing_id, buyer_id, buyer_name, seller_id, seller_name, item_type, item_name, quantity, final_price, transaction_data)
VALUES (uuid_generate_v4(), 'system', 'System', 'system', 'System', 'system', 'schema_initialized', 1, 0, '{"schema_version": "1.0", "created_at": "' || CURRENT_TIMESTAMP || '"}');
