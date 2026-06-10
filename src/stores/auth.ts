import { defineStore } from 'pinia'
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import type { User } from '@supabase/supabase-js'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const loading = ref(true)
  const initialized = ref(false)

  async function fetchUser() {
    loading.value = true
    const { data: { session } } = await supabase.auth.getSession()
    user.value = session?.user ?? null
    loading.value = false
    initialized.value = true
    return user.value
  }

  async function ensureUser() {
    if (initialized.value) {
      return user.value
    }

    return fetchUser()
  }

  // 监听认证状态变化
  supabase.auth.onAuthStateChange((_event, session) => {
    user.value = session?.user ?? null
    loading.value = false
    initialized.value = true
  })

  return {
    user,
    loading,
    fetchUser,
    ensureUser
  }
})
