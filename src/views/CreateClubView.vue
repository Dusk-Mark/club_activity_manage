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
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-2xl mx-auto">
      <!-- 头部 -->
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          取消
        </button>
        <h1 class="text-xl font-bold text-slate-900">创建新社团</h1>
        <div class="w-20"></div>
      </header>

      <main>
        <section class="bg-white p-8 lg:p-12 rounded-[3rem] shadow-xl relative overflow-hidden">
          <div class="relative z-10">
            <div class="mb-10">
              <h2 class="text-3xl font-bold text-slate-900 mb-2">创建新的校园社团</h2>
              <p class="text-slate-500 font-medium">填写基础资料、上传标识与简介，建立统一的社团展示与管理入口。</p>
            </div>

            <form @submit.prevent="handleCreate" class="space-y-8">
              <!-- Logo 上传组件 -->
              <div class="flex justify-center mb-8">
                <ImageUpload 
                  v-model="clubForm.logo_url" 
                  bucket="avatars" 
                  folder="club-logos" 
                />
              </div>

              <!-- 基本信息 -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">社团名称</label>
                  <input v-model="clubForm.name" type="text" placeholder="例如：极客编程社" 
                         class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                </div>

                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">社团简介</label>
                  <textarea v-model="clubForm.description" rows="4" placeholder="向大家介绍一下您的社团吧..." 
                            class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700 resize-none"></textarea>
                </div>
              </div>

              <!-- 提示 -->
              <div class="p-5 bg-amber-50 rounded-2xl border border-amber-100 flex gap-4">
                <Info class="w-6 h-6 text-amber-500 flex-shrink-0" />
                <p class="text-xs text-amber-700 font-medium leading-relaxed">
                  温馨提示：创建社团后，您将自动成为该社团的“社团管理员”，可以开始发布活动并邀请社员加入。
                </p>
              </div>

              <!-- 提示信息 -->
              <div v-if="message.text" :class="['p-4 rounded-2xl text-sm font-bold', message.type === 'success' ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600']">
                {{ message.text }}
              </div>

              <button :disabled="loading" type="submit" 
                      class="w-full bg-primary hover:bg-primary-dark disabled:opacity-50 text-white py-5 rounded-[1.5rem] font-bold shadow-xl shadow-primary/20 transition-all flex items-center justify-center gap-2">
                <Loader2 v-if="loading" class="w-5 h-5 animate-spin" />
                <template v-else>
                  <Send class="w-5 h-5" />
                  提交创建申请
                </template>
              </button>
            </form>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
