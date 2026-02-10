1\. System Overview \& Tech Stack

ApexRun is a performance-focused running platform.



Frontend: Flutter 3.19+ (Impeller Engine) using Riverpod for state management.



Backend: Supabase (Auth, Storage, Edge Functions)



Backend: Go 1.22+ (Gin Framework) for high-performance API and GPS ingestion.



Database: PostgreSQL 16+ with PostGIS (spatial) (Hosted on Supabase).



In-App Maps: Mapbox SDK.



Real-time/Cache: Redis 7+ (Streams for message queuing, Sorted Sets for leaderboards).



AI/ML: Google Gemini 1.5 Flash (LLM Coach) and MediaPipe (on-device pose estimation).



AI Engine: Gemini 1.5 Flash (via Supabase Edge Functions).



2\. Full Project Structure

Claude Code should initialize the project with this directory hierarchy:



apexrun/

├── backend/                  # Go service (cmd/api/main.go)

│   ├── internal/             # Domain logic, repos, services

│   ├── pkg/                  # Shared utilities (JWT, Logger)

│   └── migrations/           # SQL migration files

├── ml-service/               # Python FastAPI (custom ML models)

└── mobile/                   # Flutter application

&nbsp;   ├── lib/

&nbsp;   │   ├── data/             # Repositories \& Data sources

&nbsp;   │   ├── domain/           # Entities \& Use cases

&nbsp;   │   ├── presentation/     # Screens \& Providers

&nbsp;   │   └── ml/               # TFLite \& Pose detection logic



3\. Database Schema (The PostGIS Foundation)

To enable Strava-style segments and high-fidelity tracking, run this SQL in the Supabase SQL Editor:



-- Enable PostGIS for spatial operations

CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;



-- Activities Table: Stores the full GPS path

CREATE TABLE activities (

&nbsp;   id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&nbsp;   user\_id UUID REFERENCES auth.users(id),

&nbsp;   activity\_name TEXT,

&nbsp;   route\_path extensions.geography(LineString, 4326), -- The full run path

&nbsp;   distance\_meters FLOAT,

&nbsp;   start\_time TIMESTAMPTZ DEFAULT NOW()

);



-- Segments Table: Fixed paths for community competition

CREATE TABLE segments (

&nbsp;   id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

&nbsp;   name TEXT NOT NULL,

&nbsp;   segment\_path extensions.geography(LineString, 4326) NOT NULL

);



-- Spatial Index for performance

CREATE INDEX idx\_activities\_route ON activities USING GIST (route\_path);

CREATE INDEX idx\_segments\_path ON segments USING GIST (segment\_path);



4\. AI \& Machine Learning Specifications

A. Computer Vision (MediaPipe)

Form Analysis: Monitor 33 body landmarks.



Logic: Calculate Ground Contact Time and Vertical Oscillation on-device.



Feedback: Results are mapped to JSON and stored in activities.form\_analysis\_data.

B. Gemini 1.5 Flash (Adaptive Coaching)

Daily Recalibration: Every morning, fetch the user's HRV, Sleep, and last 7 days of activity\_streams.



Functionality: Adjust planned\_workouts (Easy Run, Intervals, etc.) dynamically based on fatigue.



Prompting: Gemini acts as a technical coach specializing in marathon physiology.



Background GPS Tracking

Plugin: flutter\_background\_geolocation.



Logic: Capture pings every 1–2 seconds. Store points in a local List<double> and convert to a WKT (Well-Known Text) LINESTRING before upserting to Supabase via POST.



Segment Matching Logic

Use this PostGIS query to check if an activity path matches a segment:



SELECT s.id, s.name

FROM segments s

WHERE extensions.ST\_DWithin(s.segment\_path, :activity\_path, 20) -- Path is within 20m buffer

&nbsp; AND extensions.ST\_CoveredBy(s.segment\_path, extensions.ST\_Buffer(:activity\_path, 15));



C. Gemini 1.5 Flash Coaching (Edge Function)

Create a Supabase Edge Function process-coaching that:



Receives current\_hrv and last\_7\_days\_load.



Calls the Gemini 1.5 Flash API with a system prompt: "You are an elite marathon coach. Adjust the user's training plan based on these recovery metrics."



Returns a JSON response to the Flutter app to update the dashboard.



5\. Critical Development Commands

Claude Code should follow these steps to maintain high GPS reliability:



Background Tracking: Use the flutter\_background\_geolocation plugin to survive the OS "Doze" mode.



Jank-Free Maps: Force Impeller rendering for Mapbox route overlays to maintain 120fps.



Privacy Shrouds: Implement a function to blur the route\_geom within 200m of the user's home\_location.



UI/UX \& Design Directives:

Design System: Follow the ApexRun Design System (Dark Mode #0A0A0A, Electric Lime #CCFF00).



Performance: All map interactions must maintain 120fps. Use MapboxMap with Impeller rendering.



Navigation: Persistent Bottom Nav (Home, Record, AI Coach, Leaderboard, Profile).





