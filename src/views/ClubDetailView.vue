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
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex items-center justify-between gap-4 px-5 py-5 md:px-6">
        <button
          type="button"
          class="club-back-button inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold"
          @click="router.back()"
        >
          <ArrowLeft class="h-4 w-4" />
          返回社团列表
        </button>
        <button type="button" class="club-back-button flex h-11 w-11 items-center justify-center">
          <MessageSquare class="h-5 w-5" />
        </button>
      </header>

      <div v-if="loading" class="club-panel flex flex-col items-center justify-center py-20">
        <Loader2 class="h-10 w-10 animate-spin text-[#ecd7ad]" />
        <p class="mt-4 text-sm text-slate-400">正在加载社团详情...</p>
      </div>

      <main v-else-if="club" class="grid grid-cols-1 gap-6 xl:grid-cols-[1.08fr_0.92fr]">
        <section class="space-y-6">
          <article class="club-panel overflow-hidden p-2">
            <div class="relative overflow-hidden rounded-[28px]">
              <img
                :src="`https://picsum.photos/seed/${club.id}/1400/760`"
                :alt="club.name"
                class="h-[360px] w-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-[#050706] via-[#050706]/30 to-transparent" />
              <div class="absolute inset-x-0 bottom-0 p-8">
                <div class="flex flex-wrap items-center gap-3">
                  <span class="club-pill px-3 py-1 text-xs">活跃社团</span>
                  <span class="club-status-chip px-3 py-1 text-xs">{{ members.length }} 名成员</span>
                </div>
                <div class="mt-5 flex flex-col gap-5 md:flex-row md:items-end">
                  <div class="h-24 w-24 overflow-hidden rounded-[24px] border border-white/12 bg-white/10 p-1">
                    <img
                      :src="club.logo_url || `https://ui-avatars.com/api/?name=${club.name}&background=111515&color=F7F2EA&size=256`"
                      :alt="club.name"
                      class="h-full w-full rounded-[20px] object-cover"
                    />
                  </div>
                  <div>
                    <h1 class="font-display text-5xl font-bold text-white">{{ club.name }}</h1>
                    <p class="mt-2 max-w-2xl text-sm leading-7 text-white/78">
                      {{ club.description || '该社团正在完善介绍内容，欢迎先查看活动与成员信息。' }}
                    </p>
                  </div>
                </div>
              </div>
            </div>

            <div class="grid gap-4 p-6 md:grid-cols-2">
              <article class="club-panel-muted p-5">
                <div class="mb-3 flex items-center gap-2 text-[#ecd7ad]">
                  <Users class="h-5 w-5" />
                  <span class="text-sm font-medium">核心成员</span>
                </div>
                <div class="flex -space-x-3">
                  <img
                    v-for="m in members"
                    :key="m.id"
                    :src="m.profiles?.avatar_url || `https://ui-avatars.com/api/?name=${m.profiles?.full_name}&background=111515&color=F7F2EA`"
                    :alt="m.profiles?.full_name || '成员头像'"
                    class="h-12 w-12 rounded-full border-2 border-[#111515] object-cover"
                  />
                </div>
                <p class="mt-4 text-sm leading-6 text-slate-300">当前活跃在社团内部的成员将优先出现在这里。</p>
              </article>

              <article class="club-panel-muted p-5">
                <div class="mb-3 flex items-center gap-2 text-[#d9e7de]">
                  <ShieldCheck class="h-5 w-5" />
                  <span class="text-sm font-medium">认证信息</span>
                </div>
                <p class="text-sm text-slate-400">创建人</p>
                <p class="mt-1 text-lg font-semibold text-white">{{ club.profiles?.full_name || '未知' }}</p>
                <p class="mt-3 text-sm text-slate-400">创建时间</p>
                <p class="mt-1 text-lg font-semibold text-white">{{ new Date(club.created_at).toLocaleDateString() }}</p>
              </article>
            </div>
          </article>

          <section class="space-y-4">
            <div class="flex items-center justify-between px-1">
              <div>
                <p class="text-sm text-slate-400">Club Activities</p>
                <h2 class="mt-1 font-display text-3xl font-bold text-white">社团活动</h2>
              </div>
              <button type="button" class="text-sm font-medium text-[#ecd7ad]">查看全部活动</button>
            </div>

            <div v-if="activities.length === 0" class="club-empty-state p-12">
              <Calendar class="mx-auto h-12 w-12 text-slate-500" />
              <p class="mt-4 font-display text-3xl font-bold text-white">暂无近期活动</p>
            </div>

            <div v-else class="grid grid-cols-1 gap-5 md:grid-cols-2">
              <button
                v-for="act in activities"
                :key="act.id"
                type="button"
                @click="router.push(`/activity/${act.id}`)"
                class="card-hover club-panel-muted p-5 text-left"
              >
                <h3 class="font-display text-2xl font-bold text-white">{{ act.title }}</h3>
                <div class="mt-4 space-y-2 text-sm text-slate-400">
                  <p class="flex items-center gap-2">
                    <Calendar class="h-4 w-4" />
                    {{ new Date(act.start_time).toLocaleDateString() }}
                  </p>
                  <p class="flex items-center gap-2">
                    <MapPin class="h-4 w-4" />
                    {{ act.location || '校内' }}
                  </p>
                </div>
              </button>
            </div>
          </section>
        </section>

        <aside class="space-y-6">
          <section class="club-panel sticky top-6 p-6 md:p-8">
            <div class="mb-6">
              <p class="text-sm text-slate-400">Membership</p>
              <h3 class="mt-1 font-display text-3xl font-bold text-white">加入社团</h3>
            </div>

            <div
              v-if="message.text"
              :class="[
                'mb-6 rounded-2xl border px-4 py-3 text-sm leading-6',
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

            <div v-if="isMember" class="club-panel-muted p-6 text-center">
              <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-400/14 text-emerald-100">
                <ShieldCheck class="h-6 w-6" />
              </div>
              <h4 class="mt-4 text-lg font-semibold text-white">您已是该社团成员</h4>
              <p class="mt-2 text-sm text-slate-400">欢迎继续参与社团活动与内部协作。</p>
            </div>

            <div v-else-if="hasApplied" class="club-panel-muted p-6 text-center">
              <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-amber-400/14 text-amber-100">
                <Clock class="h-6 w-6" />
              </div>
              <h4 class="mt-4 text-lg font-semibold text-white">加入申请审核中</h4>
              <p class="mt-2 text-sm text-slate-400">请耐心等待管理员处理您的申请。</p>
            </div>

            <div v-else class="space-y-5">
              <div class="club-panel-muted p-5">
                <div class="mb-3 flex items-center gap-3 text-[#d9e7de]">
                  <Info class="h-5 w-5" />
                  <span class="text-sm font-medium">加入后可优先参与内部活动</span>
                </div>
                <p class="text-sm leading-7 text-slate-300">
                  成为成员后，你可以优先获取活动通知、内部资源和组织动态。
                </p>
              </div>
              <button
                type="button"
                @click="handleJoinRequest"
                :disabled="joining"
                class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
              >
                <Loader2 v-if="joining" class="h-5 w-5 animate-spin" />
                <template v-else>
                  <UserPlus class="h-5 w-5" />
                  填写加入申请
                </template>
              </button>
            </div>
          </section>

          <section class="club-panel-muted p-6">
            <h3 class="font-display text-2xl font-bold text-white">联系我们</h3>
            <p class="mt-3 text-sm leading-7 text-slate-300">
              对社团有任何疑问，欢迎前往留言区交流，或直接联系创建人了解更多细节。
            </p>
            <button type="button" class="club-button-secondary mt-5 w-full rounded-2xl px-5 py-4 text-sm font-semibold">
              发送私信
            </button>
          </section>
        </aside>
      </main>
    </div>
  </div>
</template>
