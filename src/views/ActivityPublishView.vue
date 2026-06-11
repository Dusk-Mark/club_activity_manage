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
          <div class="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl border border-white/10 bg-white/92 p-1 shadow-[0_16px_28px_-18px_rgba(0,0,0,0.45)]">
            <img src="/%E4%B8%AD%E5%8C%97%E5%A4%A7%E5%AD%A6%E6%A0%A1%E5%BE%BD.png" alt="中北大学校徽" class="h-full w-full object-contain" />
          </div>
          <div>
            <p class="text-sm text-slate-400">Activity Studio</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>
        <span class="club-pill w-fit px-4 py-2 text-sm">活动编排入口</span>
      </header>

      <main class="club-panel p-6 md:p-8 lg:p-10">
        <div class="grid gap-8 lg:grid-cols-[0.88fr_1.12fr]">
          <section class="space-y-5">
            <div>
              <p class="text-sm text-slate-400">Publishing Brief</p>
              <h2 class="mt-1 font-display text-4xl font-bold text-white">建立一场可报名、可签到、可归档的校园活动</h2>
            </div>
            <p class="text-sm leading-7 text-slate-300">
              统一填写时间、地点、名额与活动说明，学生端将按此信息完成浏览、报名与后续参与。
            </p>

            <div class="club-panel-muted p-6">
              <div class="mb-4 flex items-center gap-3 text-[#d9e7de]">
                <Info class="h-5 w-5" />
                <span class="text-sm font-medium">发布后即进入协作链路</span>
              </div>
              <p class="text-sm leading-7 text-slate-300">
                活动发布后，报名申请、签到流程和反馈收集会自动围绕该活动展开，后续也可继续补充资料归档。
              </p>
            </div>
          </section>

          <section>
            <form @submit.prevent="handlePublish" class="space-y-5">
              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">发布社团</label>
                <div
                  v-if="pageMessage"
                  class="rounded-2xl border border-amber-400/20 bg-amber-400/10 px-4 py-3 text-sm leading-6 text-amber-100"
                >
                  {{ pageMessage }}
                </div>
                <select v-model="selectedClubId" class="club-input w-full px-5 py-4">
                  <option value="">请选择社团</option>
                  <option v-for="club in myClubs" :key="club.id" :value="club.id">{{ club.name }}</option>
                </select>
              </div>

              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">活动标题</label>
                <input
                  v-model="activityForm.title"
                  type="text"
                  placeholder="例如：春季草地音乐节"
                  class="club-input w-full px-5 py-4"
                />
              </div>

              <div class="grid gap-5 md:grid-cols-2">
                <div class="space-y-2">
                  <label class="text-sm font-medium text-slate-300">开始时间</label>
                  <div class="relative">
                    <Calendar class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                    <input
                      v-model="activityForm.start_time"
                      type="datetime-local"
                      class="club-input w-full py-4 pl-12 pr-4"
                    />
                  </div>
                </div>
                <div class="space-y-2">
                  <label class="text-sm font-medium text-slate-300">结束时间</label>
                  <div class="relative">
                    <Clock class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                    <input
                      v-model="activityForm.end_time"
                      type="datetime-local"
                      class="club-input w-full py-4 pl-12 pr-4"
                    />
                  </div>
                </div>
              </div>

              <div class="grid gap-5 md:grid-cols-2">
                <div class="space-y-2">
                  <label class="text-sm font-medium text-slate-300">活动地点</label>
                  <div class="relative">
                    <MapPin class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                    <input
                      v-model="activityForm.location"
                      type="text"
                      placeholder="校内大礼堂"
                      class="club-input w-full py-4 pl-12 pr-4"
                    />
                  </div>
                </div>
                <div class="space-y-2">
                  <label class="text-sm font-medium text-slate-300">招募名额</label>
                  <div class="relative">
                    <Users class="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-slate-500" />
                    <input
                      v-model.number="activityForm.max_participants"
                      type="number"
                      class="club-input w-full py-4 pl-12 pr-4"
                    />
                  </div>
                </div>
              </div>

              <div class="space-y-2">
                <label class="text-sm font-medium text-slate-300">活动内容详情</label>
                <textarea
                  v-model="activityForm.description"
                  rows="6"
                  placeholder="详细介绍活动流程、要求以及参与方式..."
                  class="club-input w-full resize-none px-5 py-4"
                />
              </div>

              <button
                :disabled="loading"
                type="submit"
                class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
              >
                <Loader2 v-if="loading" class="h-5 w-5 animate-spin" />
                <template v-else>
                  <Send class="h-5 w-5" />
                  确认发布活动
                </template>
              </button>
            </form>
          </section>
        </div>
      </main>
    </div>
  </div>
</template>
