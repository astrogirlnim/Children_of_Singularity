-- schema.sql
-- Database schema for Children of the Singularity
-- PostgreSQL database structure for player persistence, inventory, and progression

-- Enable UUID extension for generating unique IDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Players table - stores core player information
CREATE TABLE IF NOT EXISTS players (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    credits INTEGER NOT NULL DEFAULT 0,
    progression_path VARCHAR(50) NOT NULL DEFAULT 'rogue',
    position_x FLOAT NOT NULL DEFAULT 0.0,
    position_y FLOAT NOT NULL DEFAULT 0.0,
    position_z FLOAT NOT NULL DEFAULT 0.0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Inventory table - stores player items
CREATE TABLE IF NOT EXISTS inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    item_id VARCHAR(255) NOT NULL,
    item_type VARCHAR(100) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    value INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Upgrades table - stores player upgrades and progression
CREATE TABLE IF NOT EXISTS upgrades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    upgrade_type VARCHAR(100) NOT NULL,
    level INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(player_id, upgrade_type)
);

-- Zones table - stores zone access and progression
CREATE TABLE IF NOT EXISTS zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id VARCHAR(255) NOT NULL,
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    access_level INTEGER NOT NULL DEFAULT 1,
    last_visited TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(player_id, zone_id)
);

-- Game sessions table - track player sessions for analytics
CREATE TABLE IF NOT EXISTS game_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    session_start TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    session_end TIMESTAMP WITH TIME ZONE,
    zone_id VARCHAR(255),
    actions_performed INTEGER DEFAULT 0,
    debris_collected INTEGER DEFAULT 0,
    credits_earned INTEGER DEFAULT 0
);

-- AI interactions table - track AI communications and milestones
CREATE TABLE IF NOT EXISTS ai_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
    interaction_type VARCHAR(100) NOT NULL,
    message_content TEXT,
    milestone_reached VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_players_name ON players(name);
CREATE INDEX IF NOT EXISTS idx_players_progression ON players(progression_path);
CREATE INDEX IF NOT EXISTS idx_inventory_player ON inventory(player_id);
CREATE INDEX IF NOT EXISTS idx_inventory_type ON inventory(item_type);
CREATE INDEX IF NOT EXISTS idx_upgrades_player ON upgrades(player_id);
CREATE INDEX IF NOT EXISTS idx_zones_player ON zones(player_id);
CREATE INDEX IF NOT EXISTS idx_zones_zone_id ON zones(zone_id);
CREATE INDEX IF NOT EXISTS idx_sessions_player ON game_sessions(player_id);
CREATE INDEX IF NOT EXISTS idx_ai_interactions_player ON ai_interactions(player_id);

-- Create a function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at timestamps
-- Drop existing triggers first to prevent "already exists" errors
DROP TRIGGER IF EXISTS update_players_updated_at ON players;
DROP TRIGGER IF EXISTS update_inventory_updated_at ON inventory;
DROP TRIGGER IF EXISTS update_upgrades_updated_at ON upgrades;
DROP TRIGGER IF EXISTS update_zones_updated_at ON zones;

CREATE TRIGGER update_players_updated_at BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_inventory_updated_at BEFORE UPDATE ON inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_upgrades_updated_at BEFORE UPDATE ON upgrades
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_zones_updated_at BEFORE UPDATE ON zones
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default upgrade types for new players
INSERT INTO upgrades (player_id, upgrade_type, level)
SELECT p.id, 'speed_boost', 0 FROM players p
WHERE NOT EXISTS (SELECT 1 FROM upgrades u WHERE u.player_id = p.id AND u.upgrade_type = 'speed_boost');

INSERT INTO upgrades (player_id, upgrade_type, level)
SELECT p.id, 'inventory_expansion', 0 FROM players p
WHERE NOT EXISTS (SELECT 1 FROM upgrades u WHERE u.player_id = p.id AND u.upgrade_type = 'inventory_expansion');

INSERT INTO upgrades (player_id, upgrade_type, level)
SELECT p.id, 'collection_efficiency', 0 FROM players p
WHERE NOT EXISTS (SELECT 1 FROM upgrades u WHERE u.player_id = p.id AND u.upgrade_type = 'collection_efficiency');

INSERT INTO upgrades (player_id, upgrade_type, level)
SELECT p.id, 'cargo_magnet', 0 FROM players p
WHERE NOT EXISTS (SELECT 1 FROM upgrades u WHERE u.player_id = p.id AND u.upgrade_type = 'cargo_magnet');

-- Create a function to initialize default upgrades for new players
CREATE OR REPLACE FUNCTION initialize_player_upgrades()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO upgrades (player_id, upgrade_type, level) VALUES
        (NEW.id, 'speed_boost', 0),
        (NEW.id, 'inventory_expansion', 0),
        (NEW.id, 'collection_efficiency', 0),
        (NEW.id, 'cargo_magnet', 0);
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to initialize upgrades when a new player is created
-- Drop existing trigger first to prevent "already exists" errors
DROP TRIGGER IF EXISTS initialize_new_player_upgrades ON players;

CREATE TRIGGER initialize_new_player_upgrades AFTER INSERT ON players
    FOR EACH ROW EXECUTE FUNCTION initialize_player_upgrades();

-- Create some sample data for testing
INSERT INTO players (id, name, credits, progression_path, position_x, position_y, position_z)
VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 'Test Salvager', 100, 'rogue', 0.0, 0.0, 0.0),
    ('550e8400-e29b-41d4-a716-446655440001', 'Corporate Drone', 250, 'corporate', 100.0, 50.0, 0.0),
    ('550e8400-e29b-41d4-a716-446655440002', 'AI Hybrid', 500, 'ai_integration', -50.0, -75.0, 0.0)
ON CONFLICT (id) DO NOTHING;

-- Insert sample zones
INSERT INTO zones (zone_id, player_id, access_level) VALUES
    ('zone_alpha_01', '550e8400-e29b-41d4-a716-446655440000', 1),
    ('zone_alpha_01', '550e8400-e29b-41d4-a716-446655440001', 1),
    ('zone_alpha_01', '550e8400-e29b-41d4-a716-446655440002', 1),
    ('zone_beta_01', '550e8400-e29b-41d4-a716-446655440002', 2)
ON CONFLICT (player_id, zone_id) DO NOTHING;

-- Insert sample inventory items
INSERT INTO inventory (player_id, item_id, item_type, quantity, value) VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 'scrap_001', 'scrap_metal', 5, 25),
    ('550e8400-e29b-41d4-a716-446655440000', 'satellite_001', 'broken_satellite', 1, 150),
    ('550e8400-e29b-41d4-a716-446655440001', 'bio_waste_001', 'bio_waste', 3, 75),
    ('550e8400-e29b-41d4-a716-446655440002', 'ai_core_001', 'ai_component', 1, 500)
ON CONFLICT (id) DO NOTHING;

-- Create a view for easy player data retrieval
CREATE OR REPLACE VIEW player_summary AS
SELECT
    p.id,
    p.name,
    p.credits,
    p.progression_path,
    p.position_x,
    p.position_y,
    p.position_z,
    p.created_at,
    p.last_login,
    COUNT(DISTINCT i.id) as inventory_count,
    COUNT(DISTINCT z.id) as zones_accessible,
    AVG(u.level) as avg_upgrade_level
FROM players p
LEFT JOIN inventory i ON p.id = i.player_id
LEFT JOIN zones z ON p.id = z.player_id
LEFT JOIN upgrades u ON p.id = u.player_id
GROUP BY p.id, p.name, p.credits, p.progression_path, p.position_x, p.position_y, p.position_z, p.created_at, p.last_login;

-- Log schema creation
INSERT INTO ai_interactions (player_id, interaction_type, message_content, milestone_reached) VALUES
    ('550e8400-e29b-41d4-a716-446655440000', 'system', 'Database schema initialized', 'schema_created');

-- Add comments to document the schema
COMMENT ON TABLE players IS 'Core player information and current state';
COMMENT ON TABLE inventory IS 'Player inventory items with quantities and values';
COMMENT ON TABLE upgrades IS 'Player upgrades and progression levels';
COMMENT ON TABLE zones IS 'Zone access permissions and visit history';
COMMENT ON TABLE game_sessions IS 'Player session tracking for analytics';
COMMENT ON TABLE ai_interactions IS 'AI communication logs and milestone tracking';
COMMENT ON VIEW player_summary IS 'Consolidated player data for quick queries';
