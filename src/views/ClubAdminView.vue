<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowLeft,
  CheckCircle2,
  Clock3,
  Loader2,
  ShieldCheck,
  UserPlus,
  Users,
  WalletCards,
  XCircle
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const activeTab = ref<'applications' | 'registrations'>('applications')
const myClubs = ref<any[]>([])
const clubApplications = ref<any[]>([])
const registrations = ref<any[]>([])
const selectedClubId = ref<string | null>(null)
const operationMessage = ref('')
const userRole = ref<'student' | 'club_admin' | 'league_committee' | 'admin'>('student')

const normalizeClubs = (items: any[]) => {
  const seen = new Set<string>()

  return items.filter((item: any) => {
    if (!item?.id || seen.has(item.id)) {
      return false
    }

    seen.add(item.id)
    return true
  })
}

const selectedClub = computed(() => {
  return myClubs.value.find(item => item.id === selectedClubId.value) || null
})

const overviewStats = computed(() => [
  {
    title: '待处理社团申请',
    value: `${clubApplications.value.length}`,
    icon: UserPlus,
    tone: 'text-[#f2ddae]'
  },
  {
    title: '待审活动报名',
    value: `${registrations.value.length}`,
    icon: CheckCircle2,
    tone: 'text-emerald-300'
  },
  {
    title: '当前管理社团',
    value: `${myClubs.value.length}`,
    icon: ShieldCheck,
    tone: 'text-[#9fc0f7]'
  }
])

const fetchMyClubs = async () => {
  if (!authStore.user) return

  const [{ data: profile, error: profileError }, { data, error }] = await Promise.all([
    supabase
      .from('profiles')
      .select('role')
      .eq('id', authStore.user.id)
      .maybeSingle(),
    supabase
      .from('club_members')
      .select('club_id, role, clubs(id, name, description)')
      .eq('user_id', authStore.user.id)
  ])

  if (profileError) throw profileError
  if (error) throw error

  userRole.value = (profile?.role || 'student') as typeof userRole.value

  const memberships = data || []
  const managedClubs = memberships
    .filter(item => item.role === 'admin')
    .map(item => item.clubs)

  if (managedClubs.length > 0) {
    myClubs.value = normalizeClubs(managedClubs)
  } else if (userRole.value === 'club_admin') {
    myClubs.value = normalizeClubs(memberships.map(item => item.clubs))
  } else {
    myClubs.value = []
  }

  if (!selectedClubId.value && myClubs.value.length) {
    selectedClubId.value = myClubs.value[0].id
  }
}

const fetchQueues = async () => {
  if (!selectedClubId.value) {
    loading.value = false
    return
  }

  loading.value = true
  operationMessage.value = ''

  try {
    const [{ data: appData, error: appError }, { data: regData, error: regError }] = await Promise.all([
      supabase
        .from('user_applications')
        .select('*, profiles(full_name, avatar_url, username), application_types(name)')
        .eq('status', 'pending')
        .order('created_at', { ascending: false }),
      supabase
        .from('activity_registrations')
        .select('*, profiles(full_name, avatar_url, username), activities(title, club_id, start_time, location)')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
    ])

    if (appError) throw appError
    if (regError) throw regError

    clubApplications.value = (appData || []).filter(item =>
      item.content?.club_id === selectedClubId.value
    )
    registrations.value = (regData || []).filter(item => item.activities?.club_id === selectedClubId.value)
  } finally {
    loading.value = false
  }
}

const handleApplicationDecision = async (application: any, status: 'approved' | 'rejected') => {
  try {
    if (status === 'approved' && application.content?.application_key === 'join_club') {
      const { error: memberError } = await supabase
        .from('club_members')
        .upsert({
          club_id: application.content?.club_id,
          user_id: application.user_id,
          role: 'member'
        }, {
          onConflict: 'club_id,user_id'
        })

      if (memberError) throw memberError
    }

    const { error } = await supabase
      .from('user_applications')
      .update({
        status,
        admin_remark: status === 'approved' ? '社团管理员已处理该申请。' : '社团管理员已驳回该申请。'
      })
      .eq('id', application.id)

    if (error) throw error

    clubApplications.value = clubApplications.value.filter(item => item.id !== application.id)
    operationMessage.value = status === 'approved' ? '申请已通过。' : '申请已驳回。'
  } catch (error: any) {
    operationMessage.value = error.message || '处理申请失败。'
  }
}

const handleRegistrationDecision = async (registration: any, status: 'approved' | 'rejected') => {
  try {
    const { error } = await supabase
      .from('activity_registrations')
      .update({ status })
      .eq('id', registration.id)

    if (error) throw error

    registrations.value = registrations.value.filter(item => item.id !== registration.id)
    operationMessage.value = status === 'approved' ? '报名已通过。' : '报名已拒绝。'
  } catch (error: any) {
    operationMessage.value = error.message || '处理报名失败。'
  }
}

onMounted(async () => {
  try {
    await authStore.ensureUser()

    await fetchMyClubs()

    if (!myClubs.value.length) {
      loading.value = false
      return
    }

    await fetchQueues()
  } catch (error) {
    loading.value = false
    console.error('Error loading club admin view:', error)
  }
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:px-6 xl:flex-row xl:items-center xl:justify-between">
        <div class="flex items-center gap-4">
          <button
            type="button"
            class="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/8 bg-white/5 text-slate-200"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div class="flex h-12 w-12 items-center justify-center overflow-hidden rounded-2xl border border-white/10 bg-white/92 p-1 shadow-[0_16px_28px_-18px_rgba(0,0,0,0.45)]">
            <img src="/%E4%B8%AD%E5%8C%97%E5%A4%A7%E5%AD%A6%E6%A0%A1%E5%BE%BD.png" alt="中北大学校徽" class="h-full w-full object-contain" />
          </div>
          <div>
            <p class="text-sm text-slate-400">Club Workflow</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">社团事务审批</span>
          <span class="rounded-full border border-white/8 px-4 py-2">活动报名审批</span>
          <span class="rounded-full border border-white/8 px-4 py-2">流程留痕</span>
        </div>
      </header>

      <div v-if="myClubs.length === 0 && !loading" class="club-panel p-10 text-center">
        <Users class="mx-auto h-14 w-14 text-slate-500" />
        <h2 class="mt-5 font-display text-3xl font-bold text-white">您暂时没有可管理的社团</h2>
        <p class="mx-auto mt-3 max-w-xl text-sm leading-6 text-slate-400">
          只有被设为社团管理员的账号才能进入此处处理加入社团和活动报名等审批流程。
        </p>
        <button
          type="button"
          class="club-button-primary mt-6 rounded-2xl px-6 py-4 text-sm font-semibold"
          @click="router.push('/create-club')"
        >
          前往创建社团
        </button>
      </div>

      <div v-else class="grid gap-6 xl:grid-cols-[0.9fr_1.1fr]">
        <aside class="space-y-6">
          <section class="club-panel p-6">
            <p class="text-sm text-slate-400">Managed Clubs</p>
            <h3 class="mt-1 font-display text-2xl font-bold text-white">我的管理范围</h3>

            <div class="mt-5 space-y-3">
              <button
                v-for="club in myClubs"
                :key="club.id"
                type="button"
                class="card-hover flex w-full items-center justify-between rounded-[20px] border px-4 py-4 text-left transition-all"
                :class="selectedClubId === club.id
                  ? 'border-[#e7d29c]/30 bg-[#e7d29c]/10'
                  : 'border-white/8 bg-white/[0.03]'"
                @click="selectedClubId = club.id; fetchQueues()"
              >
                <div>
                  <p class="font-semibold text-white">{{ club.name }}</p>
                  <p class="mt-1 line-clamp-2 text-sm leading-6 text-slate-400">
                    {{ club.description || '用于审批成员申请和活动报名。' }}
                  </p>
                </div>
                <ShieldCheck class="h-5 w-5 text-[#f2ddae]" />
              </button>
            </div>
          </section>

          <section class="club-panel p-6">
            <p class="text-sm text-slate-400">Overview</p>
            <div class="mt-5 grid gap-4">
              <article v-for="item in overviewStats" :key="item.title" class="club-panel-muted p-5">
                <component :is="item.icon" class="h-5 w-5" :class="item.tone" />
                <p class="mt-3 font-display text-3xl font-bold text-white">{{ item.value }}</p>
                <p class="mt-2 text-sm text-slate-400">{{ item.title }}</p>
              </article>
            </div>
          </section>
        </aside>

        <main class="space-y-6">
          <section class="club-panel p-6 md:p-8">
            <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
              <div>
                <p class="text-sm text-slate-400">Approval Queue</p>
                <h2 class="mt-1 font-display text-3xl font-bold text-white">
                  {{ selectedClub?.name || '社团审批队列' }}
                </h2>
              </div>
              <div class="grid grid-cols-2 rounded-2xl bg-[#0d1220] p-1">
                <button
                  type="button"
                  class="rounded-2xl px-4 py-3 text-sm font-semibold"
                  :class="activeTab === 'applications' ? 'club-button-primary' : 'text-slate-300'"
                  @click="activeTab = 'applications'"
                >
                  经费/资源申请
                </button>
                <button
                  type="button"
                  class="rounded-2xl px-4 py-3 text-sm font-semibold"
                  :class="activeTab === 'registrations' ? 'club-button-primary' : 'text-slate-300'"
                  @click="activeTab = 'registrations'"
                >
                  活动报名
                </button>
              </div>
            </div>

            <div
              v-if="operationMessage"
              class="mt-5 rounded-2xl border border-[#4a6fa5]/18 bg-[#4a6fa5]/10 px-4 py-3 text-sm text-slate-200"
            >
              {{ operationMessage }}
            </div>

            <div v-if="loading" class="flex justify-center py-16">
              <Loader2 class="h-8 w-8 animate-spin text-[#f2ddae]" />
            </div>

            <div v-else-if="activeTab === 'applications'" class="mt-6 space-y-4">
              <article
                v-for="item in clubApplications"
                :key="item.id"
                class="card-hover club-panel-muted rounded-[24px] p-5"
              >
                <div class="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-3">
                      <p class="font-semibold text-white">{{ item.profiles?.full_name || '匿名申请人' }}</p>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                        {{ item.application_types?.name || item.content?.application_name || '申请单' }}
                      </span>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-500">
                        {{ new Date(item.created_at).toLocaleString('zh-CN') }}
                      </span>
                    </div>

                    <h3 class="mt-4 text-xl font-semibold text-white">
                      {{ item.content?.title || item.content?.club_name || '待审批申请' }}
                    </h3>
                    <p class="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-300">
                      {{ item.content?.reason || '暂无申请理由。' }}
                    </p>

                    <div class="mt-4 flex flex-wrap gap-3 text-xs text-slate-500">
                      <span v-if="item.content?.amount" class="rounded-full border border-white/8 px-3 py-1">
                        <WalletCards class="mr-1 inline h-3.5 w-3.5" />
                        {{ Number(item.content.amount).toLocaleString('zh-CN') }} 元
                      </span>
                      <span v-if="item.content?.detail" class="rounded-full border border-white/8 px-3 py-1">
                        已附补充说明
                      </span>
                    </div>
                  </div>

                  <div class="flex gap-3">
                    <button
                      type="button"
                      class="rounded-2xl border border-rose-400/20 bg-rose-400/10 px-5 py-3 text-sm font-semibold text-rose-100"
                      @click="handleApplicationDecision(item, 'rejected')"
                    >
                      <span class="flex items-center gap-2">
                        <XCircle class="h-4 w-4" />
                        驳回
                      </span>
                    </button>
                    <button
                      type="button"
                      class="rounded-2xl border border-emerald-400/20 bg-emerald-400/10 px-5 py-3 text-sm font-semibold text-emerald-100"
                      @click="handleApplicationDecision(item, 'approved')"
                    >
                      <span class="flex items-center gap-2">
                        <CheckCircle2 class="h-4 w-4" />
                        通过
                      </span>
                    </button>
                  </div>
                </div>
              </article>

              <div
                v-if="!clubApplications.length"
                class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center"
              >
                <UserPlus class="h-8 w-8 text-slate-500" />
                <p class="mt-4 font-display text-2xl font-bold text-white">暂无待审社团申请</p>
                <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                  学生提交的加入社团和经费相关申请会在这里汇总显示。
                </p>
              </div>
            </div>

            <div v-else class="mt-6 space-y-4">
              <article
                v-for="item in registrations"
                :key="item.id"
                class="card-hover club-panel-muted rounded-[24px] p-5"
              >
                <div class="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-3">
                      <p class="font-semibold text-white">{{ item.profiles?.full_name || '匿名报名人' }}</p>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                        {{ item.activities?.title || '活动报名' }}
                      </span>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-500">
                        <Clock3 class="mr-1 inline h-3.5 w-3.5" />
                        {{ new Date(item.created_at).toLocaleString('zh-CN') }}
                      </span>
                    </div>
                    <p class="mt-4 text-sm leading-7 text-slate-300">
                      活动开始时间：{{ new Date(item.activities?.start_time).toLocaleString('zh-CN') }}
                    </p>
                    <p class="mt-2 text-sm leading-7 text-slate-400">
                      活动地点：{{ item.activities?.location || '待定' }}
                    </p>
                  </div>

                  <div class="flex gap-3">
                    <button
                      type="button"
                      class="rounded-2xl border border-rose-400/20 bg-rose-400/10 px-5 py-3 text-sm font-semibold text-rose-100"
                      @click="handleRegistrationDecision(item, 'rejected')"
                    >
                      <span class="flex items-center gap-2">
                        <XCircle class="h-4 w-4" />
                        拒绝
                      </span>
                    </button>
                    <button
                      type="button"
                      class="rounded-2xl border border-emerald-400/20 bg-emerald-400/10 px-5 py-3 text-sm font-semibold text-emerald-100"
                      @click="handleRegistrationDecision(item, 'approved')"
                    >
                      <span class="flex items-center gap-2">
                        <CheckCircle2 class="h-4 w-4" />
                        通过
                      </span>
                    </button>
                  </div>
                </div>
              </article>

              <div
                v-if="!registrations.length"
                class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center"
              >
                <CheckCircle2 class="h-8 w-8 text-slate-500" />
                <p class="mt-4 font-display text-2xl font-bold text-white">暂无待审活动报名</p>
                <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                  学生对本社团活动提交的在线报名会自动进入这里，方便统一审核。
                </p>
              </div>
            </div>
          </section>
        </main>
      </div>
    </div>
  </div>
</template>
