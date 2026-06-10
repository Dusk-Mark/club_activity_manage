-- 启用扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. 定义枚举类型 (使用 DO 块确保幂等性)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('student', 'club_admin', 'league_committee', 'admin');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'club_status') THEN
        CREATE TYPE club_status AS ENUM ('active', 'inactive', 'disbanded');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'post_type') THEN
        CREATE TYPE post_type AS ENUM ('news', 'announcement', 'rule');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'activity_status') THEN
        CREATE TYPE activity_status AS ENUM ('draft', 'recruiting', 'ongoing', 'ended', 'archived');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'registration_status') THEN
        CREATE TYPE registration_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'application_status') THEN
        CREATE TYPE application_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'message_target') THEN
        CREATE TYPE message_target AS ENUM ('club', 'activity', 'global');
    END IF;
END $$;

-- 2. 用户个人资料表 (与 Supabase Auth 关联)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    role user_role DEFAULT 'student' NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 3. 社团表
CREATE TABLE IF NOT EXISTS clubs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    logo_url TEXT,
    status club_status DEFAULT 'active' NOT NULL,
    creator_id UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 4. 社团成员表
CREATE TABLE IF NOT EXISTS club_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    role TEXT CHECK (role IN ('member', 'leader', 'admin')) DEFAULT 'member',
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    UNIQUE(club_id, user_id)
);

-- 用 SECURITY DEFINER 辅助函数判断社团管理员身份，避免 club_members 策略自引用递归
CREATE OR REPLACE FUNCTION public.is_club_admin(target_club_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM public.club_members
    WHERE club_id = target_club_id
      AND user_id = auth.uid()
      AND role = 'admin'
  );
END;
$$;

ALTER TABLE club_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members are viewable by everyone" ON club_members;
CREATE POLICY "Members are viewable by everyone" ON club_members FOR SELECT USING (true);

DROP POLICY IF EXISTS "League committee and admins can manage members" ON club_members;
CREATE POLICY "League committee and admins can manage members" ON club_members FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

DROP POLICY IF EXISTS "Club admins can manage their own club members" ON club_members;
CREATE POLICY "Club admins can manage their own club members" ON club_members FOR ALL USING (
  public.is_club_admin(club_id)
);

-- 5. 新闻公告与规章制度表
CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    type post_type NOT NULL,
    author_id UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 6. 社团活动表
CREATE TABLE IF NOT EXISTS activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    location TEXT,
    status activity_status DEFAULT 'draft' NOT NULL,
    max_participants INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 7. 活动报名表
CREATE TABLE IF NOT EXISTS activity_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id UUID REFERENCES activities(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    status registration_status DEFAULT 'pending' NOT NULL,
    check_in_time TIMESTAMP WITH TIME ZONE,
    feedback TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    UNIQUE(activity_id, user_id)
);

-- 8. 申请类型表
CREATE TABLE IF NOT EXISTS application_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL UNIQUE
);

-- 9. 用户申请管理表
CREATE TABLE IF NOT EXISTS user_applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type_id UUID REFERENCES application_types(id),
    user_id UUID REFERENCES profiles(id),
    content JSONB NOT NULL,
    status application_status DEFAULT 'pending' NOT NULL,
    admin_remark TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 10. 留言交流表
CREATE TABLE IF NOT EXISTS messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID REFERENCES profiles(id),
    content TEXT NOT NULL,
    target_type message_target DEFAULT 'global' NOT NULL,
    target_id UUID, -- 对应 club_id 或 activity_id
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

-- 11. 自动更新 updated_at 的函数和触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    EXECUTE PROCEDURE update_updated_at_column();

-- 12. Supabase 自动创建 Profile 的触发器 (当 Auth 用户注册时)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name, avatar_url, role)
    VALUES (
        new.id, 
        new.raw_user_meta_data->>'username', 
        new.raw_user_meta_data->>'full_name', 
        new.raw_user_meta_data->>'avatar_url',
        COALESCE((new.raw_user_meta_data->>'role')::user_role, 'student'::user_role)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 13. 行级安全策略 (RLS) - 基本配置
-- 开启 RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
-- ... (其余策略保持不变)

-- 14. 存储配置 (Supabase Storage)
-- 注意：在 SQL Editor 运行以下代码前，请确保已启用 Storage 扩展
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- 允许任何人查看头像
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');

-- 允许认证用户上传头像
DROP POLICY IF EXISTS "Authenticated users can upload avatars" ON storage.objects;
CREATE POLICY "Authenticated users can upload avatars" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'avatars' AND auth.role() = 'authenticated'
);

-- 允许用户删除/更新自己的头像
DROP POLICY IF EXISTS "Users can update their own avatars" ON storage.objects;
CREATE POLICY "Users can update their own avatars" ON storage.objects FOR UPDATE USING (
  bucket_id = 'avatars' AND auth.uid() = owner
);

DROP POLICY IF EXISTS "Users can delete their own avatars" ON storage.objects;
CREATE POLICY "Users can delete their own avatars" ON storage.objects FOR DELETE USING (
  bucket_id = 'avatars' AND auth.uid() = owner
);

DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
CREATE POLICY "Public profiles are viewable by everyone" ON profiles FOR SELECT USING (true);

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- 注意：这里不再使用 FOR ALL 而是针对特定操作，且避免递归
DROP POLICY IF EXISTS "Committee can update all profiles" ON profiles;
CREATE POLICY "Committee can update all profiles" ON profiles FOR UPDATE USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('league_committee', 'admin')
);

DROP POLICY IF EXISTS "Committee can delete profiles" ON profiles;
CREATE POLICY "Committee can delete profiles" ON profiles FOR DELETE USING (
  (SELECT role FROM profiles WHERE id = auth.uid()) IN ('league_committee', 'admin')
);

-- Clubs 策略: 所有人可见，校团委或管理员可操作
DROP POLICY IF EXISTS "Clubs are viewable by everyone" ON clubs;
CREATE POLICY "Clubs are viewable by everyone" ON clubs FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage clubs" ON clubs;
CREATE POLICY "Admins can manage clubs" ON clubs FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

-- Activities 策略: 所有人可见，社团负责人/社团管理员/校团委/系统管理员可管理
DROP POLICY IF EXISTS "Activities are viewable by everyone" ON activities;
CREATE POLICY "Activities are viewable by everyone" ON activities FOR SELECT USING (true);

DROP POLICY IF EXISTS "Club admins can manage activities" ON activities;
CREATE POLICY "Club admins can manage activities" ON activities FOR ALL USING (
  EXISTS (
    SELECT 1
    FROM club_members
    WHERE user_id = auth.uid()
      AND club_id = activities.club_id
      AND role IN ('leader', 'admin')
  )
  OR (
    EXISTS (
      SELECT 1
      FROM profiles
      WHERE id = auth.uid()
        AND role = 'club_admin'
    )
    AND EXISTS (
      SELECT 1
      FROM club_members
      WHERE user_id = auth.uid()
        AND club_id = activities.club_id
    )
  )
  OR EXISTS (
    SELECT 1
    FROM profiles
    WHERE id = auth.uid()
      AND role IN ('league_committee', 'admin')
  )
) WITH CHECK (
  EXISTS (
    SELECT 1
    FROM club_members
    WHERE user_id = auth.uid()
      AND club_id = activities.club_id
      AND role IN ('leader', 'admin')
  )
  OR (
    EXISTS (
      SELECT 1
      FROM profiles
      WHERE id = auth.uid()
        AND role = 'club_admin'
    )
    AND EXISTS (
      SELECT 1
      FROM club_members
      WHERE user_id = auth.uid()
        AND club_id = activities.club_id
    )
  )
  OR EXISTS (
    SELECT 1
    FROM profiles
    WHERE id = auth.uid()
      AND role IN ('league_committee', 'admin')
  )
);

-- Registrations 策略: 个人可见本人，社团管理员可见本活动所有
DROP POLICY IF EXISTS "Users can view own registrations" ON activity_registrations;
CREATE POLICY "Users can view own registrations" ON activity_registrations FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Club admins can view registrations" ON activity_registrations;
CREATE POLICY "Club admins can view registrations" ON activity_registrations FOR SELECT USING (
  EXISTS (SELECT 1 FROM activities a JOIN club_members cm ON a.club_id = cm.club_id WHERE a.id = activity_id AND cm.user_id = auth.uid() AND cm.role = 'admin')
);

DROP POLICY IF EXISTS "Users can register for activities" ON activity_registrations;
CREATE POLICY "Users can register for activities" ON activity_registrations FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Messages 策略: 登录用户可见，本人可发
DROP POLICY IF EXISTS "Authenticated users can view messages" ON messages;
CREATE POLICY "Authenticated users can view messages" ON messages FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Users can insert messages" ON messages;
CREATE POLICY "Users can insert messages" ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- 15. 活动资料归档与网站配置
CREATE TABLE IF NOT EXISTS activity_archives (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    activity_id UUID REFERENCES activities(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    file_url TEXT,
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

CREATE TABLE IF NOT EXISTS site_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    description TEXT,
    updated_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE activity_archives ENABLE ROW LEVEL SECURITY;
ALTER TABLE site_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Activity archives viewable by everyone" ON activity_archives;
CREATE POLICY "Activity archives viewable by everyone" ON activity_archives FOR SELECT USING (true);

DROP POLICY IF EXISTS "Club admins can manage activity archives" ON activity_archives;
CREATE POLICY "Club admins can manage activity archives" ON activity_archives FOR ALL USING (
  EXISTS (
    SELECT 1
    FROM activities a
    JOIN club_members cm ON a.club_id = cm.club_id
    WHERE a.id = activity_archives.activity_id
      AND cm.user_id = auth.uid()
      AND cm.role = 'admin'
  )
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

DROP POLICY IF EXISTS "Committee can manage site configs" ON site_configs;
CREATE POLICY "Committee can manage site configs" ON site_configs FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

-- 16. 扩展申请类型字段，便于后台定义与前台动态渲染
ALTER TABLE application_types ADD COLUMN IF NOT EXISTS key TEXT UNIQUE;
ALTER TABLE application_types ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE application_types ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'system';

-- 17. 审批与后台管理策略补充
ALTER TABLE application_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_applications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can view application types" ON application_types;
CREATE POLICY "Authenticated users can view application types" ON application_types FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Committee can manage application types" ON application_types;
CREATE POLICY "Committee can manage application types" ON application_types FOR ALL USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

DROP POLICY IF EXISTS "Users can view own applications" ON user_applications;
CREATE POLICY "Users can view own applications" ON user_applications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can create own applications" ON user_applications;
CREATE POLICY "Users can create own applications" ON user_applications FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Club admins and committee can review applications" ON user_applications;
CREATE POLICY "Club admins and committee can review applications" ON user_applications FOR SELECT USING (
  auth.uid() = user_id
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
  OR (
    EXISTS (
      SELECT 1
      FROM club_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
        AND cm.club_id::text = COALESCE(user_applications.content->>'club_id', '')
    )
    AND user_applications.content->>'application_key' <> 'join_club'
  )
);

DROP POLICY IF EXISTS "Club admins and committee can update applications" ON user_applications;
CREATE POLICY "Club admins and committee can update applications" ON user_applications FOR UPDATE USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
  OR (
    EXISTS (
      SELECT 1
      FROM club_members cm
      WHERE cm.user_id = auth.uid()
        AND cm.role = 'admin'
        AND cm.club_id::text = COALESCE(user_applications.content->>'club_id', '')
    )
    AND user_applications.content->>'application_key' <> 'join_club'
  )
);

DROP POLICY IF EXISTS "Committee can view all registrations" ON activity_registrations;
CREATE POLICY "Committee can view all registrations" ON activity_registrations FOR SELECT USING (
  EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

DROP POLICY IF EXISTS "Approved users can update own registration feedback" ON activity_registrations;
CREATE POLICY "Approved users can update own registration feedback" ON activity_registrations FOR UPDATE USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1
    FROM activities a
    JOIN club_members cm ON a.club_id = cm.club_id
    WHERE a.id = activity_registrations.activity_id
      AND cm.user_id = auth.uid()
      AND cm.role = 'admin'
  )
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

-- 注意：Profiles 的管理权限已在上方第 160-180 行左右统一定义，此处不再重复，避免递归

-- 18. 社团负责人和任务协同
ALTER TABLE club_members DROP CONSTRAINT IF EXISTS club_members_role_check;
ALTER TABLE club_members
ADD CONSTRAINT club_members_role_check CHECK (role IN ('member', 'leader', 'admin'));

CREATE TABLE IF NOT EXISTS club_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    club_id UUID REFERENCES clubs(id) ON DELETE CASCADE NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT DEFAULT 'medium',
    status TEXT DEFAULT 'todo',
    due_date TIMESTAMP WITH TIME ZONE,
    assignee_id UUID REFERENCES profiles(id),
    created_by UUID REFERENCES profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW())
);

ALTER TABLE club_tasks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Club members can view tasks" ON club_tasks;
CREATE POLICY "Club members can view tasks" ON club_tasks FOR SELECT USING (
  EXISTS (
    SELECT 1
    FROM club_members cm
    WHERE cm.club_id = club_tasks.club_id
      AND cm.user_id = auth.uid()
  )
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

DROP POLICY IF EXISTS "Leaders can manage tasks" ON club_tasks;
CREATE POLICY "Leaders can manage tasks" ON club_tasks FOR ALL USING (
  EXISTS (
    SELECT 1
    FROM club_members cm
    WHERE cm.club_id = club_tasks.club_id
      AND cm.user_id = auth.uid()
      AND cm.role IN ('leader', 'admin')
  )
  OR (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'club_admin')
    AND EXISTS (
      SELECT 1
      FROM club_members cm
      WHERE cm.club_id = club_tasks.club_id
        AND cm.user_id = auth.uid()
    )
  )
  OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role IN ('league_committee', 'admin'))
);

-- 19. 推荐的初始化申请类型
-- 使用 ON CONFLICT (name) DO UPDATE 确保 key 字段被正确填充，即使记录已存在
INSERT INTO application_types (name, key, description, scope)
VALUES
  ('加入社团申请', 'join_club', '用于申请加入某个社团，由社团管理员审批。', 'club'),
  ('活动经费申请', 'activity_fund', '用于申请活动执行预算和物资经费，由校团委审批。', 'activity'),
  ('资源支持申请', 'resource_support', '用于申请场地、宣传或设备等支持。', 'system')
ON CONFLICT (name) DO UPDATE 
SET 
  key = EXCLUDED.key,
  description = EXCLUDED.description,
  scope = EXCLUDED.scope
WHERE application_types.key IS NULL;
