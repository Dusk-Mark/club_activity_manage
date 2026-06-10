<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import { 
  ArrowLeft, 
  Send, 
  Calendar, 
  Clock, 
  MapPin, 
  Users, 
  Loader2,
  Info
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()
const loading = ref(false)
const pageMessage = ref('')
const myClubs = ref<any[]>([])
const selectedClubId = ref('')
const userRole = ref<'student' | 'club_admin' | 'league_committee' | 'admin'>('student')

type ClubOption = {
  id: string
  name: string
}

const activityForm = ref({
  title: '',
  description: '',
  start_time: '',
  end_time: '',
  location: '',
  max_participants: 50,
  status: 'recruiting' as 'draft' | 'recruiting' | 'ongoing' | 'ended'
})

const normalizeClubOptions = (items: any[]): ClubOption[] => {
  const seen = new Set<string>()

  return items.filter((item): item is ClubOption => {
    if (!item?.id || !item?.name || seen.has(item.id)) {
      return false
    }

    seen.add(item.id)
    return true
  })
}

const fetchMyClubs = async () => {
  if (!authStore.user) return
  pageMessage.value = ''

  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', authStore.user.id)
    .maybeSingle()

  if (profileError) {
    throw profileError
  }

  userRole.value = (profile?.role || 'student') as typeof userRole.value

  if (userRole.value === 'league_committee' || userRole.value === 'admin') {
    const { data: clubData, error: clubError } = await supabase
      .from('clubs')
      .select('id, name')
      .order('created_at', { ascending: false })

    if (clubError) {
      throw clubError
    }

    myClubs.value = clubData || []
  } else {
    const { data: membershipData, error: membershipError } = await supabase
      .from('club_members')
      .select('club_id, role, clubs(id, name)')
      .eq('user_id', authStore.user.id)

    if (membershipError) {
      throw membershipError
    }

    const memberships = membershipData || []
    const managedClubs = memberships
      .filter(item => ['admin', 'leader'].includes(item.role))
      .map(item => item.clubs)

    if (managedClubs.length > 0) {
      myClubs.value = normalizeClubOptions(managedClubs)
    } else if (userRole.value === 'club_admin') {
      // 兼容 profiles.role 已设为 club_admin，但 club_members.role 尚未同步的场景。
      myClubs.value = normalizeClubOptions(
        memberships.map(item => item.clubs)
      )

      if (myClubs.value.length > 0) {
        pageMessage.value = '已按社团管理员身份加载你加入的社团；如需更细权限控制，请同步社团成员身份。'
      }
    } else {
      myClubs.value = []
    }
  }

  if (myClubs.value.length > 0) {
    selectedClubId.value = myClubs.value[0].id
  } else {
    selectedClubId.value = ''
    pageMessage.value = userRole.value === 'student'
      ? '你当前没有可发布活动的社团管理权限。'
      : '当前未获取到可发布活动的社团，请检查社团数据或成员身份。'
  }
}

const handlePublish = async () => {
  if (!selectedClubId.value || !activityForm.value.title) {
    alert('请选择社团并填写活动标题')
    return
  }

  loading.value = true
  try {
    const { error } = await supabase
      .from('activities')
      .insert({
        club_id: selectedClubId.value,
        title: activityForm.value.title,
        description: activityForm.value.description,
        start_time: activityForm.value.start_time,
        end_time: activityForm.value.end_time,
        location: activityForm.value.location,
        max_participants: activityForm.value.max_participants,
        status: activityForm.value.status
      })

    if (error) throw error
    alert('活动发布成功！')
    router.push('/dashboard')
  } catch (error: any) {
    alert('发布失败: ' + error.message)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  try {
    await authStore.ensureUser()
    await fetchMyClubs()
  } catch (error: any) {
    pageMessage.value = error?.message || '社团信息加载失败，请稍后重试。'
  }
})
</script>

<template>
  <div class="min-h-screen bg-wanderlust p-4 lg:p-8">
    <div class="max-w-3xl mx-auto">
      <header class="flex items-center justify-between mb-8">
        <button @click="router.back()" class="flex items-center gap-2 px-4 py-2 bg-white/80 backdrop-blur-md rounded-full shadow-sm hover:shadow-md transition-all font-bold text-slate-600">
          <ArrowLeft class="w-5 h-5" />
          返回
        </button>
        <h1 class="text-xl font-bold text-slate-900">发布新活动</h1>
        <div class="w-20"></div>
      </header>

      <main>
        <section class="bg-white p-8 lg:p-12 rounded-[3rem] shadow-xl relative overflow-hidden">
          <div class="relative z-10">
            <div class="mb-10">
              <h2 class="text-3xl font-bold text-slate-900 mb-2">发布新的校园活动</h2>
              <p class="text-slate-500 font-medium">统一填写时间、地点、名额与活动内容，让社团成员更快完成报名与参与。</p>
            </div>

            <form @submit.prevent="handlePublish" class="space-y-8">
              <!-- 选择社团 -->
              <div class="space-y-2">
                <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">发布社团</label>
                <div v-if="pageMessage" class="rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-700">
                  {{ pageMessage }}
                </div>
                <select v-model="selectedClubId" 
                        class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700 appearance-none">
                  <option value="">请选择社团</option>
                  <option v-for="club in myClubs" :key="club.id" :value="club.id">{{ club.name }}</option>
                </select>
              </div>

              <!-- 基本信息 -->
              <div class="space-y-6">
                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">活动标题</label>
                  <input v-model="activityForm.title" type="text" placeholder="例如：春季草地音乐节" 
                         class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="space-y-2">
                    <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">开始时间</label>
                    <div class="relative flex items-center">
                      <Calendar class="absolute left-4 w-5 h-5 text-slate-300" />
                      <input v-model="activityForm.start_time" type="datetime-local" 
                             class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                    </div>
                  </div>
                  <div class="space-y-2">
                    <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">结束时间</label>
                    <div class="relative flex items-center">
                      <Clock class="absolute left-4 w-5 h-5 text-slate-300" />
                      <input v-model="activityForm.end_time" type="datetime-local" 
                             class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                    </div>
                  </div>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                  <div class="space-y-2">
                    <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">活动地点</label>
                    <div class="relative flex items-center">
                      <MapPin class="absolute left-4 w-5 h-5 text-slate-300" />
                      <input v-model="activityForm.location" type="text" placeholder="校内大礼堂" 
                             class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                    </div>
                  </div>
                  <div class="space-y-2">
                    <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">招募名额</label>
                    <div class="relative flex items-center">
                      <Users class="absolute left-4 w-5 h-5 text-slate-300" />
                      <input v-model.number="activityForm.max_participants" type="number" 
                             class="w-full pl-12 pr-4 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700" />
                    </div>
                  </div>
                </div>

                <div class="space-y-2">
                  <label class="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">活动内容详情</label>
                  <textarea v-model="activityForm.description" rows="5" placeholder="详细介绍活动的流程、要求以及参与方式..." 
                            class="w-full px-6 py-4 bg-slate-50 border border-slate-100 rounded-2xl focus:bg-white focus:border-primary/30 outline-none transition-all font-bold text-slate-700 resize-none"></textarea>
                </div>
              </div>

              <div class="p-5 bg-blue-50 rounded-2xl border border-blue-100 flex gap-4">
                <Info class="w-6 h-6 text-blue-500 flex-shrink-0" />
                <p class="text-xs text-blue-700 font-medium leading-relaxed">
                  提示：活动发布后将立即对全校学生可见，您可以在管理后台查看报名名单并进行审核。
                </p>
              </div>

              <button :disabled="loading" type="submit" 
                      class="w-full bg-slate-900 text-white py-5 rounded-[1.5rem] font-bold shadow-xl transition-all flex items-center justify-center gap-2 hover:bg-slate-800 disabled:opacity-50">
                <Loader2 v-if="loading" class="w-5 h-5 animate-spin" />
                <template v-else>
                  <Send class="w-5 h-5" />
                  确认发布活动
                </template>
              </button>
            </form>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
