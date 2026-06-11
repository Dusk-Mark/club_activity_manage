<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowLeft,
  Building2,
  Loader2,
  Settings2,
  ShieldCheck,
  Sparkles,
  Trash2,
  UserCog,
  Users,
  WalletCards
} from 'lucide-vue-next'
import { clubMemberRoleLabelMap, defaultApplicationTypes, roleLabelMap } from '../lib/portal'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const activeTab = ref<'users' | 'applications' | 'types' | 'configs' | 'governance'>('users')
const searchQuery = ref('')
const systemMessage = ref('')
const deletingActivityId = ref('')

const users = ref<any[]>([])
const clubs = ref<any[]>([])
const activities = ref<any[]>([])
const clubMembers = ref<any[]>([])
const applicationTypes = ref<any[]>([])
const siteConfigs = ref<any[]>([])
const pendingApplications = ref<any[]>([])
const selectedGovernanceClubId = ref('')

const newType = ref({
  name: '',
  key: '',
  description: '',
  scope: 'system'
})

const newConfig = ref({
  config_key: '',
  config_value: '',
  description: ''
})

const filteredUsers = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()

  if (!keyword) return users.value

  return users.value.filter(item =>
    item.full_name?.toLowerCase().includes(keyword) ||
    item.username?.toLowerCase().includes(keyword) ||
    item.role?.toLowerCase().includes(keyword)
  )
})

const filteredClubs = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()

  if (!keyword) return clubs.value

  return clubs.value.filter(item => item.name?.toLowerCase().includes(keyword))
})

const filteredActivities = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()

  if (!keyword) return activities.value

  return activities.value.filter(item => item.title?.toLowerCase().includes(keyword))
})

const filteredApplications = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()
  const apps = pendingApplications.value.filter(app => app.status === 'pending')

  if (!keyword) return apps

  return apps.filter(app =>
    app.profiles?.full_name?.toLowerCase().includes(keyword) ||
    app.profiles?.username?.toLowerCase().includes(keyword) ||
    app.content?.club_name?.toLowerCase().includes(keyword) ||
    app.content?.title?.toLowerCase().includes(keyword) ||
    app.application_types?.name?.toLowerCase().includes(keyword)
  )
})

const governanceMembers = computed(() => {
  const keyword = searchQuery.value.trim().toLowerCase()

  return clubMembers.value.filter(item => {
    const matchesClub = !selectedGovernanceClubId.value || item.club_id === selectedGovernanceClubId.value

    if (!matchesClub) return false
    if (!keyword) return true

    return (
      item.profiles?.full_name?.toLowerCase().includes(keyword) ||
      item.profiles?.username?.toLowerCase().includes(keyword) ||
      item.clubs?.name?.toLowerCase().includes(keyword) ||
      item.role?.toLowerCase().includes(keyword)
    )
  })
})

const overviewStats = computed(() => [
  {
    title: '平台用户',
    value: `${users.value.length}`,
    icon: Users,
    tone: 'text-[#f2ddae]'
  },
  {
    title: '申请类型',
    value: `${applicationTypes.value.length}`,
    icon: WalletCards,
    tone: 'text-[#9fc0f7]'
  },
  {
    title: '网站配置项',
    value: `${siteConfigs.value.length}`,
    icon: Settings2,
    tone: 'text-emerald-300'
  },
  {
    title: '活跃社团',
    value: `${clubs.value.filter((item: any) => item.status === 'active').length}`,
    icon: Building2,
    tone: 'text-white'
  }
])

const fetchData = async () => {
  loading.value = true

  try {
    const user = await authStore.ensureUser()

    if (!user) {
      router.push('/')
      return
    }

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (profileError) throw profileError

    if (!['league_committee', 'admin'].includes(profile?.role || '')) {
      router.push('/dashboard')
      return
    }

    const [
      { data: userData, error: userError },
      { data: clubData, error: clubError },
      { data: activityData, error: activityError },
      { data: clubMemberData, error: clubMemberError },
      { data: applicationData, error: applicationError },
      typeResponse,
      configResponse
    ] = await Promise.all([
      supabase.from('profiles').select('*').order('updated_at', { ascending: false }),
      supabase.from('clubs').select('*, profiles(full_name)').order('created_at', { ascending: false }),
      supabase.from('activities').select('*, clubs(name)').order('start_time', { ascending: false }),
      supabase.from('club_members').select('*, profiles(full_name, username), clubs(name)').order('joined_at', { ascending: false }),
      supabase.from('user_applications').select('*, profiles(full_name, avatar_url, username), application_types(name)').order('created_at', { ascending: false }),
      supabase.from('application_types').select('*').order('name', { ascending: true }),
      supabase.from('site_configs').select('*').order('config_key', { ascending: true })
    ])

    if (userError) throw userError
    if (clubError) throw clubError
    if (activityError) throw activityError
    if (clubMemberError) throw clubMemberError
    if (applicationError) throw applicationError

    users.value = userData || []
    clubs.value = clubData || []
    activities.value = activityData || []
    clubMembers.value = clubMemberData || []
    pendingApplications.value = applicationData || []
    applicationTypes.value = typeResponse.error
      ? defaultApplicationTypes.map(item => ({ ...item }))
      : typeResponse.data || []
    siteConfigs.value = configResponse.error ? [] : configResponse.data || []

    if (!selectedGovernanceClubId.value && clubs.value.length) {
      selectedGovernanceClubId.value = clubs.value[0].id
    }
  } catch (error) {
    systemMessage.value = '综合后台加载失败，请检查数据库迁移和权限策略。'
    console.error('Error loading league admin view:', error)
  } finally {
    loading.value = false
  }
}

const handleRoleUpdate = async (userId: string, role: string) => {
  const { error } = await supabase
    .from('profiles')
    .update({ role })
    .eq('id', userId)

  if (error) {
    systemMessage.value = error.message || '更新用户角色失败。'
    return
  }

  systemMessage.value = '用户角色已更新。'
  await fetchData()
}

const handleAddApplicationType = async () => {
  if (!newType.value.name.trim()) {
    systemMessage.value = '请先填写申请类型名称。'
    return
  }

  const payload = {
    name: newType.value.name.trim(),
    key: (newType.value.key || newType.value.name).trim().toLowerCase().replace(/\s+/g, '_'),
    description: newType.value.description.trim(),
    scope: newType.value.scope
  }

  const { error } = await supabase.from('application_types').insert(payload)

  if (error) {
    systemMessage.value = error.message || '新增申请类型失败。'
    return
  }

  newType.value = { name: '', key: '', description: '', scope: 'system' }
  systemMessage.value = '申请类型已新增。'
  await fetchData()
}

const handleSaveConfig = async () => {
  if (!newConfig.value.config_key.trim()) {
    systemMessage.value = '请填写配置键名。'
    return
  }

  const { error } = await supabase
    .from('site_configs')
    .upsert({
      config_key: newConfig.value.config_key.trim(),
      config_value: newConfig.value.config_value.trim(),
      description: newConfig.value.description.trim(),
      updated_by: authStore.user?.id
    }, {
      onConflict: 'config_key'
    })

  if (error) {
    systemMessage.value = error.message || '保存网站配置失败。'
    return
  }

  newConfig.value = { config_key: '', config_value: '', description: '' }
  systemMessage.value = '网站配置已保存。'
  await fetchData()
}

const handleClubStatus = async (club: any) => {
  const nextStatus = club.status === 'active' ? 'inactive' : 'active'
  const { error } = await supabase
    .from('clubs')
    .update({ status: nextStatus })
    .eq('id', club.id)

  if (error) {
    systemMessage.value = error.message || '更新社团状态失败。'
    return
  }

  systemMessage.value = '社团状态已更新。'
  await fetchData()
}

const handleActivityDelete = async (activity: any) => {
  if (deletingActivityId.value) return

  const confirmed = window.confirm(`确定删除活动“${activity.title || '未命名活动'}”吗？该操作不可恢复。`)

  if (!confirmed) {
    return
  }

  deletingActivityId.value = activity.id

  const { error } = await supabase
    .from('activities')
    .delete()
    .eq('id', activity.id)

  if (error) {
    systemMessage.value = error.message || '删除活动失败。'
    deletingActivityId.value = ''
    return
  }

  activities.value = activities.value.filter(item => item.id !== activity.id)
  systemMessage.value = '活动已删除。'
  deletingActivityId.value = ''
}

const handleClubMemberRoleUpdate = async (memberId: string, role: string) => {
  const { error } = await supabase
    .from('club_members')
    .update({ role })
    .eq('id', memberId)

  if (error) {
    systemMessage.value = error.message || '更新成员身份失败。'
    return
  }

  systemMessage.value = role === 'leader' ? '已指定该成员为社团负责人。' : '成员身份已更新。'
  await fetchData()
}

const handleApplicationDecision = async (application: any, status: 'approved' | 'rejected') => {
  try {
    // 如果是加入社团申请且被批准，则自动写入成员表
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
        admin_remark: status === 'approved' ? '校团委已批准该申请。' : '校团委已驳回该申请。'
      })
      .eq('id', application.id)

    if (error) throw error

    systemMessage.value = status === 'approved' ? '申请已通过。' : '申请已驳回。'
    await fetchData()
  } catch (error: any) {
    systemMessage.value = error.message || '处理申请失败。'
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
          <button
            type="button"
            class="flex h-12 w-12 items-center justify-center rounded-2xl border border-white/8 bg-white/5 text-slate-200"
            @click="router.back()"
          >
            <ArrowLeft class="h-5 w-5" />
          </button>
          <div>
            <p class="text-sm text-slate-400">League Console</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">全量用户管理</span>
          <span class="rounded-full border border-white/8 px-4 py-2">全校申请审批</span>
          <span class="rounded-full border border-white/8 px-4 py-2">网站配置</span>
        </div>
      </header>

      <section class="grid gap-4 md:grid-cols-4">
        <article v-for="item in overviewStats" :key="item.title" class="club-panel p-5">
          <component :is="item.icon" class="h-5 w-5" :class="item.tone" />
          <p class="mt-3 font-display text-3xl font-bold text-white">{{ item.value }}</p>
          <p class="mt-2 text-sm text-slate-400">{{ item.title }}</p>
        </article>
      </section>

      <section class="club-panel p-6 md:p-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div class="grid grid-cols-2 gap-2 rounded-2xl bg-[#0d1220] p-1 md:grid-cols-5">
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTab === 'users' ? 'club-button-primary' : 'text-slate-300'"
              @click="activeTab = 'users'"
            >
              用户管理
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTab === 'applications' ? 'club-button-primary' : 'text-slate-300'"
              @click="activeTab = 'applications'"
            >
              申请审批
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTab === 'types' ? 'club-button-primary' : 'text-slate-300'"
              @click="activeTab = 'types'"
            >
              申请类型
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTab === 'configs' ? 'club-button-primary' : 'text-slate-300'"
              @click="activeTab = 'configs'"
            >
              网站配置
            </button>
            <button
              type="button"
              class="rounded-2xl px-4 py-3 text-sm font-semibold"
              :class="activeTab === 'governance' ? 'club-button-primary' : 'text-slate-300'"
              @click="activeTab = 'governance'"
            >
              校级治理
            </button>
          </div>

          <input
            v-model="searchQuery"
            type="text"
            class="club-input w-full max-w-sm px-4 py-4"
            :placeholder="activeTab === 'users'
              ? '搜索姓名、账号或角色'
              : activeTab === 'governance'
                ? '搜索社团或活动'
                : '搜索当前内容'"
          />
        </div>

        <div
          v-if="systemMessage"
          class="mt-5 rounded-2xl border border-[#4a6fa5]/18 bg-[#4a6fa5]/10 px-4 py-3 text-sm text-slate-200"
        >
          {{ systemMessage }}
        </div>

        <div v-if="loading" class="flex justify-center py-16">
          <Loader2 class="h-8 w-8 animate-spin text-[#f2ddae]" />
        </div>

        <div v-else-if="activeTab === 'users'" class="mt-6 grid gap-4">
          <article
            v-for="user in filteredUsers"
            :key="user.id"
            class="card-hover club-panel-muted rounded-[24px] p-5"
          >
            <div class="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <div class="flex flex-wrap items-center gap-3">
                  <p class="font-semibold text-white">{{ user.full_name || user.username || '未命名用户' }}</p>
                  <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                    {{ user.username || '无用户名' }}
                  </span>
                </div>
                <p class="mt-3 text-sm text-slate-300">{{ roleLabelMap[user.role] || user.role }}</p>
              </div>
              <select
                class="club-input min-w-[180px] px-4 py-3"
                :value="user.role"
                @change="handleRoleUpdate(user.id, ($event.target as HTMLSelectElement).value)"
              >
                <option value="student">学生用户</option>
                <option value="club_admin">社团管理员</option>
                <option value="league_committee">校团委</option>
                <option value="admin">系统管理员</option>
              </select>
            </div>
          </article>
        </div>

        <div v-else-if="activeTab === 'applications'" class="mt-6 space-y-4">
          <div v-if="!filteredApplications.length" class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center">
            <WalletCards class="h-8 w-8 text-slate-500" />
            <p class="mt-4 font-display text-2xl font-bold text-white">暂无待审批申请</p>
            <p class="mt-2 text-sm text-slate-400">全校学生的加入社团、经费等申请将在此汇总。</p>
          </div>

          <article
            v-for="app in filteredApplications"
            :key="app.id"
            class="card-hover club-panel-muted rounded-[24px] p-5"
          >
            <div class="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
              <div class="flex-1">
                <div class="flex flex-wrap items-center gap-3">
                  <p class="font-semibold text-white">{{ app.profiles?.full_name || app.profiles?.username }}</p>
                  <span class="rounded-full border border-white/8 bg-white/5 px-3 py-1 text-xs text-slate-400">
                    {{ app.application_types?.name }}
                  </span>
                  <span v-if="app.content?.club_name" class="rounded-full border border-[#f2ddae]/18 bg-[#f2ddae]/10 px-3 py-1 text-xs text-[#f2ddae]">
                    {{ app.content.club_name }}
                  </span>
                </div>
                <div class="mt-4 space-y-2 text-sm text-slate-300">
                  <p><span class="text-slate-500">申请标题：</span>{{ app.content?.title }}</p>
                  <p v-if="app.content?.amount"><span class="text-slate-500">申请金额：</span>¥{{ app.content.amount }}</p>
                  <p><span class="text-slate-500">申请理由：</span>{{ app.content?.reason }}</p>
                  <p v-if="app.content?.detail"><span class="text-slate-500">详细说明：</span>{{ app.content.detail }}</p>
                </div>
              </div>

              <div class="flex shrink-0 gap-3">
                <button
                  type="button"
                  class="flex h-11 items-center gap-2 rounded-xl border border-rose-500/20 bg-rose-500/10 px-5 text-sm font-semibold text-rose-200 transition-colors hover:bg-rose-500/20"
                  @click="handleApplicationDecision(app, 'rejected')"
                >
                  驳回
                </button>
                <button
                  type="button"
                  class="flex h-11 items-center gap-2 rounded-xl bg-emerald-500 px-5 text-sm font-semibold text-white transition-colors hover:bg-emerald-600"
                  @click="handleApplicationDecision(app, 'approved')"
                >
                  批准申请
                </button>
              </div>
            </div>
          </article>
        </div>

        <div v-else-if="activeTab === 'types'" class="mt-6 grid gap-6 xl:grid-cols-[0.92fr_1.08fr]">
          <section class="club-panel-muted rounded-[24px] p-5">
            <h3 class="font-display text-2xl font-bold text-white">新增申请类型</h3>
            <div class="mt-5 space-y-4">
              <input v-model="newType.name" type="text" class="club-input w-full px-4 py-4" placeholder="例如：场地借用申请" />
              <input v-model="newType.key" type="text" class="club-input w-full px-4 py-4" placeholder="类型标识，可留空自动生成" />
              <select v-model="newType.scope" class="club-input w-full px-4 py-4">
                <option value="club">社团级</option>
                <option value="activity">活动级</option>
                <option value="system">系统级</option>
              </select>
              <textarea v-model="newType.description" rows="3" class="club-input w-full resize-none px-4 py-4" placeholder="填写类型说明" />
              <button type="button" class="club-button-primary rounded-2xl px-5 py-4 text-sm font-semibold" @click="handleAddApplicationType">
                保存申请类型
              </button>
            </div>
          </section>

          <section class="space-y-4">
            <article v-for="item in applicationTypes" :key="item.id || item.key" class="card-hover club-panel-muted rounded-[24px] p-5">
              <div class="flex flex-wrap items-center gap-3">
                <p class="font-semibold text-white">{{ item.name }}</p>
                <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                  {{ item.scope || 'system' }}
                </span>
              </div>
              <p class="mt-3 text-sm leading-7 text-slate-300">{{ item.description || '暂无说明。' }}</p>
            </article>
          </section>
        </div>

        <div v-else-if="activeTab === 'configs'" class="mt-6 grid gap-6 xl:grid-cols-[0.92fr_1.08fr]">
          <section class="club-panel-muted rounded-[24px] p-5">
            <h3 class="font-display text-2xl font-bold text-white">写入网站配置</h3>
            <div class="mt-5 space-y-4">
              <input v-model="newConfig.config_key" type="text" class="club-input w-full px-4 py-4" placeholder="例如：site_banner_text" />
              <input v-model="newConfig.config_value" type="text" class="club-input w-full px-4 py-4" placeholder="填写配置值" />
              <textarea v-model="newConfig.description" rows="3" class="club-input w-full resize-none px-4 py-4" placeholder="配置用途说明" />
              <button type="button" class="club-button-primary rounded-2xl px-5 py-4 text-sm font-semibold" @click="handleSaveConfig">
                保存配置
              </button>
            </div>
          </section>

          <section class="space-y-4">
            <article v-for="item in siteConfigs" :key="item.id || item.config_key" class="card-hover club-panel-muted rounded-[24px] p-5">
              <div class="flex flex-wrap items-center gap-3">
                <p class="font-semibold text-white">{{ item.config_key }}</p>
                <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                  最近更新
                </span>
              </div>
              <p class="mt-3 break-all text-sm leading-7 text-slate-300">{{ item.config_value }}</p>
              <p class="mt-2 text-xs text-slate-500">{{ item.description || '暂无说明。' }}</p>
            </article>
          </section>
        </div>

        <div v-else class="mt-6 space-y-6">
          <section class="club-panel-muted rounded-[24px] p-5">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p class="text-sm text-slate-400">Leader Assignment</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">社团负责人指派</h3>
              </div>
              <div class="w-full max-w-sm">
                <select v-model="selectedGovernanceClubId" class="club-input w-full px-4 py-4">
                  <option v-for="club in clubs" :key="club.id" :value="club.id">{{ club.name }}</option>
                </select>
              </div>
            </div>

            <div v-if="governanceMembers.length" class="mt-5 grid gap-4 md:grid-cols-2">
              <article v-for="member in governanceMembers" :key="member.id" class="rounded-[20px] border border-white/8 bg-white/[0.03] p-5">
                <div class="flex items-start justify-between gap-4">
                  <div>
                    <p class="font-semibold text-white">{{ member.profiles?.full_name || member.profiles?.username || '未命名成员' }}</p>
                    <p class="mt-2 text-sm text-slate-400">{{ member.clubs?.name }}</p>
                    <p class="mt-2 text-xs text-slate-500">
                      当前身份：{{ clubMemberRoleLabelMap[member.role] || member.role }}
                    </p>
                  </div>
                  <UserCog class="h-5 w-5 text-[#f2ddae]" />
                </div>
                <select
                  class="club-input mt-4 w-full px-4 py-3"
                  :value="member.role"
                  @change="handleClubMemberRoleUpdate(member.id, ($event.target as HTMLSelectElement).value)"
                >
                  <option value="member">普通成员</option>
                  <option value="leader">社团负责人</option>
                  <option value="admin">社团管理员</option>
                </select>
              </article>
            </div>

            <div
              v-else
              class="mt-5 flex min-h-48 flex-col items-center justify-center rounded-[24px] border border-white/8 bg-white/[0.03] p-8 text-center"
            >
              <UserCog class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">当前社团暂无成员可指派</p>
              <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                先让学生通过加入社团申请，之后校团委即可在这里指定负责人。
              </p>
            </div>
          </section>

          <div class="grid gap-6 xl:grid-cols-2">
          <section class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="font-display text-2xl font-bold text-white">社团治理</h3>
              <Sparkles class="h-5 w-5 text-[#f2ddae]" />
            </div>
            <article v-for="club in filteredClubs" :key="club.id" class="card-hover club-panel-muted rounded-[24px] p-5">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-semibold text-white">{{ club.name }}</p>
                  <p class="mt-2 text-sm leading-7 text-slate-300">{{ club.description || '暂无社团介绍。' }}</p>
                  <p class="mt-3 text-xs text-slate-500">创建者：{{ club.profiles?.full_name || '未知' }}</p>
                </div>
                <button type="button" class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="handleClubStatus(club)">
                  {{ club.status === 'active' ? '设为停用' : '恢复活跃' }}
                </button>
              </div>
            </article>
          </section>

          <section class="space-y-4">
            <div class="flex items-center justify-between">
              <h3 class="font-display text-2xl font-bold text-white">活动总览</h3>
              <ShieldCheck class="h-5 w-5 text-[#9fc0f7]" />
            </div>
            <article v-for="activity in filteredActivities" :key="activity.id" class="card-hover club-panel-muted rounded-[24px] p-5">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-semibold text-white">{{ activity.title }}</p>
                  <p class="mt-2 text-sm text-slate-300">{{ activity.clubs?.name || '校园活动' }}</p>
                  <p class="mt-3 text-xs text-slate-500">
                    {{ new Date(activity.start_time).toLocaleString('zh-CN') }}
                  </p>
                </div>
                <div class="flex flex-col items-end gap-3">
                  <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                    {{ activity.status }}
                  </span>
                  <button
                    type="button"
                    class="flex items-center gap-2 rounded-2xl border border-rose-400/20 bg-rose-400/10 px-4 py-2 text-sm font-semibold text-rose-100 transition-colors duration-200 hover:bg-rose-400/16 disabled:cursor-not-allowed disabled:opacity-60"
                    :disabled="deletingActivityId === activity.id"
                    @click="handleActivityDelete(activity)"
                  >
                    <Loader2 v-if="deletingActivityId === activity.id" class="h-4 w-4 animate-spin" />
                    <Trash2 v-else class="h-4 w-4" />
                    {{ deletingActivityId === activity.id ? '删除中...' : '删除活动' }}
                  </button>
                </div>
              </div>
            </article>
          </section>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
