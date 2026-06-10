import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const fallbackSupabaseUrl = 'https://example.supabase.co'
const fallbackSupabaseAnonKey =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.placeholder.payload'

export const isSupabaseConfigured = Boolean(supabaseUrl && supabaseAnonKey)
export const supabaseConfigMessage = isSupabaseConfigured
  ? ''
  : '当前环境未配置 Supabase，请在 Vercel 项目设置中补充 VITE_SUPABASE_URL 与 VITE_SUPABASE_ANON_KEY。'

if (!isSupabaseConfigured) {
  console.error(supabaseConfigMessage)
}

// Use a harmless fallback client so the app can still render a visible error
// state instead of crashing on startup when deployment env vars are missing.
export const supabase = createClient(
  supabaseUrl || fallbackSupabaseUrl,
  supabaseAnonKey || fallbackSupabaseAnonKey,
)
