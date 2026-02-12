-- Insert segments
INSERT INTO public.segments (id, name, description, segment_path, distance_meters, elevation_gain_meters, creator_id, is_verified, activity_type, total_attempts, unique_athletes)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', 'India Gate Loop', 'Classic 2km loop around India Gate - popular sprint segment', 
   ST_GeogFromText('SRID=4326;LINESTRING(77.2295 28.6129, 77.2310 28.6140, 77.2325 28.6155, 77.2335 28.6170, 77.2325 28.6185, 77.2310 28.6175, 77.2295 28.6160, 77.2290 28.6145, 77.2295 28.6129)'),
   2100.0, 5.0, 'e4fa0adc-b6eb-40ab-9172-7aa35b84d9b2', true, 'run', 45, 12),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', 'Lodhi Garden Trail', 'Scenic path through Lodhi Garden', 
   ST_GeogFromText('SRID=4326;LINESTRING(77.2190 28.5930, 77.2210 28.5950, 77.2235 28.5970, 77.2255 28.5985, 77.2270 28.6000, 77.2280 28.6020)'),
   1800.0, 12.0, 'e4fa0adc-b6eb-40ab-9172-7aa35b84d9b2', true, 'run', 32, 8)
ON CONFLICT (id) DO NOTHING;
