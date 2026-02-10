# ApexRun Backend API

High-performance Go backend for GPS ingestion, segment matching, and AI coaching.

## Prerequisites

- Go 1.22 or later
- PostgreSQL with PostGIS (provided by Supabase)
- Redis 7+ (local or cloud)
- Google Cloud account (for Gemini AI)

## Quick Start

### 1. Install Go

Download and install from https://go.dev/dl/

Verify installation:
```bash
go version
```

### 2. Install Dependencies

```bash
cd backend
go mod download
```

### 3. Configure Environment

```bash
cp .env.example .env
# Edit .env with your actual credentials
```

### 4. Run the Server

```bash
go run cmd/api/main.go
```

The server will start on `http://localhost:8080`

## Project Structure

```
backend/
├── cmd/
│   └── api/
│       └── main.go              # Application entry point
├── internal/
│   ├── auth/                    # JWT authentication & middleware
│   ├── activities/              # Activity recording logic
│   ├── segments/                # Segment matching worker
│   ├── database/                # Database connection pool
│   └── config/                  # Configuration loader
├── pkg/
│   ├── logger/                  # Structured logging (Zap)
│   └── utils/                   # GPS calculations, helpers
├── migrations/
│   └── 001_initial_schema.sql   # Database schema
├── go.mod                       # Go dependencies
└── .env                         # Environment variables (gitignored)
```

## API Endpoints

### Health Check
```
GET /health
```

### Activities
```
POST   /api/v1/activities        # Create new activity
GET    /api/v1/activities/:id    # Get activity details
GET    /api/v1/activities        # List user's activities
PUT    /api/v1/activities/:id    # Update activity
DELETE /api/v1/activities/:id    # Delete activity
```

### Segments
```
GET    /api/v1/segments                   # List all segments
GET    /api/v1/segments/:id               # Get segment details
GET    /api/v1/segments/:id/leaderboard   # Get segment leaderboard
POST   /api/v1/segments                   # Create new segment
```

### AI Coaching
```
GET    /api/v1/coaching/daily             # Get daily workout recommendation
POST   /api/v1/coaching/analyze           # Analyze training plan
```

## Database Setup

The database schema is defined in `migrations/001_initial_schema.sql`.

To apply migrations:
1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `migrations/001_initial_schema.sql`
4. Run the query

## Development

### Running Tests
```bash
go test ./...
```

### Building for Production
```bash
go build -o apexrun-api cmd/api/main.go
```

### Docker (Optional)
```bash
docker build -t apexrun-backend .
docker run -p 8080:8080 --env-file .env apexrun-backend
```

## Environment Variables

See `.env.example` for all configuration options.

Critical variables:
- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_JWT_SECRET` - JWT secret from Supabase settings
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` -Redis connection string

## Authentication

The backend validates Supabase JWT tokens. All protected routes require an `Authorization` header:

```
Authorization: Bearer <supabase_jwt_token>
```

## Performance

- **GPS Ingestion**: Handles 1000+ points per second
- **Segment Matching**: PostGIS spatial queries <50ms
- **Leaderboards**: Redis-cached, <10ms response time

## Monitoring

Logs are output in JSON format (configurable via `LOG_FORMAT` env var).

Health check endpoint returns database and Redis status:
```json
{
  "status": "ok",
  "database": "connected",
  "redis": "connected",
  "version": "1.0.0"
}
```

## Deployment

Deploy to:
- **Google Cloud Run** (recommended)
- **AWS ECS/Fargate**
- **Railway/Render**
- **Heroku**

Ensure environment variables are configured in your deployment platform.
