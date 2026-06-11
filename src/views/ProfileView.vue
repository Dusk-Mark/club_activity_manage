<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { 
  ArrowLeft, 
  Save, 
  User as UserIcon, 
  Mail, 
  Tag, 
  Camera,
  Loader2,
  CheckCircle2
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const profile = ref<any>({
  full_name: '',
  username: '',
  avatar_url: '',
  role: 'student'
})
const message = ref({ text: '', type: '' })

const fetchProfile = async () => {
  const user = await authStore.ensureUser()
  if (!user) return
  
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', user.id)
    .single()
  
  if (data) {
    profile.value = data
  } else if (error) {
    console.error('Error fetching profile:', error.message)
  }
}

const handleUpdate = async () => {
  const user = await authStore.ensureUser()
  if (!user) {
    router.push('/')
    return
  }

  loading.value = true
  message.value = { text: '', type: '' }
  
  try {
    const { error } = await supabase
      .from('profiles')
      .update({
        full_name: profile.value.full_name,
        username: profile.value.username
      })
      .eq('id', user.id)
    
    if (error) throw error
    message.value = { text: '个人资料已成功更新！', type: 'success' }
  } catch (error: any) {
    message.value = { text: error.message || '更新失败', type: 'error' }
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await fetchProfile()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-5xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:flex-row md:items-center md:justify-between md:px-6">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="club-back-button flex h-12 w-12 items-center justify-center"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div>
            <p class="text-sm text-slate-400">Profile Archive</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-3 text-sm">
          <span class="club-pill px-4 py-2">{{ profile.role === 'student' ? '学生身份' : profile.role }}</span>
          <span class="club-status-chip px-4 py-2">资料维护</span>
        </div>
      </header>

      <main class="grid gap-6 lg:grid-cols-[0.86fr_1.14fr]">
        <section class="club-panel overflow-hidden p-6 md:p-8">
          <div class="rounded-[28px] border border-white/8 bg-white/[0.03] p-6">
            <div class="flex flex-col items-center text-center">
              <div class="relative group">
                <div class="h-36 w-36 overflow-hidden rounded-[32px] border border-white/10 bg-white/5 p-1 shadow-[0_28px_50px_-24px_rgba(0,0,0,0.8)]">
                  <img
                    :src="profile.avatar_url || `https://ui-avatars.com/api/?name=${profile.full_name || 'User'}&background=111515&color=F7F2EA&size=256`"
                    :alt="profile.full_name || '用户头像'"
                    class="h-full w-full rounded-[28px] object-cover"
                  />
                </div>
                <button type="button" class="club-button-primary absolute -bottom-2 -right-2 rounded-2xl p-3">
                  <Camera class="h-5 w-5" />
                </button>
              </div>
              <h2 class="mt-6 font-display text-4xl font-bold text-white">
                {{ profile.full_name || '未设置姓名' }}
              </h2>
              <p class="mt-2 text-sm text-slate-400">
                {{ authStore.user?.email || '暂无邮箱信息' }}
              </p>
            </div>

            <div class="club-divider my-8" />

            <div class="grid gap-4 sm:grid-cols-2">
              <article class="club-panel-muted p-5">
                <p class="text-sm text-slate-400">账户角色</p>
                <p class="mt-2 text-lg font-semibold text-white">
                  {{ profile.role === 'student' ? '学生用户' : profile.role }}
                </p>
              </article>
              <article class="club-panel-muted p-5">
                <p class="text-sm text-slate-400">资料状态</p>
                <p class="mt-2 text-lg font-semibold text-white">可更新</p>
              </article>
            </div>
          </div>
        </section>

        <section class="club-panel p-6 md:p-8">
          <div class="mb-6">
            <p class="text-sm text-slate-400">Editable Fields</p>
            <h2 class="mt-1 font-display text-3xl font-bold text-white">更新个人资料</h2>
          </div>

          <form @submit.prevent="handleUpdate" class="space-y-5">
            <div class="grid gap-5 md:grid-cols-2">
              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">真实姓名</label>
                <div class="relative">
                  <UserIcon class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                  <input
                    v-model="profile.full_name"
                    type="text"
                    placeholder="请输入姓名"
                    class="club-input w-full py-4 pl-12 pr-4"
                  />
                </div>
              </div>

              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">用户名</label>
                <div class="relative">
                  <Tag class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                  <input
                    v-model="profile.username"
                    type="text"
                    placeholder="设置用户名"
                    class="club-input w-full py-4 pl-12 pr-4"
                  />
                </div>
              </div>
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">电子邮箱</label>
              <div class="relative">
                <Mail class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                <input
                  :value="authStore.user?.email"
                  disabled
                  type="email"
                  class="club-input w-full cursor-not-allowed py-4 pl-12 pr-4 opacity-70"
                />
              </div>
            </div>

            <div
              v-if="message.text"
              :class="[
                'rounded-2xl border px-4 py-3 text-sm leading-6',
                message.type === 'success'
                  ? 'border-emerald-400/20 bg-emerald-400/10 text-emerald-100'
                  : 'border-rose-400/20 bg-rose-400/10 text-rose-100'
              ]"
            >
              <div class="flex items-center gap-2">
                <CheckCircle2 v-if="message.type === 'success'" class="h-5 w-5" />
                <span>{{ message.text }}</span>
              </div>
            </div>

            <button
              :disabled="loading"
              type="submit"
              class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
            >
              <Loader2 v-if="loading" class="h-5 w-5 animate-spin" />
              <template v-else>
                <Save class="h-5 w-5" />
                保存更改
              </template>
            </button>
          </form>

          <div class="mt-6 grid gap-4 md:grid-cols-2">
            <button type="button" class="card-hover club-panel-muted flex items-center justify-between p-5 text-left">
              <div>
                <p class="font-semibold text-white">修改密码</p>
                <p class="mt-2 text-sm text-slate-400">定期更新密码可提升账户安全性。</p>
              </div>
              <ArrowRight class="h-5 w-5 text-slate-500" />
            </button>
            <button type="button" class="card-hover club-panel-muted flex items-center justify-between p-5 text-left">
              <div>
                <p class="font-semibold text-white">账号设置</p>
                <p class="mt-2 text-sm text-slate-400">管理通知、隐私与后续账户偏好。</p>
              </div>
              <ArrowRight class="h-5 w-5 text-slate-500" />
            </button>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
