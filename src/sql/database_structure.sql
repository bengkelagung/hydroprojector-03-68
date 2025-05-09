-- Create essential tables for the hydroprojector application

-- Create the profiles table first as it's referenced by other tables
CREATE TABLE IF NOT EXISTS public.profiles (
  profile_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT,
  last_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create projects table
CREATE TABLE IF NOT EXISTS public.projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_name TEXT NOT NULL,
  description TEXT,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES public.profiles(profile_id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create devices table
CREATE TABLE IF NOT EXISTS public.devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_name TEXT NOT NULL,
  description TEXT,
  device_type TEXT DEFAULT 'ESP32' NOT NULL,
  project_id UUID NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
  is_connected BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'ACTIVE',
  last_seen TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Create pins reference table
CREATE TABLE IF NOT EXISTS public.pins (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pin_name TEXT NOT NULL,
  pin_number INTEGER NOT NULL,
  UNIQUE(pin_number)
);

-- Create data types table
CREATE TABLE IF NOT EXISTS public.data_types (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

-- Create signal types table
CREATE TABLE IF NOT EXISTS public.signal_types (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

-- Create modes table
CREATE TABLE IF NOT EXISTS public.modes (
  id SERIAL PRIMARY KEY,
  type TEXT UNIQUE NOT NULL
);

-- Create label table
CREATE TABLE IF NOT EXISTS public.label (
  id SERIAL PRIMARY KEY,
  name VARCHAR(50) UNIQUE NOT NULL
);

-- Create pin_configs table with foreign key references
CREATE TABLE IF NOT EXISTS public.pin_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id UUID NOT NULL REFERENCES public.devices(id) ON DELETE CASCADE,
  pin_id UUID NOT NULL REFERENCES public.pins(id) ON DELETE RESTRICT,
  data_type_id INTEGER NOT NULL REFERENCES public.data_types(id) ON DELETE RESTRICT,
  signal_type_id INTEGER NOT NULL REFERENCES public.signal_types(id) ON DELETE RESTRICT,
  mode_id INTEGER NOT NULL REFERENCES public.modes(id) ON DELETE RESTRICT,
  label_id INTEGER REFERENCES public.label(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  unit TEXT,
  value TEXT,
  last_updated TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
  UNIQUE(device_id, pin_id)
);

-- Create pin_data table for historical data
CREATE TABLE IF NOT EXISTS public.pin_data (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pin_config_id UUID NOT NULL REFERENCES public.pin_configs(id) ON DELETE CASCADE,
  value TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Initial data for reference tables

-- Insert default pin options
INSERT INTO public.pins (pin_name, pin_number) VALUES
  ('GPIO0', 0),
  ('GPIO1', 1),
  ('GPIO2', 2),
  ('GPIO3', 3),
  ('GPIO4', 4),
  ('GPIO5', 5),
  ('GPIO12', 12),
  ('GPIO13', 13),
  ('GPIO14', 14),
  ('GPIO15', 15),
  ('GPIO16', 16),
  ('GPIO17', 17),
  ('GPIO18', 18),
  ('GPIO19', 19),
  ('GPIO21', 21),
  ('GPIO22', 22),
  ('GPIO23', 23),
  ('GPIO25', 25),
  ('GPIO26', 26),
  ('GPIO27', 27),
  ('GPIO32', 32),
  ('GPIO33', 33),
  ('GPIO34', 34),
  ('GPIO35', 35),
  ('GPIO36', 36),
  ('GPIO39', 39)
ON CONFLICT (pin_number) DO NOTHING;

-- Insert default data types
INSERT INTO public.data_types (name) VALUES
  ('integer'),
  ('float'),
  ('boolean'),
  ('string'),
  ('analog'),
  ('digital')
ON CONFLICT (name) DO NOTHING;

-- Insert default signal types
INSERT INTO public.signal_types (name) VALUES
  ('pH'),
  ('temperature'),
  ('humidity'),
  ('water-level'),
  ('nutrient'),
  ('light'),
  ('analog'),
  ('digital'),
  ('custom')
ON CONFLICT (name) DO NOTHING;

-- Insert default modes
INSERT INTO public.modes (type) VALUES
  ('input'),
  ('output')
ON CONFLICT (type) DO NOTHING;

-- Insert default labels
INSERT INTO public.label (name) VALUES
  ('pH'),
  ('Suhu'),
  ('Kelembaban'),
  ('Pompa'),
  ('Lampu'),
  ('Level Air')
ON CONFLICT (name) DO NOTHING;

-- Set up RLS policies
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pin_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pin_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.label ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.signal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.modes ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
CREATE POLICY "Users can view their own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can view their own projects" ON public.projects
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own projects" ON public.projects
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own projects" ON public.projects
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own projects" ON public.projects
  FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view devices in their projects" ON public.devices
  FOR SELECT USING (
    project_id IN (
      SELECT id FROM public.projects WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create devices in their projects" ON public.devices
  FOR INSERT WITH CHECK (
    project_id IN (
      SELECT id FROM public.projects WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update devices in their projects" ON public.devices
  FOR UPDATE USING (
    project_id IN (
      SELECT id FROM public.projects WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete devices in their projects" ON public.devices
  FOR DELETE USING (
    project_id IN (
      SELECT id FROM public.projects WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view pin configs for their devices" ON public.pin_configs
  FOR SELECT USING (
    device_id IN (
      SELECT d.id FROM public.devices d
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create pin configs for their devices" ON public.pin_configs
  FOR INSERT WITH CHECK (
    device_id IN (
      SELECT d.id FROM public.devices d
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update pin configs for their devices" ON public.pin_configs
  FOR UPDATE USING (
    device_id IN (
      SELECT d.id FROM public.devices d
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete pin configs for their devices" ON public.pin_configs
  FOR DELETE USING (
    device_id IN (
      SELECT d.id FROM public.devices d
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view pin data for their devices" ON public.pin_data
  FOR SELECT USING (
    pin_config_id IN (
      SELECT pc.id FROM public.pin_configs pc
      JOIN public.devices d ON pc.device_id = d.id
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create pin data for their devices" ON public.pin_data
  FOR INSERT WITH CHECK (
    pin_config_id IN (
      SELECT pc.id FROM public.pin_configs pc
      JOIN public.devices d ON pc.device_id = d.id
      JOIN public.projects p ON d.project_id = p.id
      WHERE p.user_id = auth.uid()
    )
  );

-- Allow read access to authenticated users for reference tables
CREATE POLICY "Allow users to read pins" ON public.pins FOR SELECT USING (true);
CREATE POLICY "Allow users to read data types" ON public.data_types FOR SELECT USING (true);
CREATE POLICY "Allow users to read signal types" ON public.signal_types FOR SELECT USING (true);
CREATE POLICY "Allow users to read modes" ON public.modes FOR SELECT USING (true);
CREATE POLICY "Allow users to read labels" ON public.label FOR SELECT USING (true);

-- Grant appropriate permissions
GRANT SELECT ON public.pins TO authenticated;
GRANT SELECT ON public.data_types TO authenticated;
GRANT SELECT ON public.signal_types TO authenticated;
GRANT SELECT ON public.modes TO authenticated;
GRANT SELECT ON public.label TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.projects TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.devices TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pin_configs TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pin_data TO authenticated;

-- Grant anon user select on reference tables for initial loading
GRANT SELECT ON public.pins TO anon;
GRANT SELECT ON public.data_types TO anon;
GRANT SELECT ON public.signal_types TO anon;
GRANT SELECT ON public.modes TO anon;
GRANT SELECT ON public.label TO anon;

-- Create storage trigger to delete avatar when user is deleted
CREATE OR REPLACE FUNCTION delete_avatar_on_user_delete()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete avatar from storage
  PERFORM storage.delete_object('avatars', OLD.user_id || '/*');
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_delete_avatar_on_user_delete
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION delete_avatar_on_user_delete();

-- Create function to clean up all user data
CREATE OR REPLACE FUNCTION clean_up_user_data(user_id UUID)
RETURNS void AS $$
BEGIN
  -- Delete all pin data related to user's devices
  DELETE FROM pin_data
  WHERE pin_config_id IN (
    SELECT pc.id
    FROM pin_configs pc
    JOIN devices d ON pc.device_id = d.id
    JOIN projects p ON d.project_id = p.id
    WHERE p.user_id = user_id
  );

  -- Delete all pin configurations related to user's devices
  DELETE FROM pin_configs
  WHERE device_id IN (
    SELECT d.id
    FROM devices d
    JOIN projects p ON d.project_id = p.id
    WHERE p.user_id = user_id
  );

  -- Delete all devices related to user's projects
  DELETE FROM devices
  WHERE project_id IN (
    SELECT id FROM projects WHERE user_id = user_id
  );

  -- Delete all projects
  DELETE FROM projects WHERE user_id = user_id;

  -- Delete profile
  DELETE FROM profiles WHERE user_id = user_id;

  -- Delete avatar from storage
  PERFORM storage.delete_object('avatars', user_id || '/*');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
