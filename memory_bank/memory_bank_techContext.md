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
pydantic==2.5.0
python-multipart==0.0.6
```

## Development Tools
- **Version Control**: Git
- **IDE**: Cursor (VS Code-based)
- **Database Tools**: PostgreSQL CLI tools
- **Asset Pipeline**: Godot's built-in importer

## Configuration Files
- `project.godot`: Godot project configuration
- `backend/requirements.txt`: Python dependencies
- `data/postgres/schema.sql`: Database schema
- `.gitignore`: Version control exclusions

## Build & Deployment
- **Development**: Godot editor for client, uvicorn for backend
- **Production**: Godot export templates, Docker containers (planned)
- **CI/CD**: GitHub Actions (planned)

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