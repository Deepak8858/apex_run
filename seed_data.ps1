#!/usr/bin/env pwsh
# ApexRun Mock Data Seeder

$SUPABASE_URL = "https://voddddmmiarnbvwmgzgo.supabase.co"
$ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvZGRkZG1taWFybmJ2d21nemdvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2NTE3OTcsImV4cCI6MjA4NjIyNzc5N30.i7Ni-NHsmbwaXEoyOut_26PH1PK_Xycw3ChzkvPtklM"

function Login-User($email, $password) {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    $resp = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/token?grant_type=password" `
        -Method POST -ContentType "application/json" `
        -Headers @{ apikey = $ANON_KEY } -Body $body
    return @{ token = $resp.access_token; id = $resp.user.id }
}

function Signup-User($email, $password) {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    try {
        $resp = Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/signup" `
            -Method POST -ContentType "application/json" `
            -Headers @{ apikey = $ANON_KEY } -Body $body
        return @{ id = $resp.id; email = $resp.email }
    } catch {
        Write-Host "Signup error: $_"
        return $null
    }
}

function Invoke-SupabaseRest($token, $path, $body, $method = "POST", $prefer = "return=representation") {
    $headers = @{
        apikey = $ANON_KEY
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
        Prefer = $prefer
    }
    try {
        $resp = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/$path" `
            -Method $method -Headers $headers -Body ($body | ConvertTo-Json -Depth 10)
        return $resp
    } catch {
        Write-Host "REST error on $path : $($_.Exception.Message)"
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host $reader.ReadToEnd()
        return $null
    }
}

function Invoke-SupabaseRPC($token, $funcName, $params) {
    $headers = @{
        apikey = $ANON_KEY
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    }
    try {
        $resp = Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/rpc/$funcName" `
            -Method POST -Headers $headers -Body ($params | ConvertTo-Json -Depth 10)
        return $resp
    } catch {
        Write-Host "RPC error on $funcName : $($_.Exception.Message)"
        $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        Write-Host $reader.ReadToEnd()
        return $null
    }
}

# ============ Step 1: Authenticate Users ============
Write-Host "=== Authenticating runner@apexrun.app ==="
$runner = Login-User "runner@apexrun.app" "ApexRun2026!"
Write-Host "Runner ID: $($runner.id)"
Write-Host "Runner Token: $($runner.token.Substring(0, 20))..."

Write-Host "`n=== Handling testuser@apexrun.app ==="
try {
    $testuser = Login-User "testuser@apexrun.app" "ApexRun2026!"
    Write-Host "TestUser ID: $($testuser.id)"
} catch {
    Write-Host "Login failed, trying signup with new password..."
    # Try creating with different password
    try {
        $testuser = Login-User "testuser@apexrun.app" "TestUser2026!"
        Write-Host "TestUser ID (alt password): $($testuser.id)"
    } catch {
        Write-Host "Alt password also failed. Trying to delete and re-create..."
        # We'll skip testuser if we can't auth
        $testuser = $null
        Write-Host "WARNING: Could not authenticate testuser@apexrun.app. Seeding only runner data."
    }
}

# ============ Step 2: Upsert User Profiles ============
Write-Host "`n=== Seeding User Profiles ==="

# Runner profile
$runnerProfile = @{
    id = $runner.id
    display_name = "Alex Runner"
    avatar_url = "https://api.dicebear.com/7.x/avataaars/svg?seed=runner"
    bio = "Marathon enthusiast | Sub-3:30 goal | Love trail running"
    privacy_radius_meters = 200
    preferred_distance_unit = "km"
    preferred_pace_format = "min_per_km"
}
$result = Invoke-SupabaseRest $runner.token "user_profiles" $runnerProfile "POST" "return=representation,resolution=merge-duplicates"
if ($result) { Write-Host "Runner profile upserted." } else { Write-Host "Runner profile may already exist, trying PATCH..." }

# TestUser profile (if authenticated)
if ($testuser) {
    $testProfile = @{
        id = $testuser.id
        display_name = "Jordan TestRunner"
        avatar_url = "https://api.dicebear.com/7.x/avataaars/svg?seed=testuser"
        bio = "Casual runner exploring the limits | 10K specialist"
        privacy_radius_meters = 300
        preferred_distance_unit = "km"
        preferred_pace_format = "min_per_km"
    }
    $result = Invoke-SupabaseRest $testuser.token "user_profiles" $testProfile "POST" "return=representation,resolution=merge-duplicates"
    if ($result) { Write-Host "TestUser profile upserted." }
}

# ============ Step 3: Seed Activities via RPC ============
Write-Host "`n=== Seeding Activities for Runner ==="

# Delhi area coordinates for realistic routes
$routes = @(
    @{
        name = "Morning Easy Run"
        type = "run"
        wkt = "LINESTRING(77.2090 28.6139, 77.2100 28.6150, 77.2120 28.6165, 77.2140 28.6175, 77.2155 28.6190, 77.2170 28.6200, 77.2180 28.6215, 77.2165 28.6230, 77.2150 28.6220, 77.2130 28.6210, 77.2110 28.6195, 77.2095 28.6180, 77.2090 28.6160, 77.2090 28.6139)"
        distance = 5200.0
        duration = 1680
        pace = 5.38
        maxSpeed = 12.5
        elevGain = 25.0
        elevLoss = 25.0
        avgHr = 142
        maxHr = 158
        daysAgo = 1
        formData = @{
            overall_score = 82
            cadence_score = 85
            stride_score = 78
            posture_score = 83
            ground_contact = 245
            vertical_oscillation = 8.2
            recommendations = @("Increase cadence slightly", "Focus on hip extension")
        }
    },
    @{
        name = "Tempo Run - Lodhi Garden"
        type = "run"
        wkt = "LINESTRING(77.2190 28.5930, 77.2210 28.5945, 77.2230 28.5960, 77.2250 28.5975, 77.2270 28.5990, 77.2280 28.6010, 77.2270 28.6030, 77.2250 28.6015, 77.2230 28.6000, 77.2210 28.5985, 77.2200 28.5965, 77.2190 28.5945, 77.2190 28.5930)"
        distance = 8100.0
        duration = 2268
        pace = 4.67
        maxSpeed = 15.2
        elevGain = 42.0
        elevLoss = 40.0
        avgHr = 165
        maxHr = 178
        daysAgo = 3
        formData = @{
            overall_score = 76
            cadence_score = 80
            stride_score = 72
            posture_score = 76
            ground_contact = 230
            vertical_oscillation = 9.1
            recommendations = @("Maintain form in final km", "Reduce overstriding at pace")
        }
    },
    @{
        name = "Long Run - Sunday"
        type = "run"
        wkt = "LINESTRING(77.1850 28.6350, 77.1880 28.6370, 77.1920 28.6390, 77.1960 28.6410, 77.2000 28.6430, 77.2040 28.6420, 77.2080 28.6400, 77.2110 28.6380, 77.2130 28.6360, 77.2100 28.6340, 77.2060 28.6330, 77.2020 28.6340, 77.1980 28.6350, 77.1940 28.6360, 77.1900 28.6360, 77.1870 28.6355, 77.1850 28.6350)"
        distance = 16500.0
        duration = 5280
        pace = 5.33
        maxSpeed = 13.8
        elevGain = 85.0
        elevLoss = 83.0
        avgHr = 152
        maxHr = 170
        daysAgo = 5
        formData = @{
            overall_score = 71
            cadence_score = 74
            stride_score = 68
            posture_score = 71
            ground_contact = 260
            vertical_oscillation = 9.8
            recommendations = @("Core fatigue after 12km", "Shorten stride in final third")
        }
    },
    @{
        name = "Interval Training 800m"
        type = "run"
        wkt = "LINESTRING(77.2300 28.6100, 77.2315 28.6115, 77.2330 28.6130, 77.2345 28.6140, 77.2355 28.6155, 77.2340 28.6165, 77.2320 28.6155, 77.2305 28.6140, 77.2300 28.6125, 77.2300 28.6100)"
        distance = 6800.0
        duration = 2040
        pace = 5.0
        maxSpeed = 18.5
        elevGain = 15.0
        elevLoss = 15.0
        avgHr = 172
        maxHr = 192
        daysAgo = 7
        formData = @{
            overall_score = 79
            cadence_score = 88
            stride_score = 75
            posture_score = 74
            ground_contact = 215
            vertical_oscillation = 7.5
            recommendations = @("Good speed work form", "Watch shoulder tension at high efforts")
        }
    },
    @{
        name = "Recovery Walk"
        type = "walk"
        wkt = "LINESTRING(77.2090 28.6139, 77.2095 28.6145, 77.2105 28.6152, 77.2115 28.6158, 77.2120 28.6165, 77.2115 28.6170, 77.2105 28.6168, 77.2095 28.6162, 77.2090 28.6155, 77.2090 28.6139)"
        distance = 3200.0
        duration = 2400
        pace = 12.5
        maxSpeed = 6.5
        elevGain = 10.0
        elevLoss = 10.0
        avgHr = 105
        maxHr = 118
        daysAgo = 2
        formData = $null
    },
    @{
        name = "Hill Repeats - Ridge Road"
        type = "run"
        wkt = "LINESTRING(77.1950 28.6200, 77.1965 28.6215, 77.1980 28.6230, 77.1995 28.6248, 77.2010 28.6260, 77.2000 28.6275, 77.1985 28.6265, 77.1970 28.6250, 77.1955 28.6235, 77.1950 28.6220, 77.1950 28.6200)"
        distance = 7400.0
        duration = 2590
        pace = 5.83
        maxSpeed = 16.0
        elevGain = 120.0
        elevLoss = 118.0
        avgHr = 168
        maxHr = 188
        daysAgo = 10
        formData = @{
            overall_score = 73
            cadence_score = 76
            stride_score = 70
            posture_score = 73
            ground_contact = 255
            vertical_oscillation = 10.2
            recommendations = @("Lean into hills more", "Shorten stride on uphills", "Use arms for power")
        }
    },
    @{
        name = "Park Run 5K"
        type = "run"
        wkt = "LINESTRING(77.2200 28.6300, 77.2220 28.6315, 77.2245 28.6330, 77.2265 28.6340, 77.2280 28.6350, 77.2270 28.6365, 77.2250 28.6355, 77.2230 28.6345, 77.2215 28.6330, 77.2205 28.6315, 77.2200 28.6300)"
        distance = 5000.0
        duration = 1350
        pace = 4.50
        maxSpeed = 17.2
        elevGain = 18.0
        elevLoss = 18.0
        avgHr = 175
        maxHr = 190
        daysAgo = 14
        formData = @{
            overall_score = 85
            cadence_score = 90
            stride_score = 82
            posture_score = 83
            ground_contact = 210
            vertical_oscillation = 7.0
            recommendations = @("Excellent race form", "Strong finish - good kick")
        }
    },
    @{
        name = "Easy Jog - Active Recovery"
        type = "run"
        wkt = "LINESTRING(77.2090 28.6139, 77.2100 28.6148, 77.2112 28.6157, 77.2100 28.6165, 77.2090 28.6155, 77.2090 28.6139)"
        distance = 4000.0
        duration = 1520
        pace = 6.33
        maxSpeed = 10.5
        elevGain = 8.0
        elevLoss = 8.0
        avgHr = 128
        maxHr = 140
        daysAgo = 0
        formData = @{
            overall_score = 80
            cadence_score = 82
            stride_score = 78
            posture_score = 80
            ground_contact = 250
            vertical_oscillation = 8.5
            recommendations = @("Good recovery pace", "Relaxed shoulders - well done")
        }
    }
)

$activityIds = @()
foreach ($r in $routes) {
    $startTime = (Get-Date).AddDays(-$r.daysAgo).AddHours(-6).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $endTime = (Get-Date).AddDays(-$r.daysAgo).AddHours(-6).AddSeconds($r.duration).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    
    $params = @{
        p_user_id = $runner.id
        p_activity_name = $r.name
        p_activity_type = $r.type
        p_route_path_wkt = $r.wkt
        p_distance_meters = $r.distance
        p_duration_seconds = $r.duration
        p_avg_pace = $r.pace
        p_max_speed = $r.maxSpeed
        p_elevation_gain = $r.elevGain
        p_elevation_loss = $r.elevLoss
        p_avg_heart_rate = $r.avgHr
        p_max_heart_rate = $r.maxHr
        p_start_time = $startTime
        p_end_time = $endTime
        p_is_private = $false
    }
    
    $aid = Invoke-SupabaseRPC $runner.token "insert_activity" $params
    if ($aid) {
        Write-Host "Activity '$($r.name)' created: $aid"
        $activityIds += $aid
        
        # Update form_analysis_data if available
        if ($r.formData) {
            $formJson = $r.formData | ConvertTo-Json -Depth 5
            $headers = @{
                apikey = $ANON_KEY
                Authorization = "Bearer $($runner.token)"
                "Content-Type" = "application/json"
                Prefer = "return=representation"
            }
            $patchBody = @{ form_analysis_data = $r.formData } | ConvertTo-Json -Depth 5
            try {
                Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/activities?id=eq.$aid" `
                    -Method PATCH -Headers $headers -Body $patchBody | Out-Null
                Write-Host "  Form analysis data added."
            } catch {
                Write-Host "  Could not add form data: $($_.Exception.Message)"
            }
        }
    }
}

# ============ Step 4: Seed Activities for TestUser ============
if ($testuser) {
    Write-Host "`n=== Seeding Activities for TestUser ==="
    $testRoutes = @(
        @{
            name = "Morning 10K"
            type = "run"
            wkt = "LINESTRING(77.2400 28.6500, 77.2420 28.6520, 77.2450 28.6540, 77.2480 28.6555, 77.2510 28.6570, 77.2530 28.6585, 77.2510 28.6600, 77.2480 28.6590, 77.2450 28.6575, 77.2420 28.6560, 77.2400 28.6540, 77.2400 28.6500)"
            distance = 10200.0
            duration = 3468
            pace = 5.67
            maxSpeed = 13.0
            elevGain = 55.0
            elevLoss = 53.0
            avgHr = 155
            maxHr = 172
            daysAgo = 2
        },
        @{
            name = "Evening Easy Run"
            type = "run"
            wkt = "LINESTRING(77.2400 28.6500, 77.2415 28.6512, 77.2430 28.6525, 77.2415 28.6535, 77.2400 28.6520, 77.2400 28.6500)"
            distance = 4500.0
            duration = 1620
            pace = 6.0
            maxSpeed = 11.5
            elevGain = 12.0
            elevLoss = 12.0
            avgHr = 138
            maxHr = 150
            daysAgo = 0
        }
    )
    foreach ($r in $testRoutes) {
        $startTime = (Get-Date).AddDays(-$r.daysAgo).AddHours(-5).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $endTime = (Get-Date).AddDays(-$r.daysAgo).AddHours(-5).AddSeconds($r.duration).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $params = @{
            p_user_id = $testuser.id
            p_activity_name = $r.name
            p_activity_type = $r.type
            p_route_path_wkt = $r.wkt
            p_distance_meters = $r.distance
            p_duration_seconds = $r.duration
            p_avg_pace = $r.pace
            p_max_speed = $r.maxSpeed
            p_elevation_gain = $r.elevGain
            p_elevation_loss = $r.elevLoss
            p_avg_heart_rate = $r.avgHr
            p_max_heart_rate = $r.maxHr
            p_start_time = $startTime
            p_end_time = $endTime
            p_is_private = $false
        }
        $aid = Invoke-SupabaseRPC $testuser.token "insert_activity" $params
        if ($aid) { Write-Host "TestUser Activity '$($r.name)' created: $aid" }
    }
}

# ============ Step 5: Seed Planned Workouts ============
Write-Host "`n=== Seeding Planned Workouts ==="

$workouts = @(
    @{
        workout_type = "easy"
        description = "Easy aerobic run at conversational pace. Focus on breathing and form."
        target_distance_meters = 6000.0
        target_duration_minutes = 36
        coaching_rationale = "Building aerobic base after yesterday's tempo. Keep HR under 145."
        planned_date = (Get-Date).ToString("yyyy-MM-dd")
        is_completed = $false
    },
    @{
        workout_type = "tempo"
        description = "20 min warm-up, 20 min at tempo (4:40-4:50/km), 10 min cool-down."
        target_distance_meters = 9000.0
        target_duration_minutes = 50
        coaching_rationale = "Lactate threshold development. You've shown good tempo fitness this week."
        planned_date = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
        is_completed = $false
    },
    @{
        workout_type = "intervals"
        description = "6x800m at 5K pace (3:45-3:55/km) with 400m jog recovery."
        target_distance_meters = 10000.0
        target_duration_minutes = 55
        coaching_rationale = "VO2max intervals to boost speed endurance. Your 800m splits are improving."
        planned_date = (Get-Date).AddDays(3).ToString("yyyy-MM-dd")
        is_completed = $false
    },
    @{
        workout_type = "long_run"
        description = "Long run with progression: first 10K easy, last 5K at marathon pace."
        target_distance_meters = 18000.0
        target_duration_minutes = 100
        coaching_rationale = "Weekly long run building to marathon distance. Progressive effort builds stamina."
        planned_date = (Get-Date).AddDays(5).ToString("yyyy-MM-dd")
        is_completed = $false
    },
    @{
        workout_type = "recovery"
        description = "Very easy recovery jog or walk. Keep HR below 130."
        target_distance_meters = 3000.0
        target_duration_minutes = 25
        coaching_rationale = "Active recovery after intervals. Promotes blood flow and reduces soreness."
        planned_date = (Get-Date).AddDays(4).ToString("yyyy-MM-dd")
        is_completed = $false
    },
    @{
        workout_type = "easy"
        description = "Completed easy run, good pacing and form."
        target_distance_meters = 5000.0
        target_duration_minutes = 30
        coaching_rationale = "Base building phase. Consistent easy mileage builds foundation."
        planned_date = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
        is_completed = $true
    },
    @{
        workout_type = "tempo"
        description = "Completed tempo run. Hit target paces well."
        target_distance_meters = 8000.0
        target_duration_minutes = 40
        coaching_rationale = "Good lactate threshold session. Pace was consistent."
        planned_date = (Get-Date).AddDays(-3).ToString("yyyy-MM-dd")
        is_completed = $true
    }
)

foreach ($w in $workouts) {
    $w.user_id = $runner.id
    $result = Invoke-SupabaseRest $runner.token "planned_workouts" $w
    if ($result) { Write-Host "Workout '$($w.workout_type)' on $($w.planned_date) created." }
}

if ($testuser) {
    $testWorkouts = @(
        @{
            user_id = $testuser.id
            workout_type = "easy"
            description = "Easy run around the park. Focus on relaxed form."
            target_distance_meters = 5000.0
            target_duration_minutes = 32
            coaching_rationale = "Building consistency. 3 runs per week target."
            planned_date = (Get-Date).ToString("yyyy-MM-dd")
            is_completed = $false
        },
        @{
            user_id = $testuser.id
            workout_type = "long_run"
            description = "Weekend long run, easy effort throughout."
            target_distance_meters = 12000.0
            target_duration_minutes = 72
            coaching_rationale = "Longest run this month. Stay comfortable."
            planned_date = (Get-Date).AddDays(2).ToString("yyyy-MM-dd")
            is_completed = $false
        }
    )
    foreach ($w in $testWorkouts) {
        $result = Invoke-SupabaseRest $testuser.token "planned_workouts" $w
        if ($result) { Write-Host "TestUser workout created." }
    }
}

# ============ Step 6: Seed Segments & Efforts ============
Write-Host "`n=== Seeding Segments ==="

# We need to insert segments - RLS allows all authenticated users to view them
# segments are created by creator_id so RLS should allow insert
$segments = @(
    @{
        name = "India Gate Loop"
        description = "Classic 2km loop around India Gate - popular sprint segment"
        segment_path_wkt = "LINESTRING(77.2295 28.6129, 77.2310 28.6140, 77.2325 28.6155, 77.2335 28.6170, 77.2325 28.6185, 77.2310 28.6175, 77.2295 28.6160, 77.2290 28.6145, 77.2295 28.6129)"
        distance_meters = 2100.0
        elevation_gain_meters = 5.0
        is_verified = $true
        activity_type = "run"
        total_attempts = 45
        unique_athletes = 12
    },
    @{
        name = "Lodhi Garden Trail"
        description = "Scenic path through Lodhi Garden - mix of pavement and trail"
        segment_path_wkt = "LINESTRING(77.2190 28.5930, 77.2210 28.5950, 77.2235 28.5970, 77.2255 28.5985, 77.2270 28.6000, 77.2280 28.6020)"
        distance_meters = 1800.0
        elevation_gain_meters = 12.0
        is_verified = $true
        activity_type = "run"
        total_attempts = 32
        unique_athletes = 8
    }
)

# Segments have PostGIS columns, we need SQL or a similar approach
# Let's use direct REST with geography workaround via SQL RPC
# Actually segments table has segment_path which is geography - REST API can't directly insert
# We need to create an RPC for segments too. Let's use the SQL API approach via Supabase

# Alternative: use the Supabase SQL Editor-style approach if we have service role key
# Since we don't, let's create a temporary RPC function via the Go backend SSH

# Actually, let's try a workaround: create an RPC to insert segments
Write-Host "Segments require PostGIS - attempting to create insert_segment RPC via SSH..."

# For now, let's use the Go backend's direct DB access via SSH to insert segments
$segmentSQL = @"
-- Insert segments
INSERT INTO public.segments (id, name, description, segment_path, distance_meters, elevation_gain_meters, creator_id, is_verified, activity_type, total_attempts, unique_athletes)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'India Gate Loop', 'Classic 2km loop around India Gate - popular sprint segment', 
   ST_GeogFromText('SRID=4326;LINESTRING(77.2295 28.6129, 77.2310 28.6140, 77.2325 28.6155, 77.2335 28.6170, 77.2325 28.6185, 77.2310 28.6175, 77.2295 28.6160, 77.2290 28.6145, 77.2295 28.6129)'),
   2100.0, 5.0, '$($runner.id)', true, 'run', 45, 12),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Lodhi Garden Trail', 'Scenic path through Lodhi Garden', 
   ST_GeogFromText('SRID=4326;LINESTRING(77.2190 28.5930, 77.2210 28.5950, 77.2235 28.5970, 77.2255 28.5985, 77.2270 28.6000, 77.2280 28.6020)'),
   1800.0, 12.0, '$($runner.id)', true, 'run', 32, 8)
ON CONFLICT (id) DO NOTHING;
"@
Write-Host $segmentSQL
Write-Host "This SQL needs to be run via Supabase SQL Editor or SSH to droplet."
Write-Host "Attempting via SSH..."

# Save SQL to temp file and run via SSH
$segmentSQL | Out-File -FilePath "h:\ApexRun\apex_run\segment_seed.sql" -Encoding UTF8

# Also create segment efforts SQL
if ($activityIds.Count -ge 2) {
    $effortsSQL = @"
-- Insert segment efforts (leaderboard entries)
INSERT INTO public.segment_efforts (segment_id, activity_id, user_id, elapsed_seconds, avg_pace_min_per_km, avg_heart_rate, max_speed_kmh, recorded_at)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', '$($activityIds[0])', '$($runner.id)', 540, 4.29, 170, 16.5, '$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")'),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', '$($activityIds[1])', '$($runner.id)', 468, 4.33, 168, 15.8, '$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")')
ON CONFLICT (segment_id, activity_id) DO NOTHING;
"@
    $effortsSQL | Out-File -FilePath "h:\ApexRun\apex_run\efforts_seed.sql" -Encoding UTF8
    Write-Host "Efforts SQL saved."
}

Write-Host "`n=== Seeding Summary ==="
Write-Host "Runner activities created: $($activityIds.Count)"
Write-Host "Planned workouts created: $($workouts.Count)"
Write-Host "TestUser authenticated: $($testuser -ne $null)"
Write-Host ""
Write-Host "MANUAL STEPS NEEDED:"
Write-Host "1. Run segment_seed.sql in Supabase SQL Editor"
Write-Host "2. Run efforts_seed.sql in Supabase SQL Editor"
Write-Host "Done!"
