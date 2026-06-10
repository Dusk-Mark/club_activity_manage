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
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-3xl mx-auto">
      <!-- 头部 -->
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">个人中心</h1>
        <div class="w-20"></div> <!-- 占位平衡 -->
      </header>

      <main class="space-y-6">
        <!-- 基础资料卡片 -->
        <section class="bg-white p-8 lg:p-12 rounded-[3rem] shadow-xl relative overflow-hidden">
          <div class="relative z-10">
            <!-- 头像部分 -->
            <div class="flex flex-col items-center mb-10">
              <div class="relative group">
                <div class="w-32 h-32 rounded-[2.5rem] bg-slate-100 overflow-hidden border-4 border-white shadow-lg">
                  <img :src="profile.avatar_url || `https://ui-avatars.com/api/?name=${profile.full_name || 'User'}&background=random&size=128`" 
                       class="w-full h-full object-cover" />
                </div>
                <button class="absolute bottom-0 right-0 bg-primary text-white p-3 rounded-2xl shadow-lg hover:scale-110 transition-transform">
                  <Camera class="w-5 h-5" />
                </button>
              </div>
              <div class="mt-4 text-center">
                <h2 class="text-2xl font-bold text-slate-900">{{ profile.full_name || '未设置姓名' }}</h2>
                <div class="flex items-center gap-2 justify-center mt-1">
                  <span class="px-3 py-1 bg-primary/10 text-primary text-[10px] font-bold rounded-full uppercase tracking-widest">
                    {{ profile.role === 'student' ? '学生' : profile.role }}
                  </span>
                </div>
              </div>
            </div>

            <!-- 表单部分 -->
            <form @submit.prevent="handleUpdate" class="space-y-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">真实姓名</label>
                  <div class="relative flex items-center">
                    <UserIcon class="absolute left-4 w-5 h-5 text-slate-300" />
                    <input v-model="profile.full_name" type="text" placeholder="请输入姓名" 
                           class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                  </div>
                </div>

                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">用户名</label>
                  <div class="relative flex items-center">
                    <Tag class="absolute left-4 w-5 h-5 text-slate-300" />
                    <input v-model="profile.username" type="text" placeholder="设置用户名" 
                           class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                  </div>
                </div>

                <div class="space-y-2 md:col-span-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">电子邮箱 (不可修改)</label>
                  <div class="relative flex items-center">
                    <Mail class="absolute left-4 w-5 h-5 text-slate-300" />
                    <input :value="authStore.user?.email" disabled type="email" 
                           class="w-full pl-12 pr-4 py-4 bg-slate-100 border border-slate-100 rounded-2xl outline-none font-bold text-slate-400 cursor-not-allowed" />
                  </div>
                </div>
              </div>

              <!-- 提示信息 -->
              <div v-if="message.text" :class="['p-4 rounded-2xl text-sm font-bold flex items-center gap-2', message.type === 'success' ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600']">
                <CheckCircle2 v-if="message.type === 'success'" class="w-5 h-5" />
                {{ message.text }}
              </div>

              <button :disabled="loading" type="submit" 
                      class="w-full bg-slate-900 hover:bg-slate-800 disabled:opacity-50 text-white py-5 rounded-[1.5rem] font-bold shadow-xl transition-all flex items-center justify-center gap-2">
                <Loader2 v-if="loading" class="w-5 h-5 animate-spin" />
                <template v-else>
                  <Save class="w-5 h-5" />
                  保存更改
                </template>
              </button>
            </form>
          </div>
        </section>

        <!-- 其他操作 -->
        <section class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div class="bg-white p-6 rounded-[2rem] shadow-lg border border-slate-50 flex items-center justify-between group cursor-pointer">
            <div>
              <div class="font-bold text-slate-800">修改密码</div>
              <div class="text-xs text-slate-400 font-medium">定期更换密码更安全</div>
            </div>
            <div class="p-3 bg-slate-50 rounded-xl group-hover:bg-primary group-hover:text-white transition-all">
              <ArrowRight class="w-5 h-5" />
            </div>
          </div>
          <div class="bg-white p-6 rounded-[2rem] shadow-lg border border-slate-50 flex items-center justify-between group cursor-pointer">
            <div>
              <div class="font-bold text-slate-800">账号设置</div>
              <div class="text-xs text-slate-400 font-medium">管理您的隐私与通知</div>
            </div>
            <div class="p-3 bg-slate-50 rounded-xl group-hover:bg-primary group-hover:text-white transition-all">
              <ArrowRight class="w-5 h-5" />
            </div>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
