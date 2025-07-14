# Technical Context

## Development Environment
- **OS**: macOS 24.5.0 (Darwin)
- **Shell**: /bin/zsh
- **Package Manager**: Homebrew 4.5.9
- **Godot Version**: 4.4.1.stable.official.49a5bc7b6

## Technology Stack

### Frontend (Game Client)
- **Engine**: Godot 4.4.1
- **Language**: GDScript with strict typing
- **Networking**: ENet (built into Godot)
- **Audio**: Godot's built-in audio system + external AI voice synthesis

### Backend Services
- **API Framework**: FastAPI (Python)
- **Database**: PostgreSQL
- **ORM**: SQLAlchemy
- **HTTP Client**: Python requests/httpx
- **Authentication**: JWT tokens (planned)

### Dependencies
```python
# backend/requirements.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
psycopg2-binary==2.9.9
pydantic==2.0.5
python-multipart==0.0.6
```

## Development Tools
- **Version Control**: Git
- **IDE**: Cursor (VS Code-based)
- **Database Tools**: PostgreSQL CLI tools
- **Asset Pipeline**: Godot's built-in importer

## Security Tools
- **Secret Scanning**: Gitleaks v8.27.2
- **Pre-commit Hooks**: Pre-commit framework v4.2.0
- **Code Quality**: Black, Flake8, various pre-commit hooks
- **CI/CD Security**: Integrated gitleaks in GitHub Actions

## Backend Configuration & Setup

### Virtual Environment Setup
- **Path**: `/backend/venv/`
- **Activation**: `source backend/venv/bin/activate`
- **Python**: Python 3.x with FastAPI and dependencies
- **Status**: ✅ Resolved - Virtual environment activation issue fixed

### Backend Service Details
- **Host**: `localhost`
- **Port**: `8000`
- **URL**: `http://localhost:8000`
- **Start Command**: `python -m uvicorn backend.app:app --reload --host 0.0.0.0 --port 8000`
- **Status**: ✅ Operational - Running with fallback mode

### API Endpoints Verified
- **Health Check**: `/api/v1/health` → `{"status":"healthy","database_status":"disconnected (using fallback)"}`
- **Statistics**: `/api/v1/stats` → `{"total_players":1,"total_inventory_items":0,"total_zones":0}`
- **Player Management**: `/api/v1/players/*` → Functional with stub data
- **Inventory Management**: `/api/v1/inventory/*` → Functional with stub data

## Configuration Files
- `project.godot`: Godot project configuration
- `backend/requirements.txt`: Python dependencies
- `data/postgres/schema.sql`: Database schema
- `.gitignore`: Version control exclusions
- `.gitleaks.toml`: Gitleaks secret detection configuration
- `.pre-commit-config.yaml`: Pre-commit hooks configuration

## Build & Deployment
- **Development**: Godot editor for client, uvicorn for backend
- **Production**: Godot export templates, Docker containers (planned)
- **CI/CD**: GitHub Actions with comprehensive quality checks including security scanning

## Phase 2 Technical Implementations

### HTTP Client Integration
- **APIClient**: `scripts/APIClient.gd` - Extends HTTPRequest
- **Signal-Based**: Async operations with signal callbacks
- **Error Handling**: Comprehensive network error management
- **Backend Integration**: Full API endpoint coverage

### Upgrade System Technology
- **Architecture**: Modular upgrade system with effect application
- **Data Structures**: Enums for upgrade types, dictionaries for configuration
- **Persistence**: Backend integration for upgrade state management
- **Performance**: Efficient upgrade effect application

### Trading System Integration
- **Real-Time Sync**: Credit synchronization between client and server
- **Transaction Validation**: Server-side validation with client feedback
- **Error Recovery**: Graceful handling of network failures
- **State Management**: Consistent state across client and server

## Key Technical Constraints
- Cross-platform compatibility (Windows, macOS, Linux)
- Real-time networking requirements
- Large-scale asset management
- AI voice synthesis integration
- Database performance for multiplayer sessions

## Performance Targets
- 60 FPS client rendering
- <100ms network latency for local multiplayer
- <500ms API response times
- Support for 10+ concurrent players per zone

## Development Workflow Improvements

### Backend Development
- **Virtual Environment**: Proper venv activation resolved
- **Testing**: API endpoints verified with curl commands
- **Logging**: Comprehensive logging throughout backend services
- **Error Handling**: Robust error handling with fallback mechanisms

### Frontend Development
- **Strict Typing**: All GDScript with type hints
- **Signal Architecture**: Event-driven programming throughout
- **Component Design**: Modular systems with clear separation of concerns
- **Testing**: Manual testing of all critical paths

### Integration Testing
- **API Testing**: All endpoints tested and verified
- **Client-Server**: APIClient integration tested thoroughly
- **System Integration**: Cross-system communication verified
- **Error Scenarios**: Network failure handling tested

## Technical Debt and Considerations

### Current Technical Debt
- **Database Connection**: PostgreSQL connection not implemented (using fallback)
- **ENet Implementation**: Still using stubs for multiplayer networking
- **UI Systems**: Visual interfaces not yet implemented
- **Performance Optimization**: Not yet optimized for large-scale deployment

### Future Technical Considerations
- **Database Migration**: Move from fallback to real PostgreSQL
- **Multiplayer Scaling**: Implement proper ENet networking
- **UI Framework**: Implement comprehensive UI systems
- **Performance Monitoring**: Add performance metrics and monitoring
- **Security Hardening**: Implement proper authentication and authorization
