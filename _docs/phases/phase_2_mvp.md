# Phase 2: MVP (Minimal Viable Product) - Enhanced with Cloud Infrastructure & Authentication

## Scope
Deliver a playable, networked game with the core gameplay loop: explore, collect, trade, upgrade. The enhanced MVP includes production-ready cloud database infrastructure (AWS RDS) and user authentication systems, making it suitable for internet-scale multiplayer deployment.

## Enhanced Deliverables
- Trading lobby system for player-to-player exchanges (room-based multiplayer)
- Player can navigate, collect trash, and see inventory (single-player zones)
- Trading at NPC hub for credits
- Player-to-player trading of upgrades and debris
- Simple upgrade system (speed, capacity, zone access)
- Static AI text messages at milestones
- **NEW**: AWS RDS PostgreSQL cloud database integration
- **NEW**: JWT-based user authentication and registration
- **NEW**: Secure API endpoints with authentication middleware
- **NEW**: Environment-based configuration management
- Persistent player state (credits, inventory, upgrades)
- Minimal UI (HUD, inventory, trading, upgrade screens)

---

## Enhanced Features & Actionable Steps

### 1. Trading Lobby System
- [ ] Implement multiplayer trading lobbies (room-based, not real-time zones)
- [ ] Create lobby creation/joining system with room codes
- [ ] Add player-to-player trading interface for upgrades and debris
- [ ] Handle trading session state and transaction validation
- [ ] Add basic logging for trading events
- [ ] **NEW**: Integrate authentication tokens with trading sessions

### 2. Player Navigation & Trash Collection
- [x] Implement player movement controls (2D/2.5D)
- [x] Spawn collectible trash objects in the zone
- [x] Add collection mechanic (minigame, skill-check, or auto)
- [x] Update inventory on collection
- [x] Provide visual/audio feedback for collection

### 3. Inventory & Trading
- [x] Implement inventory system (client + server sync)
- [x] Add NPC hub scene for trading
- [x] Allow selling trash for credits
- [x] Update credits and clear inventory on sale
- [x] Log all trade actions

### 4. Upgrades & Progression
- [x] Implement upgrade system (speed, capacity, zone access)
- [x] Deduct credits and apply upgrade effects
- [x] Unlock deeper zone access with upgrades
- [x] Track progression state per player
- [x] Log upgrade purchases
- [ ] **Implement upgrade purchase UI at trading hubs** ⚠️ *See: `_docs/trading_hub_upgrade_system_implementation_plan.md`*

### 5. AI Messaging (Static)
- [ ] Trigger static AI text messages at key milestones (first upgrade, sale, new zone)
- [ ] Display messages via UI overlay
- [ ] Log all AI message triggers

### 6. Minimal UI
- [ ] Implement HUD (inventory, credits, upgrade status)
- [ ] Add inventory and trading screens
- [ ] Add upgrade selection UI
- [ ] Display AI messages in overlay
- [ ] **NEW**: Add user registration/login screens
- [ ] **NEW**: Add authentication status indicators
- [ ] Ensure all UI is functional and clear

### 7. **NEW**: Cloud Database Infrastructure (AWS RDS) - Phase 2A
#### Dependencies: Must complete before authentication implementation
- [ ] **Set up AWS RDS PostgreSQL instance with Multi-AZ**
  - Instance class: db.t3.micro (development), db.t3.small (production)
  - Storage: 20GB GP2 with auto-scaling enabled
  - Backup retention: 7 days
  - Enhanced monitoring enabled
- [ ] **Configure VPC security groups and network access**
  - Private subnet configuration
  - Security group rules for application access
  - SSL/TLS certificate configuration
- [ ] **Update database connection management**
  - Modify `backend/app.py` connection string handling
  - Add connection pooling with SQLAlchemy
  - Implement connection retry logic with exponential backoff
- [ ] **Environment variable management**
  - Create `backend/.env.production` template
  - Update `backend/app.py` to use environment-specific configs
  - Document RDS connection string format
- [ ] **Database migration strategy**
  - Set up Alembic migration framework
  - Create initial migration from existing schema
  - Test migration rollback procedures
- [ ] **Monitoring and logging setup**
  - CloudWatch integration for RDS metrics
  - Query performance monitoring
  - Connection pool monitoring

**Files to Modify:**
- `backend/app.py`: Database connection management
- `backend/requirements.txt`: Add SQLAlchemy connection pooling
- `data/postgres/schema.sql`: Ensure RDS compatibility
- `backend/.env.example`: Environment variable documentation
- `documentation/core_concept/tech_stack.md`: Update database section

### 8. **NEW**: Authentication System Implementation - Phase 2B
#### Dependencies: Requires AWS RDS setup (Phase 2A) to be complete
- [ ] **User registration and authentication endpoints**
  - `/api/v1/auth/register` - User registration with email validation
  - `/api/v1/auth/login` - JWT token authentication
  - `/api/v1/auth/refresh` - Token refresh mechanism
  - `/api/v1/auth/logout` - Token invalidation
- [ ] **Password security implementation**
  - bcrypt password hashing with salt
  - Password strength validation
  - Rate limiting for login attempts
- [ ] **JWT token management**
  - Access token (15 minutes) and refresh token (7 days)
  - Token blacklisting for logout
  - Secure token storage on client side
- [ ] **Database schema updates for authentication**
  - Add `users` table with email, hashed_password, created_at
  - Add `user_sessions` table for token management
  - Update `players` table to reference `users.id`
  - Add foreign key constraints and indexes
- [ ] **API endpoint security middleware**
  - JWT token validation middleware
  - Protected route decorators
  - User permission checking
- [ ] **Client-side authentication integration**
  - Update `scripts/APIClient.gd` with authentication methods
  - Add JWT token storage and automatic refresh
  - Update all API calls to include authentication headers

**Files to Create:**
- `backend/auth.py`: Authentication logic and JWT handling
- `backend/models.py`: SQLAlchemy models for users and sessions
- `backend/middleware.py`: Authentication middleware
- `data/postgres/migrations/`: Alembic migration files
- `scenes/ui/LoginScreen.tscn`: User login interface
- `scenes/ui/RegisterScreen.tscn`: User registration interface
- `scripts/AuthManager.gd`: Client-side authentication manager

**Files to Modify:**
- `backend/app.py`: Add authentication routes and middleware
- `backend/requirements.txt`: Already includes auth dependencies
- `scripts/APIClient.gd`: Add authentication methods
- `data/postgres/schema.sql`: Add authentication tables
- `scripts/ZoneMain3D.gd`: Integrate authentication flow

### 9. **NEW**: Security Hardening - Phase 2C
#### Dependencies: Requires authentication system (Phase 2B) to be complete
- [ ] **API security enhancements**
  - Rate limiting with Redis backend
  - CORS configuration for production
  - Input validation and sanitization
  - SQL injection prevention
- [ ] **Environment variable security**
  - Secure secret management (AWS Secrets Manager integration)
  - Environment variable validation
  - Development vs production configuration separation
- [ ] **Database security**
  - Enable RDS encryption at rest
  - SSL/TLS enforcement for connections
  - Database user privilege restriction
- [ ] **Monitoring and alerting**
  - Failed authentication attempt monitoring
  - Database connection monitoring
  - Performance metrics collection

**Files to Create:**
- `backend/security.py`: Security utilities and middleware
- `backend/config.py`: Configuration management
- `.env.production.example`: Production environment template

**Files to Modify:**
- `backend/app.py`: Add security middleware
- `.gitleaks.toml`: Update secret detection rules
- `documentation/security/`: Add production security guidelines

### 10. Persistence (Enhanced)
- [x] Save player state (credits, inventory, upgrades, zone access) server-side
- [x] Restore state on reconnect
- [x] Add error handling/logging for persistence
- [ ] **NEW**: User account persistence across sessions
- [ ] **NEW**: Cross-device player state synchronization
- [ ] **NEW**: Database transaction integrity for critical operations

---

## Completion Criteria (Enhanced)
- Players can create accounts and authenticate securely
- Players can navigate single-player zones, collect trash, and manage inventory
- Players can join trading lobbies to exchange upgrades and debris with other players
- Players can trade with NPCs for credits and purchase upgrades
- All core systems are networked and persistent
- Player data is stored securely in AWS RDS
- Authentication tokens protect all sensitive operations
- Minimal UI is present and functional
- Static AI messages trigger at milestones
- Production-ready database infrastructure is operational
- Logs confirm all major actions and security events

## ✅ Completed Systems (75% Complete)

### Backend Integration & API Communication
- **APIClient System**: Complete HTTP client for FastAPI backend communication
- **Backend Services**: Fully operational with comprehensive API endpoints
- **Error Handling**: Robust error management with fallback mechanisms
- **Virtual Environment**: Backend activation issues resolved

### Trading & Economy System
- **Credit Management**: Server-authoritative credit system with real-time sync
- **Transaction Processing**: Backend API integration for sell operations
- **Inventory Sync**: Real-time inventory updates with backend persistence
- **Trade Validation**: Server-side validation with client feedback

### Upgrade System Architecture
- **6 Upgrade Types**: Movement, Inventory, Collection, Exploration, Utility upgrades
- **Cost System**: Exponential cost scaling with purchase validation
- **Effect Application**: Real-time upgrade effects on player systems
- **Progression Tracking**: Persistent upgrade states with backend sync
- **⚠️ Missing**: Player UI for purchasing upgrades (backend logic complete, needs trading hub integration)

### Player & Zone Management
- **PlayerShip**: Enhanced movement, debris collection, inventory management
- **ZoneMain**: Improved zone coordination and system integration
- **Debris Collection**: Functional collection mechanics with backend sync
- **Movement Controls**: WASD movement with upgrade effect application

### Data Persistence
- **Backend Storage**: Credits, inventory, and upgrade state persistence
- **State Synchronization**: Client-server state consistency
- **Error Recovery**: Graceful handling of network failures
- **Logging**: Comprehensive logging throughout all systems

## 🔄 Enhanced Remaining Work (25% Remaining + New Infrastructure)

### **Priority 1: Cloud Infrastructure (Phase 2A)**
- AWS RDS PostgreSQL setup with Multi-AZ configuration
- Connection pooling and production database management
- Environment variable management and security
- Database migration framework implementation

### **Priority 2: Authentication System (Phase 2B)**
- User registration and login system implementation
- JWT token management and security middleware
- Client-side authentication integration
- Database schema updates for user management

### **Priority 3: Security Hardening (Phase 2C)**
- API security enhancements and rate limiting
- Environment variable security and secret management
- Production security monitoring and alerting

### **Priority 4: Original MVP Features**
- Trading lobby system with room-based multiplayer
- Visual inventory management interface
- Upgrade selection and purchasing UI
- HUD elements for credits and inventory status
- Player-to-player trading interface improvements
- AI integration and milestone trigger system

## **Architecture Considerations for Enhanced MVP**

### **Database Architecture**
```
Development: Local PostgreSQL → AWS RDS (Single-AZ)
Production: AWS RDS Multi-AZ → Read Replicas → CloudWatch Monitoring
```

### **Authentication Flow**
```
Client → Registration/Login → JWT Tokens → Protected API Endpoints → RDS Storage
```

### **Security Layers**
```
1. Input Validation (Pydantic models)
2. Authentication Middleware (JWT verification)
3. Rate Limiting (Redis-backed)
4. Database Security (SSL, encryption)
5. Environment Security (AWS Secrets Manager)
```

### **Required Environment Variables**
```bash
# Database Configuration
DB_HOST=your-rds-endpoint.region.rds.amazonaws.com
DB_NAME=children_of_singularity
DB_USER=app_user
DB_PASSWORD=secure_password_from_secrets_manager
DB_PORT=5432

# Authentication
JWT_SECRET_KEY=your-jwt-secret-key
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=15
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# Security
API_RATE_LIMIT_PER_MINUTE=100
CORS_ORIGINS=["https://yourdomain.com"]
ENVIRONMENT=production
```

### **File Impact Analysis**

**Critical Files Requiring Updates:**
- `backend/app.py`: Core API with authentication and RDS integration
- `scripts/APIClient.gd`: Client authentication and secure API calls
- `data/postgres/schema.sql`: Enhanced schema with authentication tables
- `backend/requirements.txt`: Already includes necessary dependencies

**New Files to Create:**
- `backend/auth.py`: Authentication logic (≈200 lines)
- `backend/models.py`: SQLAlchemy models (≈150 lines)
- `backend/config.py`: Configuration management (≈100 lines)
- `scripts/AuthManager.gd`: Client auth manager (≈250 lines)
- `scenes/ui/LoginScreen.tscn`: Login interface
- `scenes/ui/RegisterScreen.tscn`: Registration interface

**Infrastructure Files:**
- `.env.production.example`: Production environment template
- `backend/migrations/`: Alembic migration files
- `documentation/deployment/aws_setup.md`: RDS deployment guide

### **Estimated Development Timeline**
- **Phase 2A (Cloud Infrastructure)**: 1-2 weeks
- **Phase 2B (Authentication)**: 2-3 weeks  
- **Phase 2C (Security Hardening)**: 1 week
- **Original MVP Features**: 2-3 weeks
- **Total Enhanced MVP**: 6-9 weeks

This enhanced Phase 2 plan transforms the MVP from a local development prototype into a production-ready, internet-scale multiplayer game with enterprise-grade security and cloud infrastructure.
