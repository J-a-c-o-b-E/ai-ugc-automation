-- AI UGC Generator Database Schema
-- Run this in Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- AI Characters table
CREATE TABLE IF NOT EXISTS characters (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  is_default BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Jobs table for processing pipeline
CREATE TABLE IF NOT EXISTS jobs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  character_id UUID REFERENCES characters(id),
  tiktok_url TEXT NOT NULL,
  original_video_url TEXT,
  video_duration DECIMAL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'downloading', 'analyzing', 'extracting', 'generating_images', 'generating_videos', 'complete', 'error')),
  current_step INTEGER DEFAULT 0,
  total_steps INTEGER DEFAULT 7,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- UGC Segments detected in videos
CREATE TABLE IF NOT EXISTS segments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
  segment_index INTEGER NOT NULL,
  start_time DECIMAL NOT NULL,
  end_time DECIMAL NOT NULL,
  duration DECIMAL NOT NULL,
  final_duration DECIMAL,
  is_looped BOOLEAN DEFAULT FALSE,
  loop_count INTEGER DEFAULT 1,
  segment_video_url TEXT,
  first_frame_url TEXT,
  ai_character_image_url TEXT,
  clean_image_url TEXT,
  output_video_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'cut', 'frame_extracted', 'image_generated', 'image_cleaned', 'video_generating', 'complete', 'error')),
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Processing logs for real-time updates
CREATE TABLE IF NOT EXISTS logs (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  job_id UUID REFERENCES jobs(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  log_type TEXT DEFAULT 'info' CHECK (log_type IN ('info', 'success', 'warning', 'error')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- API Keys storage (encrypted)
CREATE TABLE IF NOT EXISTS api_keys (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  wavespeed_key_encrypted TEXT,
  gemini_key_encrypted TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_jobs_user_id ON jobs(user_id);
CREATE INDEX IF NOT EXISTS idx_jobs_status ON jobs(status);
CREATE INDEX IF NOT EXISTS idx_segments_job_id ON segments(job_id);
CREATE INDEX IF NOT EXISTS idx_logs_job_id ON logs(job_id);
CREATE INDEX IF NOT EXISTS idx_logs_created_at ON logs(created_at);
CREATE INDEX IF NOT EXISTS idx_characters_user_id ON characters(user_id);

-- Enable Row Level Security
ALTER TABLE characters ENABLE ROW LEVEL SECURITY;
ALTER TABLE jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- RLS Policies for characters
CREATE POLICY "Users can view their own characters" ON characters
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own characters" ON characters
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own characters" ON characters
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own characters" ON characters
  FOR DELETE USING (auth.uid() = user_id);

-- RLS Policies for jobs
CREATE POLICY "Users can view their own jobs" ON jobs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own jobs" ON jobs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own jobs" ON jobs
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for segments (via job ownership)
CREATE POLICY "Users can view segments of their jobs" ON segments
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM jobs WHERE jobs.id = segments.job_id AND jobs.user_id = auth.uid())
  );

-- RLS Policies for logs (via job ownership)
CREATE POLICY "Users can view logs of their jobs" ON logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM jobs WHERE jobs.id = logs.job_id AND jobs.user_id = auth.uid())
  );

-- RLS Policies for api_keys
CREATE POLICY "Users can view their own api keys" ON api_keys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own api keys" ON api_keys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own api keys" ON api_keys
  FOR UPDATE USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_characters_updated_at BEFORE UPDATE ON characters
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_jobs_updated_at BEFORE UPDATE ON jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_segments_updated_at BEFORE UPDATE ON segments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON api_keys
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default character
INSERT INTO characters (id, name, description, is_default) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Jade Miller',
  'mid-20s woman
calm, poised demeanor
soft neutral gaze with a subtle closed-lip hint of a smile
deep espresso-black hair
long, straight, sleek hair
middle part
hair tucked behind the ears and flowing over the shoulders
sharp winged black eyeliner
soft brown eyeshadow
groomed natural eyebrows
matte mauve-nude lipstick
satin skin finish with subtle contouring
small silver-toned or white gold polished hoop earrings
silver-toned cuban link chain bracelet on the right wrist',
  TRUE
) ON CONFLICT DO NOTHING;

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('videos', 'videos', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('images', 'images', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('frames', 'frames', true) ON CONFLICT DO NOTHING;

-- Storage policies
CREATE POLICY "Public read access for videos" ON storage.objects
  FOR SELECT USING (bucket_id = 'videos');

CREATE POLICY "Authenticated users can upload videos" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'videos' AND auth.role() = 'authenticated');

CREATE POLICY "Public read access for images" ON storage.objects
  FOR SELECT USING (bucket_id = 'images');

CREATE POLICY "Authenticated users can upload images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'images' AND auth.role() = 'authenticated');

CREATE POLICY "Public read access for frames" ON storage.objects
  FOR SELECT USING (bucket_id = 'frames');

CREATE POLICY "Authenticated users can upload frames" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'frames' AND auth.role() = 'authenticated');

-- Enable realtime for relevant tables
ALTER PUBLICATION supabase_realtime ADD TABLE jobs;
ALTER PUBLICATION supabase_realtime ADD TABLE segments;
ALTER PUBLICATION supabase_realtime ADD TABLE logs;
