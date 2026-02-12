-- Insert segment efforts (leaderboard entries)
INSERT INTO public.segment_efforts (segment_id, activity_id, user_id, elapsed_seconds, avg_pace_min_per_km, avg_heart_rate, max_speed_kmh, recorded_at)
VALUES 
  ('a1b2c3d4-e5f6-7890-abcd-ef1234567890', '5e5b4155-6bc1-4ed4-b96b-4abc77b042c0', 'e4fa0adc-b6eb-40ab-9172-7aa35b84d9b2', 540, 4.29, 170, 16.5, '2026-02-12T17:48:05Z'),
  ('b2c3d4e5-f6a7-8901-bcde-f12345678901', '36b31f2a-a7cb-4bc1-8331-176838f4bc20', 'e4fa0adc-b6eb-40ab-9172-7aa35b84d9b2', 468, 4.33, 168, 15.8, '2026-02-12T17:48:05Z')
ON CONFLICT (segment_id, activity_id) DO NOTHING;
