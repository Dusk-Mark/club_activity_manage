<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { roleLabelMap } from '../lib/portal'
import { useAuthStore } from '../stores/auth'
import {
  ArrowRight,
  BookOpen,
  Building2,
  CalendarDays,
  ChevronRight,
  Circle,
  Clock3,
  Flame,
  LayoutDashboard,
  LogOut,
  MapPin,
  Newspaper,
  PlusCircle,
  Search,
  ShieldAlert,
  ShieldCheck,
  Smile,
  Sparkles,
  MessageCircleMore,
  User as UserIcon,
  Users,
  ClipboardCheck,
  Zap
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

const allClubs = ref<any[]>([])
const activities = ref<any[]>([])
const loading = ref(true)
const dashboardError = ref('')
const userRole = ref('student')
const searchQuery = ref('')

const displayName = computed(() => {
  return authStore.user?.user_metadata?.full_name ||
    authStore.user?.email?.split('@')[0] ||
    '同学'
})

const filteredClubs = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()

  if (!query) {
    return allClubs.value.slice(0, 4)
  }

  return allClubs.value
    .filter(club =>
      club.name?.toLowerCase().includes(query) ||
      club.description?.toLowerCase().includes(query)
    )
    .slice(0, 6)
})

const dashboardStats = computed(() => [
  {
    title: '活跃社团',
    value: `${allClubs.value.length}`,
    description: '校园中保持活跃状态的社团数量',
    icon: Building2,
    className: 'md:col-span-3 md:row-span-2',
    tone: 'from-[#c0a26a]/18 to-[#131724]'
  },
  {
    title: '近期待参加',
    value: `${activities.value.length}`,
    description: '未来可报名或待参与的活动',
    icon: CalendarDays,
    className: 'md:col-span-2',
    tone: 'from-[#4a6fa5]/20 to-[#131724]'
  },
  {
    title: '当前权限',
    value: roleLabelMap[userRole.value] || '学生用户',
    description: '根据身份展示对应的管理入口',
    icon: ShieldCheck,
    className: 'md:col-span-2',
    tone: 'from-emerald-400/16 to-[#131724]'
  }
])

const quickActions = computed(() => {
  const actions = [
    {
      title: '发布活动',
      description: '创建招募、签到与反馈流程',
      to: '/activity/publish',
      icon: PlusCircle,
      className: 'md:col-span-3',
      iconClass: 'text-[#f2ddae]'
    },
    {
      title: '创建社团',
      description: '建立组织资料并发起纳新',
      to: '/create-club',
      icon: Building2,
      className: 'md:col-span-3',
      iconClass: 'text-[#9fc0f7]'
    },
    {
      title: '社员管理',
      description: '更新成员信息与角色分配',
      to: '/club/members',
      icon: Users,
      className: 'md:col-span-6',
      iconClass: 'text-emerald-300'
    },
    {
      title: '申请审核',
      description: '查看报名审批与社团申请流转',
      to: '/club-admin',
      icon: ShieldCheck,
      className: 'md:col-span-3',
      iconClass: 'text-[#f2ddae]'
    },
    {
      title: '我的申请',
      description: '发起加入社团、经费与资源支持申请',
      to: '/applications',
      icon: PlusCircle,
      className: 'md:col-span-3',
      iconClass: 'text-[#9fc0f7]'
    },
    {
      title: '互动社区',
      description: '进入留言板、活动交流与公告联动区',
      to: '/community',
      icon: MessageCircleMore,
      className: 'md:col-span-3',
      iconClass: 'text-emerald-300'
    },
    {
      title: '社团任务',
      description: '负责人发布任务，成员查看分工安排',
      to: '/club/tasks',
      icon: ClipboardCheck,
      className: 'md:col-span-3',
      iconClass: 'text-[#f2ddae]'
    }
  ]

  if (userRole.value === 'league_committee' || userRole.value === 'admin') {
    actions.push({
      title: '校团委总管',
      description: '查看高权限治理与总览入口',
      to: '/league-admin',
      icon: ShieldAlert,
      className: 'md:col-span-3',
      iconClass: 'text-rose-300'
    })
  }

  return actions
})

const handleLogout = async () => {
  await supabase.auth.signOut()
  router.push('/')
}

const formatDate = (value: string) => {
  return new Date(value).toLocaleDateString('zh-CN', {
    month: 'numeric',
    day: 'numeric',
    weekday: 'short'
  })
}

const formatTime = (value: string) => {
  return new Date(value).toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit'
  })
}

const getActivityMood = (startTime: string) => {
  const diffInDays = Math.ceil((new Date(startTime).getTime() - Date.now()) / 86400000)

  if (diffInDays <= 2) {
    return {
      label: '临近开启',
      icon: Flame,
      iconClass: 'text-amber-300',
      progress: 86,
      feeling: '热度高'
    }
  }

  if (diffInDays <= 7) {
    return {
      label: '报名活跃',
      icon: Smile,
      iconClass: 'text-sky-300',
      progress: 62,
      feeling: '氛围轻松'
    }
  }

  return {
    label: '筹备中',
    icon: Zap,
    iconClass: 'text-[#f2ddae]',
    progress: 38,
    feeling: '稳步预热'
  }
}

const upcomingActivities = computed(() => {
  return activities.value.map(activity => ({
    ...activity,
    mood: getActivityMood(activity.start_time)
  }))
})

const calendarDays = computed(() => {
  const start = new Date()
  start.setHours(0, 0, 0, 0)

  return Array.from({ length: 14 }, (_, index) => {
    const date = new Date(start)
    date.setDate(start.getDate() + index)

    const items = activities.value.filter(activity => {
      const activityDate = new Date(activity.start_time)
      return activityDate.toDateString() === date.toDateString()
    })

    return {
      key: date.toISOString(),
      day: date.getDate(),
      weekDay: date.toLocaleDateString('zh-CN', { weekday: 'short' }),
      isToday: index === 0,
      items
    }
  })
})

const fetchData = async () => {
  loading.value = true
  dashboardError.value = ''

  try {
    const user = await authStore.ensureUser()

    if (!user) {
      router.push('/')
      return
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    userRole.value = profile?.role || 'student'

    const [
      { data: clubsData, error: clubsError },
      { data: memberData, error: memberError },
      { data: activitiesData, error: activitiesError }
    ] = await Promise.all([
      supabase
        .from('clubs')
        .select('*')
        .eq('status', 'active'),
      supabase
        .from('club_members')
        .select('club_id'),
      supabase
        .from('activities')
        .select('*, clubs(name)')
        .gte('start_time', new Date().toISOString())
        .order('start_time', { ascending: true })
        .limit(6)
    ])

    if (clubsError) throw clubsError
    if (activitiesError) throw activitiesError

    const memberCountMap = new Map<string, number>()
    if (memberError) {
      console.warn('Error fetching club member counts:', memberError)
    } else {
      for (const item of memberData || []) {
        memberCountMap.set(item.club_id, (memberCountMap.get(item.club_id) || 0) + 1)
      }
    }

    allClubs.value = (clubsData || []).map(club => ({
      ...club,
      memberCount: memberCountMap.get(club.id) || 0
    }))

    activities.value = activitiesData || []
  } catch (error: any) {
    dashboardError.value = error?.message || '数据加载出现异常，请稍后刷新重试。'
    console.error('Error fetching dashboard data:', error)
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  fetchData()
})
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-8">
    <div class="mx-auto max-w-7xl space-y-6">
      <header class="club-panel flex flex-col gap-4 px-5 py-5 md:px-6 xl:flex-row xl:items-center xl:justify-between">
        <div class="flex items-center gap-4">
          <div class="flex h-14 w-14 items-center justify-center rounded-[20px] bg-gradient-to-br from-[#c0a26a] to-[#e7d29c] text-[#171717] shadow-[0_20px_32px_-22px_rgba(231,210,156,0.9)]">
            <LayoutDashboard class="h-6 w-6" />
          </div>
          <div>
            <p class="text-sm text-slate-400">Dashboard</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3">
          <button class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="router.push('/news')">
            <span class="flex items-center gap-2">
              <Newspaper class="h-4 w-4" />
              校园新闻
            </span>
          </button>
          <button class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="router.push('/rules')">
            <span class="flex items-center gap-2">
              <BookOpen class="h-4 w-4" />
              规章制度
            </span>
          </button>
          <button class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="router.push('/profile')">
            <span class="flex items-center gap-2">
              <UserIcon class="h-4 w-4" />
              个人中心
            </span>
          </button>
          <button class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="router.push('/community')">
            <span class="flex items-center gap-2">
              <MessageCircleMore class="h-4 w-4" />
              互动交流
            </span>
          </button>
          <button
            class="rounded-2xl border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm font-semibold text-rose-100 hover:bg-rose-400/15"
            @click="handleLogout"
          >
            <span class="flex items-center gap-2">
              <LogOut class="h-4 w-4" />
              退出登录
            </span>
          </button>
        </div>
      </header>

      <div
        v-if="dashboardError"
        class="club-panel rounded-[24px] border border-rose-400/20 bg-rose-400/10 px-5 py-4 text-sm text-rose-100"
      >
        {{ dashboardError }}
      </div>

      <main class="grid grid-cols-1 gap-6 xl:grid-cols-12">
        <section class="club-panel overflow-hidden p-6 md:p-8 xl:col-span-7">
          <div class="grid gap-8 lg:grid-cols-[1.05fr_0.95fr]">
            <div class="space-y-6">
              <div class="inline-flex items-center gap-2 rounded-full border border-[#e7d29c]/18 bg-[#e7d29c]/10 px-4 py-2 text-sm text-[#f2ddae]">
                <Sparkles class="h-4 w-4" />
                欢迎回来，{{ displayName }}
              </div>

              <div class="space-y-4">
                <h2 class="max-w-xl font-display text-4xl font-bold leading-tight text-white md:text-5xl">
                  一站查看校园社团动态，
                  <span class="block bg-gradient-to-r from-[#c0a26a] to-[#e7d29c] bg-clip-text text-transparent">
                    让活动组织与参与更高效
                  </span>
                </h2>
                <p class="max-w-2xl text-base leading-7 text-slate-300">
                  在这里可以快速掌握社团活动安排、成员管理入口和近期报名信息，更适合学校社团日常使用。
                </p>
              </div>

              <div class="club-panel-muted max-w-2xl p-3">
                <div class="flex items-center gap-3 rounded-[18px] bg-[#0c111d] px-4 py-3">
                  <Search class="h-4 w-4 text-slate-500" />
                  <input
                    v-model="searchQuery"
                    type="text"
                    placeholder="搜索社团名称或简介..."
                    class="w-full bg-transparent text-sm text-white outline-none placeholder:text-slate-500"
                  />
                  <button class="club-button-primary rounded-2xl px-4 py-2 text-sm font-semibold">
                    搜索
                  </button>
                </div>
              </div>

              <div class="grid gap-4 md:grid-cols-[1.1fr_0.9fr]">
                <div class="club-panel-muted p-5">
                  <p class="text-sm text-slate-400">当前身份</p>
                  <p class="mt-2 font-display text-2xl font-bold text-white">
                    {{ roleLabelMap[userRole] || '学生用户' }}
                  </p>
                  <p class="mt-2 text-sm leading-6 text-slate-300">
                    不同身份会显示不同的治理入口、审核权限和活动管理能力。
                  </p>
                </div>
                <div class="club-panel-muted p-5">
                  <p class="text-sm text-slate-400">推荐动作</p>
                  <p class="mt-2 font-display text-2xl font-bold text-white">
                    {{ activities.length ? '查看近期开场活动' : '先创建社团或发布活动' }}
                  </p>
                  <p class="mt-2 text-sm leading-6 text-slate-300">
                    先处理最重要的事务，再逐步浏览成员、申请与社区信息。
                  </p>
                </div>
              </div>
            </div>

            <div class="grid auto-rows-[145px] gap-4 sm:grid-cols-2">
              <article class="card-hover club-panel-muted relative overflow-hidden p-5 sm:row-span-2">
                <div class="absolute inset-0 bg-gradient-to-br from-[#c0a26a]/16 via-transparent to-transparent" />
                <div class="relative flex h-full flex-col justify-between">
                  <div>
                    <p class="text-sm text-slate-400">活跃节奏</p>
                    <p class="mt-3 font-display text-4xl font-bold text-white">
                      {{ activities.length ? '稳定升温' : '等待点亮' }}
                    </p>
                  </div>
                  <p class="max-w-xs text-sm leading-6 text-slate-300">
                    近期活动越集中，右侧日历的圆点标记和列表情绪标签就越明显。
                  </p>
                </div>
              </article>

              <article class="card-hover club-panel-muted p-5">
                <p class="text-sm text-slate-400">社团基数</p>
                <p class="mt-3 font-display text-3xl font-bold text-white">{{ allClubs.length }}</p>
                <p class="mt-2 text-sm text-slate-300">已纳入平台的活跃社团</p>
              </article>

              <article class="card-hover club-panel-muted p-5">
                <p class="text-sm text-slate-400">近期开场</p>
                <p class="mt-3 font-display text-3xl font-bold text-white">{{ activities.length }}</p>
                <p class="mt-2 text-sm text-slate-300">等待报名或参与的活动</p>
              </article>
            </div>
          </div>
        </section>

        <section class="club-panel p-5 md:p-6 xl:col-span-5">
          <div class="mb-5 flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-400">Quick Actions</p>
              <h3 class="mt-1 font-display text-2xl font-bold text-white">快捷通道</h3>
            </div>
            <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">高频操作入口</span>
          </div>

          <div class="grid gap-4 md:grid-cols-6">
            <button
              v-for="action in quickActions"
              :key="action.title"
              type="button"
              :class="['card-hover club-panel-muted p-5 text-left', action.className]"
              @click="router.push(action.to)"
            >
              <div class="mb-5 flex items-center justify-between">
                <div class="flex h-11 w-11 items-center justify-center rounded-2xl bg-white/6">
                  <component :is="action.icon" class="h-5 w-5" :class="action.iconClass" />
                </div>
                <ArrowRight class="h-4 w-4 text-slate-500" />
              </div>
              <p class="font-semibold text-white">{{ action.title }}</p>
              <p class="mt-2 text-sm leading-6 text-slate-400">{{ action.description }}</p>
            </button>
          </div>

          <div class="mt-4 rounded-[20px] border border-[#4a6fa5]/20 bg-[#4a6fa5]/10 p-4 text-sm leading-6 text-slate-200">
            把发布、创建、审核与交流拆分成独立入口，可以更快定位当前要处理的事务。
          </div>
        </section>

        <section class="xl:col-span-7">
          <div class="grid gap-4 md:grid-cols-5 md:auto-rows-[160px]">
            <article
              v-for="item in dashboardStats"
              :key="item.title"
              :class="['card-hover club-panel relative overflow-hidden p-5 md:p-6', item.className]"
            >
              <div class="absolute inset-0 bg-gradient-to-br" :class="item.tone" />
              <div class="relative flex h-full flex-col justify-between">
                <div class="flex items-center justify-between">
                  <p class="text-sm text-slate-400">{{ item.title }}</p>
                  <component :is="item.icon" class="h-5 w-5 text-[#f2ddae]" />
                </div>
                <div>
                  <p class="font-display text-3xl font-bold text-white md:text-4xl">{{ item.value }}</p>
                  <p class="mt-2 max-w-xs text-sm leading-6 text-slate-300">{{ item.description }}</p>
                </div>
              </div>
            </article>
          </div>
        </section>

        <section class="club-panel p-5 md:p-6 xl:col-span-5">
          <div class="mb-5 flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-400">Calendar Preview</p>
              <h3 class="mt-1 font-display text-2xl font-bold text-white">两周活动日历</h3>
            </div>
            <CalendarDays class="h-5 w-5 text-[#f2ddae]" />
          </div>

          <div v-if="loading" class="grid grid-cols-2 gap-3 sm:grid-cols-7">
            <div
              v-for="index in 14"
              :key="index"
              class="club-panel-muted shimmer-block h-24 rounded-[18px]"
            />
          </div>

          <div v-else-if="activities.length" class="grid grid-cols-2 gap-3 sm:grid-cols-7">
            <div
              v-for="day in calendarDays"
              :key="day.key"
              class="group club-panel-muted relative min-h-24 rounded-[18px] p-3 transition-all hover:border-[#e7d29c]/25"
              :class="day.isToday ? 'border-[#e7d29c]/28 bg-[#e7d29c]/10' : ''"
            >
              <div class="flex items-start justify-between">
                <div>
                  <p class="text-xs text-slate-500">{{ day.weekDay }}</p>
                  <p class="mt-1 font-display text-lg font-bold text-white">{{ day.day }}</p>
                </div>
                <span v-if="day.items.length" class="text-xs text-[#f2ddae]">{{ day.items.length }}</span>
              </div>

              <div class="mt-4 flex flex-wrap gap-1.5">
                <Circle
                  v-for="activity in day.items.slice(0, 3)"
                  :key="activity.id"
                  class="h-3.5 w-3.5 fill-current text-[#e7d29c]"
                />
              </div>

              <div
                v-if="day.items.length"
                class="pointer-events-none absolute left-1/2 top-full z-20 mt-3 w-52 -translate-x-1/2 rounded-2xl border border-white/8 bg-[#0d111d] p-3 opacity-0 shadow-[0_24px_40px_-18px_rgba(0,0,0,0.75)] transition-all duration-200 group-hover:pointer-events-auto group-hover:opacity-100"
              >
                <p class="text-xs text-slate-500">当日预览</p>
                <div
                  v-for="activity in day.items.slice(0, 2)"
                  :key="activity.id"
                  class="mt-2 rounded-xl bg-white/5 px-3 py-2"
                >
                  <p class="line-clamp-1 text-sm font-medium text-white">{{ activity.title }}</p>
                  <p class="mt-1 text-xs text-slate-400">{{ formatTime(activity.start_time) }}</p>
                </div>
              </div>
            </div>
          </div>

          <div
            v-else
            class="club-panel-muted flex min-h-64 flex-col items-center justify-center rounded-[24px] p-8 text-center"
          >
            <CalendarDays class="h-8 w-8 text-slate-500" />
            <p class="mt-4 font-display text-2xl font-bold text-white">暂无未来活动</p>
            <p class="mt-2 max-w-sm text-sm leading-6 text-slate-400">
              日历格子会在有活动时显示圆点并提供悬停预览，你现在可以先去发布一场新活动。
            </p>
          </div>
        </section>

        <section class="club-panel p-5 md:p-6 xl:col-span-7">
          <div class="mb-5 flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-400">Activity Feed</p>
              <h3 class="mt-1 font-display text-2xl font-bold text-white">近期活动</h3>
            </div>
            <button
              class="flex items-center gap-1 text-sm font-medium text-[#f2ddae]"
              @click="router.push('/news')"
            >
              查看更多
              <ChevronRight class="h-4 w-4" />
            </button>
          </div>

          <div v-if="loading" class="space-y-4">
            <div
              v-for="index in 4"
              :key="index"
              class="club-panel-muted shimmer-block h-28 rounded-[22px]"
            />
          </div>

          <div v-else-if="upcomingActivities.length" class="space-y-4">
            <button
              v-for="activity in upcomingActivities"
              :key="activity.id"
              type="button"
              class="card-hover club-panel-muted w-full rounded-[22px] p-4 text-left md:p-5"
              @click="router.push(`/activity/${activity.id}`)"
            >
              <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-center gap-3">
                    <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                      {{ activity.clubs?.name || '校园活动' }}
                    </span>
                    <span class="text-xs text-slate-500">{{ formatDate(activity.start_time) }}</span>
                  </div>

                  <div class="mt-3 flex items-center gap-3">
                    <h4 class="line-clamp-1 font-display text-2xl font-bold text-white">{{ activity.title }}</h4>
                    <span class="rounded-full bg-white/6 px-3 py-1 text-xs text-slate-300">
                      {{ activity.mood.feeling }}
                    </span>
                  </div>

                  <div class="mt-4 flex flex-wrap items-center gap-4 text-sm text-slate-400">
                    <span class="flex items-center gap-2">
                      <Clock3 class="h-4 w-4" />
                      {{ formatTime(activity.start_time) }}
                    </span>
                    <span class="flex items-center gap-2">
                      <MapPin class="h-4 w-4" />
                      {{ activity.location || '校内场地待定' }}
                    </span>
                  </div>
                </div>

                <div class="w-full md:max-w-[230px]">
                  <div class="mb-3 flex items-center justify-between text-sm">
                    <div class="flex items-center gap-2">
                      <component
                        :is="activity.mood.icon"
                        class="h-4 w-4"
                        :class="activity.mood.iconClass"
                      />
                      <span class="text-slate-300">{{ activity.mood.label }}</span>
                    </div>
                    <span class="text-slate-500">{{ activity.mood.progress }}%</span>
                  </div>
                  <div class="mini-progress h-2">
                    <span :style="{ width: `${activity.mood.progress}%` }" />
                  </div>
                </div>
              </div>
            </button>
          </div>

          <div
            v-else
            class="club-panel-muted flex min-h-64 flex-col items-center justify-center rounded-[24px] p-8 text-center"
          >
            <Sparkles class="h-8 w-8 text-slate-500" />
            <p class="mt-4 font-display text-2xl font-bold text-white">活动列表还没有被点亮</p>
            <p class="mt-2 max-w-sm text-sm leading-6 text-slate-400">
              当前还没有未来活动，先去发布新活动后，这里会自动显示时间、地点和参与节奏。
            </p>
            <button
              class="club-button-primary mt-5 rounded-2xl px-5 py-3 text-sm font-semibold"
              @click="router.push('/activity/publish')"
            >
              立即发布活动
            </button>
          </div>
        </section>

        <section class="club-panel p-5 md:p-6 xl:col-span-5">
          <div class="mb-5 flex items-center justify-between">
            <div>
              <p class="text-sm text-slate-400">Recommended Clubs</p>
              <h3 class="mt-1 font-display text-2xl font-bold text-white">推荐社团</h3>
            </div>
            <button class="text-sm font-medium text-[#9fc0f7]" @click="router.push('/clubs')">
              浏览全部
            </button>
          </div>

          <div v-if="loading" class="space-y-4">
            <div
              v-for="index in 4"
              :key="index"
              class="club-panel-muted shimmer-block h-20 rounded-[18px]"
            />
          </div>

          <div v-else-if="filteredClubs.length" class="space-y-4">
            <button
              v-for="club in filteredClubs"
              :key="club.id"
              type="button"
              class="card-hover club-panel-muted flex w-full items-center gap-4 rounded-[20px] p-4 text-left"
              @click="router.push(`/club/${club.id}`)"
            >
              <div class="h-14 w-14 overflow-hidden rounded-2xl border border-white/10 bg-white/5 p-1">
                <img
                  :src="club.logo_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(club.name)}&background=1f2937&color=ffffff`"
                  :alt="club.name"
                  class="h-full w-full rounded-xl object-cover"
                />
              </div>

              <div class="min-w-0 flex-1">
                <div class="flex items-center justify-between gap-3">
                  <p class="truncate font-semibold text-white">{{ club.name }}</p>
                  <ArrowRight class="h-4 w-4 text-slate-500" />
                </div>
                <p class="mt-1 text-sm text-slate-400">{{ club.memberCount }} 位成员</p>
                <p class="mt-2 line-clamp-2 text-sm leading-6 text-slate-500">
                  {{ club.description || '该社团正在完善简介，点击可查看完整信息。' }}
                </p>
              </div>
            </button>
          </div>

          <div
            v-else
            class="club-panel-muted flex min-h-64 flex-col items-center justify-center rounded-[24px] p-8 text-center"
          >
            <Users class="h-8 w-8 text-slate-500" />
            <p class="mt-4 font-display text-2xl font-bold text-white">
              {{ searchQuery ? '没有匹配的社团' : '暂无推荐社团' }}
            </p>
            <p class="mt-2 max-w-sm text-sm leading-6 text-slate-400">
              {{ searchQuery ? '换一个关键词试试，或直接浏览全部社团列表。' : '等社团数据接入后，这里会展示优先推荐的组织。' }}
            </p>
          </div>
        </section>
      </main>
    </div>
  </div>
</template>
