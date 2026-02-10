-- RPC function for inserting activities with PostGIS geography type
-- Supabase REST API cannot natively INSERT geography types,
-- so this function accepts WKT and casts it using ST_GeogFromText

CREATE OR REPLACE FUNCTION public.insert_activity(
  p_user_id UUID,
  p_activity_name TEXT,
  p_activity_type TEXT DEFAULT 'run',
  p_route_path_wkt TEXT DEFAULT NULL,
  p_distance_meters FLOAT DEFAULT 0,
  p_duration_seconds INT DEFAULT 0,
  p_avg_pace FLOAT DEFAULT NULL,
  p_max_speed FLOAT DEFAULT NULL,
  p_elevation_gain FLOAT DEFAULT NULL,
  p_elevation_loss FLOAT DEFAULT NULL,
  p_avg_heart_rate INT DEFAULT NULL,
  p_max_heart_rate INT DEFAULT NULL,
  p_start_time TIMESTAMPTZ DEFAULT NOW(),
  p_end_time TIMESTAMPTZ DEFAULT NULL,
  p_raw_gps_points JSONB DEFAULT NULL,
  p_is_private BOOLEAN DEFAULT FALSE
) RETURNS UUID AS $$
DECLARE
  new_id UUID;
  route_geog extensions.geography;
BEGIN
  -- Convert WKT to geography if provided
  IF p_route_path_wkt IS NOT NULL AND p_route_path_wkt != '' THEN
    route_geog := extensions.ST_GeogFromText(p_route_path_wkt);
  END IF;

  INSERT INTO public.activities (
    user_id, activity_name, activity_type,
    route_path, distance_meters, duration_seconds,
    avg_pace_min_per_km, max_speed_kmh,
    elevation_gain_meters, elevation_loss_meters,
    avg_heart_rate, max_heart_rate,
    start_time, end_time, raw_gps_points, is_private
  ) VALUES (
    p_user_id, p_activity_name, p_activity_type,
    route_geog, p_distance_meters, p_duration_seconds,
    p_avg_pace, p_max_speed,
    p_elevation_gain, p_elevation_loss,
    p_avg_heart_rate, p_max_heart_rate,
    p_start_time, p_end_time, p_raw_gps_points, p_is_private
  ) RETURNING id INTO new_id;

  RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
