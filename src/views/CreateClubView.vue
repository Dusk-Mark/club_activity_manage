<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import ImageUpload from '../components/ImageUpload.vue'
import { 
  ArrowLeft, 
  Send, 
  Loader2,
  Info
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const clubForm = ref({
  name: '',
  description: '',
  logo_url: ''
})
const message = ref({ text: '', type: '' })

const handleCreate = async () => {
  const user = await authStore.ensureUser()
  if (!user) {
    router.push('/')
    return
  }

  // 增加角色校验
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  
  if (profile?.role !== 'league_committee' && profile?.role !== 'admin') {
    message.value = { text: '权限不足：只有校团委老师可以创建新社团', type: 'error' }
    return
  }

  if (!clubForm.value.name || !clubForm.value.description) {
    message.value = { text: '请填写社团名称和简介', type: 'error' }
    return
  }

  loading.value = true
  message.value = { text: '', type: '' }

  try {
    const { data: newClub, error } = await supabase
      .from('clubs')
      .insert({
        name: clubForm.value.name,
        description: clubForm.value.description,
        logo_url: clubForm.value.logo_url,
        creator_id: user.id,
        status: 'active' // 默认设为活跃，实际项目中可能需要审核
      })
      .select('id')
      .single()

    if (error) throw error
    
    // 成功后自动将创建者设为社团管理员
    const { error: memberError } = await supabase.from('club_members').insert({
      club_id: newClub.id,
      user_id: user.id,
      role: 'admin'
    })

    if (memberError) throw memberError

    message.value = { text: '社团创建成功！正在跳转...', type: 'success' }
    setTimeout(() => {
      router.push('/dashboard')
    }, 1500)
  } catch (error: any) {
    message.value = { text: error.message || '创建失败', type: 'error' }
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  await authStore.ensureUser()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-4xl space-y-6">
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
            <p class="text-sm text-slate-400">Create Organization</p>
            <h1 class="font-display text-3xl font-bold text-white">创建新社团</h1>
          </div>
        </div>
        <span class="club-pill w-fit px-4 py-2 text-sm">校团委创建入口</span>
      </header>

      <main class="club-panel p-6 md:p-8 lg:p-10">
        <div class="grid gap-8 lg:grid-cols-[0.82fr_1.18fr]">
          <section class="space-y-5">
            <div>
              <p class="text-sm text-slate-400">Founding Notes</p>
              <h2 class="mt-1 font-display text-4xl font-bold text-white">建立新的校园组织档案</h2>
            </div>
            <p class="text-sm leading-7 text-slate-300">
              填写社团名称、简介与标识后，系统会生成统一的展示入口，并自动建立后续成员与活动管理基础。
            </p>

            <div class="club-panel-muted p-6">
              <div class="mb-4 flex items-center gap-3 text-[#ecd7ad]">
                <Info class="h-5 w-5" />
                <span class="text-sm font-medium">创建后自动授予管理权限</span>
              </div>
              <p class="text-sm leading-7 text-slate-300">
                创建成功后，当前账号会自动成为该社团的社团管理员，可继续发布活动、管理成员和处理报名。
              </p>
            </div>

            <div class="club-panel-muted flex items-center justify-center p-6">
              <ImageUpload
                v-model="clubForm.logo_url"
                bucket="avatars"
                folder="club-logos"
              />
            </div>
          </section>

          <section>
            <form @submit.prevent="handleCreate" class="space-y-5">
              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">社团名称</label>
                <input
                  v-model="clubForm.name"
                  type="text"
                  placeholder="例如：极客编程社"
                  class="club-input w-full px-5 py-4"
                />
              </div>

              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">社团简介</label>
                <textarea
                  v-model="clubForm.description"
                  rows="6"
                  placeholder="向大家介绍一下您的社团吧..."
                  class="club-input w-full resize-none px-5 py-4"
                />
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
                {{ message.text }}
              </div>

              <button
                :disabled="loading"
                type="submit"
                class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
              >
                <Loader2 v-if="loading" class="h-5 w-5 animate-spin" />
                <template v-else>
                  <Send class="h-5 w-5" />
                  提交创建申请
                </template>
              </button>
            </form>
          </section>
        </div>
      </main>
    </div>
  </div>
</template>
