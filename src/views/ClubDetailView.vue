<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { 
  ArrowLeft, 
  Users, 
  Calendar, 
  MapPin, 
  Clock, 
  CheckCircle2, 
  Loader2,
  ShieldCheck,
  UserPlus,
  Info,
  MessageSquare
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const clubId = route.params.id as string
const club = ref<any>(null)
const members = ref<any[]>([])
const activities = ref<any[]>([])
const loading = ref(true)
const joining = ref(false)
const isMember = ref(false)
const hasApplied = ref(false)
const message = ref({ text: '', type: '' })

const fetchClubData = async () => {
  loading.value = true
  try {
    // 1. 获取社团基础信息
    const { data: clubData, error: clubError } = await supabase
      .from('clubs')
      .select('*, profiles(full_name)')
      .eq('id', clubId)
      .single()
    
    if (clubError) throw clubError
    club.value = clubData

    // 2. 获取社员列表
    const { data: membersData } = await supabase
      .from('club_members')
      .select('*, profiles(full_name, avatar_url, username)')
      .eq('club_id', clubId)
      .limit(6)
    members.value = membersData || []

    // 3. 获取社团活动
    const { data: activitiesData } = await supabase
      .from('activities')
      .select('*')
      .eq('club_id', clubId)
      .order('start_time', { ascending: false })
      .limit(3)
    activities.value = activitiesData || []

    // 4. 检查当前用户身份
    if (authStore.user) {
      const { data: memberData } = await supabase
        .from('club_members')
        .select('*')
        .eq('club_id', clubId)
        .eq('user_id', authStore.user.id)
        .single()
      
      if (memberData) isMember.value = true

      // 检查是否有待审核申请 (假设 user_applications 表中有 type 为 'join_club')
      const { data: applyData } = await supabase
        .from('user_applications')
        .select('*')
        .eq('user_id', authStore.user.id)
        .contains('content', { club_id: clubId })
        .eq('status', 'pending')
        .single()
      
      if (applyData) hasApplied.value = true
    }
  } catch (error: any) {
    console.error('Error fetching club details:', error.message)
    router.push('/clubs')
  } finally {
    loading.value = false
  }
}

const handleJoinRequest = async () => {
  if (!authStore.user) {
    router.push('/')
    return
  }

  router.push({
    path: '/applications',
    query: {
      type: 'join_club',
      clubId
    }
  })
}

onMounted(async () => {
  await authStore.ensureUser()
  fetchClubData()
})
</script>

<template>
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-6xl mx-auto">
      <!-- 头部导航 -->
      <header class="flex items-center justify-between mb-10">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回社团列表
        </button>
        <div class="flex items-center gap-3">
          <button class="p-3 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:text-primary transition-all">
            <MessageSquare class="w-5 h-5" />
          </button>
        </div>
      </header>

      <div v-if="loading" class="flex flex-col items-center justify-center py-20">
        <Loader2 class="w-10 h-10 animate-spin text-primary" />
        <p class="mt-4 text-slate-400 font-bold">正在加载社团详情...</p>
      </div>

      <main v-else-if="club" class="grid grid-cols-1 lg:grid-cols-12 gap-8">
        <!-- 左侧：社团概览与详情 -->
        <div class="lg:col-span-8 space-y-8">
          <!-- 封面卡片 -->
          <section class="bg-white p-2 rounded-[3.5rem] shadow-xl overflow-hidden">
            <div class="h-64 md:h-80 w-full rounded-[3rem] overflow-hidden relative">
              <img :src="`https://picsum.photos/seed/${club.id}/1200/400`" class="w-full h-full object-cover" />
              <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>
              <div class="absolute bottom-8 left-8 flex items-end gap-6">
                <div class="w-24 h-24 rounded-[2rem] bg-white p-1 shadow-2xl border-4 border-white/20 overflow-hidden">
                  <img :src="club.logo_url || `https://ui-avatars.com/api/?name=${club.name}&background=random&size=128`" class="w-full h-full object-cover rounded-[1.8rem]" />
                </div>
                <div class="mb-2">
                  <h1 class="text-4xl font-bold text-white mb-2">{{ club.name }}</h1>
                  <div class="flex items-center gap-3">
                    <span class="px-3 py-1 bg-white/20 backdrop-blur-md text-white text-[10px] font-bold rounded-full uppercase tracking-widest">
                      活跃中
                    </span>
                    <span class="text-white/80 text-xs font-bold flex items-center gap-1">
                      <Users class="w-3.5 h-3.5" /> {{ members.length }} 名成员
                    </span>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="p-10">
              <h2 class="text-xl font-bold text-slate-900 mb-4">社团简介</h2>
              <p class="text-slate-500 leading-relaxed whitespace-pre-wrap mb-10">
                {{ club.description || '该社团暂无详细介绍，欢迎加入后一起丰富它！' }}
              </p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-8 pt-8 border-t border-slate-50">
                <div>
                  <h3 class="font-bold text-slate-800 mb-4 flex items-center gap-2">
                    <Users class="text-primary w-5 h-5" /> 核心成员
                  </h3>
                  <div class="flex -space-x-3 mb-4">
                    <img v-for="m in members" :key="m.id" 
                         :src="m.profiles?.avatar_url || `https://ui-avatars.com/api/?name=${m.profiles?.full_name}&background=random`" 
                         class="w-12 h-12 rounded-full border-4 border-white object-cover shadow-sm" />
                    <div v-if="members.length >= 6" class="w-12 h-12 rounded-full bg-slate-100 border-4 border-white flex items-center justify-center text-slate-400 text-xs font-bold">
                      +
                    </div>
                  </div>
                  <p class="text-xs text-slate-400 font-medium">当前活跃在社团内的伙伴们</p>
                </div>

                <div>
                  <h3 class="font-bold text-slate-800 mb-4 flex items-center gap-2">
                    <ShieldCheck class="text-emerald-500 w-5 h-5" /> 认证信息
                  </h3>
                  <div class="space-y-2">
                    <div class="text-sm font-bold text-slate-600">创建人：{{ club.profiles?.full_name }}</div>
                    <div class="text-xs text-slate-400 font-medium">认证时间：{{ new Date(club.created_at).toLocaleDateString() }}</div>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <!-- 社团动态/活动 -->
          <section>
            <div class="flex items-center justify-between mb-6 px-4">
              <h3 class="text-2xl font-bold text-slate-900">社团活动</h3>
              <button class="text-sm font-bold text-primary hover:underline">查看全部活动</button>
            </div>
            
            <div v-if="activities.length === 0" class="bg-white p-12 rounded-[3rem] shadow-xl text-center text-slate-300">
              <Calendar class="w-12 h-12 mx-auto mb-4" />
              <p class="font-bold">暂无近期活动</p>
            </div>
            
            <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div v-for="act in activities" :key="act.id" 
                   @click="router.push(`/activity/${act.id}`)"
                   class="bg-white p-6 rounded-[2.5rem] shadow-lg hover:shadow-xl transition-all cursor-pointer group">
                <h4 class="font-bold text-slate-800 text-lg mb-3 group-hover:text-primary transition-colors">{{ act.title }}</h4>
                <div class="space-y-2">
                  <div class="flex items-center gap-2 text-xs text-slate-400 font-medium">
                    <Calendar class="w-3.5 h-3.5" /> {{ new Date(act.start_time).toLocaleDateString() }}
                  </div>
                  <div class="flex items-center gap-2 text-xs text-slate-400 font-medium">
                    <MapPin class="w-3.5 h-3.5" /> {{ act.location || '校内' }}
                  </div>
                </div>
              </div>
            </div>
          </section>
        </div>

        <!-- 右侧：操作与状态 -->
        <aside class="lg:col-span-4 space-y-6">
          <section class="bg-white p-8 rounded-[3rem] shadow-xl sticky top-8">
            <h3 class="font-bold text-xl mb-6">加入社团</h3>
            
            <div v-if="message.text" :class="['p-4 rounded-2xl text-sm font-bold flex items-center gap-2 mb-6', message.type === 'success' ? 'bg-emerald-50 text-emerald-600' : 'bg-red-50 text-red-600']">
              <CheckCircle2 v-if="message.type === 'success'" class="w-5 h-5" />
              {{ message.text }}
            </div>

            <div v-if="isMember" class="bg-emerald-50 p-6 rounded-[2rem] border border-emerald-100 text-center">
              <div class="w-12 h-12 bg-emerald-500 text-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-emerald-500/20">
                <ShieldCheck class="w-6 h-6" />
              </div>
              <h4 class="font-bold text-emerald-700 mb-1">您已是该社团成员</h4>
              <p class="text-xs text-emerald-600/80 font-medium">欢迎参与我们的活动！</p>
            </div>

            <div v-else-if="hasApplied" class="bg-amber-50 p-6 rounded-[2rem] border border-amber-100 text-center">
              <div class="w-12 h-12 bg-amber-500 text-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-amber-500/20">
                <Clock class="w-6 h-6" />
              </div>
              <h4 class="font-bold text-amber-700 mb-1">加入申请审核中</h4>
              <p class="text-xs text-amber-600/80 font-medium">请耐心等待管理员处理您的申请。</p>
            </div>

            <div v-else class="space-y-6">
              <div class="p-5 bg-blue-50 rounded-[2rem] border border-blue-100 flex gap-4">
                <Info class="w-6 h-6 text-blue-500 flex-shrink-0" />
                <p class="text-xs text-blue-700 font-medium leading-relaxed">
                  加入社团后，您可以优先报名该社团的各类活动，并获得内部专属资源。
                </p>
              </div>
              <button 
                @click="handleJoinRequest"
                :disabled="joining"
                class="w-full bg-primary hover:bg-primary-dark disabled:opacity-50 text-white py-5 rounded-[2rem] font-bold shadow-xl shadow-primary/20 transition-all flex items-center justify-center gap-2"
              >
                <Loader2 v-if="joining" class="w-5 h-5 animate-spin" />
                <template v-else>
                  <UserPlus class="w-5 h-5" />
                  填写加入申请
                </template>
              </button>
            </div>
          </section>

          <!-- 快速反馈 -->
          <section class="bg-slate-900 p-8 rounded-[3rem] shadow-xl text-white">
            <h3 class="font-bold text-lg mb-4">联系我们</h3>
            <p class="text-slate-400 text-sm mb-6 leading-relaxed">对社团有任何疑问？欢迎在留言板留言或直接联系创建人。</p>
            <button class="w-full py-4 bg-white/10 hover:bg-white/20 rounded-2xl text-sm font-bold transition-all border border-white/5">发送私信</button>
          </section>
        </aside>
      </main>
    </div>
  </div>
</template>
