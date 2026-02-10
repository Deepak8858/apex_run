-- RPC function for updating user home location with PostGIS Point type

CREATE OR REPLACE FUNCTION public.update_home_location(
  p_user_id UUID,
  p_lat FLOAT,
  p_lng FLOAT
) RETURNS VOID AS $$
BEGIN
  UPDATE public.user_profiles
  SET home_location = extensions.ST_SetSRID(
    extensions.ST_MakePoint(p_lng, p_lat), 4326
  )::extensions.geography
  WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
