<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowLeft,
  ClipboardList,
  FileClock,
  Loader2,
  PiggyBank,
  Send,
  Sparkles,
  Users
} from 'lucide-vue-next'
import {
  applicationStatusLabel,
  applicationStatusTheme,
  defaultApplicationTypes,
  type ApplicationDraft
} from '../lib/portal'

const router = useRouter()
const route = useRoute()
const authStore = useAuthStore()

const loading = ref(true)
const submitting = ref(false)
const message = ref({ text: '', type: '' })

const clubs = ref<any[]>([])
const activities = ref<any[]>([])
const applications = ref<any[]>([])
const applicationTypes = ref<ApplicationDraft[]>(defaultApplicationTypes)
const applicationTypeMap = ref<Record<string, { id?: string }>>({})

const form = ref({
  typeKey: 'join_club',
  clubId: '',
  activityId: '',
  title: '',
  amount: '',
  reason: '',
  detail: ''
})

const selectedType = computed(() => {
  return applicationTypes.value.find(item => item.key === form.value.typeKey) || defaultApplicationTypes[0]
})

const selectedClub = computed(() => {
  return clubs.value.find(item => item.id === form.value.clubId) || null
})

const selectedActivityOptions = computed(() => {
  if (!form.value.clubId) {
    return activities.value
  }

  return activities.value.filter(item => item.club_id === form.value.clubId)
})

const pageIntro = computed(() => {
  if (form.value.typeKey === 'activity_fund') {
    return {
      title: '发起活动经费申请',
      description: '填写预算用途、金额与活动关联信息，系统会进入后台审批流程。'
    }
  }

  if (form.value.typeKey === 'resource_support') {
    return {
      title: '提交资源支持申请',
      description: '用于申请场地、设备、宣传等校级公共资源，便于统一协调。'
    }
  }

  return {
    title: '提交社团加入申请',
    description: '围绕目标社团填写申请理由，社团管理员可在后台完成审批。'
  }
})

watch(
  () => form.value.clubId,
  () => {
    if (form.value.activityId && !selectedActivityOptions.value.some(item => item.id === form.value.activityId)) {
      form.value.activityId = ''
    }
  }
)

const hydrateFromQuery = () => {
  const queryType = typeof route.query.type === 'string' ? route.query.type : ''
  const queryClubId = typeof route.query.clubId === 'string' ? route.query.clubId : ''
  const queryActivityId = typeof route.query.activityId === 'string' ? route.query.activityId : ''

  if (queryType && applicationTypes.value.some(item => item.key === queryType)) {
    form.value.typeKey = queryType
  }

  if (queryClubId) {
    form.value.clubId = queryClubId
  }

  if (queryActivityId) {
    form.value.activityId = queryActivityId
  }
}

const fetchBootstrap = async () => {
  loading.value = true
  message.value = { text: '', type: '' }

  try {
    const user = await authStore.ensureUser()

    if (!user) {
      router.push('/')
      return
    }

    const [
      { data: clubsData, error: clubsError },
      { data: activitiesData, error: activitiesError },
      { data: typesData, error: typesError },
      { data: myAppsData, error: appError }
    ] = await Promise.all([
      supabase
        .from('clubs')
        .select('id, name, description, status')
        .eq('status', 'active')
        .order('created_at', { ascending: false }),
      supabase
        .from('activities')
        .select('id, title, club_id, start_time, status')
        .order('start_time', { ascending: false }),
      supabase
        .from('application_types')
        .select('*')
        .order('name', { ascending: true }),
      supabase
        .from('user_applications')
        .select('*, application_types(name)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false })
    ])

    if (clubsError) throw clubsError
    if (activitiesError) throw activitiesError
    if (typesError) {
      console.warn('Could not fetch application types, using defaults:', typesError.message)
    }
    if (appError) throw appError

    clubs.value = clubsData || []
    activities.value = activitiesData || []
    applications.value = myAppsData || []

    if (typesData?.length) {
      applicationTypes.value = typesData.map((item: any) => {
        const key = (item.key || item.code || item.name || '')
          .toString()
          .trim()
          .toLowerCase()
          .replace(/\s+/g, '_')

        applicationTypeMap.value[key] = { id: item.id }

        return {
          key,
          name: item.name,
          description: item.description || '已在后台定义的申请类型。',
          scope: item.scope || 'system'
        }
      })
    }

    hydrateFromQuery()
  } catch (error) {
    message.value = { text: '申请中心加载失败，请稍后重试。', type: 'error' }
    console.error('Error fetching applications page data:', error)
  } finally {
    loading.value = false
  }
}

const resetForm = () => {
  form.value = {
    typeKey: form.value.typeKey,
    clubId: '',
    activityId: '',
    title: '',
    amount: '',
    reason: '',
    detail: ''
  }
}

const handleSubmit = async () => {
  if (!authStore.user) {
    router.push('/')
    return
  }

  if (!form.value.reason.trim()) {
    message.value = { text: '请填写申请理由。', type: 'error' }
    return
  }

  if (selectedType.value.scope === 'club' && !form.value.clubId) {
    message.value = { text: '请先选择目标社团。', type: 'error' }
    return
  }

  if (form.value.typeKey === 'activity_fund' && !form.value.amount) {
    message.value = { text: '经费申请请填写预算金额。', type: 'error' }
    return
  }

  submitting.value = true
  message.value = { text: '', type: '' }

  try {
    const content = {
      application_key: selectedType.value.key,
      application_name: selectedType.value.name,
      club_id: form.value.clubId || null,
      club_name: selectedClub.value?.name || null,
      activity_id: form.value.activityId || null,
      activity_title: selectedActivityOptions.value.find(item => item.id === form.value.activityId)?.title || null,
      title: form.value.title || selectedType.value.name,
      amount: form.value.amount ? Number(form.value.amount) : null,
      reason: form.value.reason.trim(),
      detail: form.value.detail.trim(),
      applicant_email: authStore.user.email || null
    }

    const { error } = await supabase
      .from('user_applications')
      .insert({
        type_id: applicationTypeMap.value[selectedType.value.key]?.id || null,
        user_id: authStore.user.id,
        content,
        status: 'pending'
      })

    if (error) throw error

    message.value = { text: '申请已提交，后台审批流程已启动。', type: 'success' }
    resetForm()
    await fetchBootstrap()
  } catch (error: any) {
    message.value = { text: error.message || '提交申请失败，请稍后重试。', type: 'error' }
  } finally {
    submitting.value = false
  }
}

onMounted(() => {
  fetchBootstrap()
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
            <p class="text-sm text-slate-400">Application Center</p>
            <h1 class="font-display text-3xl font-bold text-white">中北大学社团活动</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">加入社团</span>
          <span class="rounded-full border border-white/8 px-4 py-2">经费申请</span>
          <span class="rounded-full border border-white/8 px-4 py-2">审批追踪</span>
        </div>
      </header>

      <div class="grid gap-6 xl:grid-cols-[1.08fr_0.92fr]">
        <section class="club-panel overflow-hidden p-6 md:p-8">
          <div class="grid gap-6 lg:grid-cols-[1fr_0.88fr]">
            <div class="space-y-5">
              <div class="inline-flex items-center gap-2 rounded-full border border-[#e7d29c]/18 bg-[#e7d29c]/10 px-4 py-2 text-sm text-[#f2ddae]">
                <Sparkles class="h-4 w-4" />
                统一承接个人申请与审批流转
              </div>

              <div>
                <h2 class="font-display text-4xl font-bold text-white">{{ pageIntro.title }}</h2>
                <p class="mt-3 max-w-2xl text-base leading-7 text-slate-300">{{ pageIntro.description }}</p>
              </div>

              <div class="grid gap-4 md:grid-cols-3">
                <article class="club-panel-muted p-5">
                  <Users class="h-5 w-5 text-[#f2ddae]" />
                  <p class="mt-3 font-display text-2xl font-bold text-white">{{ clubs.length }}</p>
                  <p class="mt-2 text-sm text-slate-400">可申请加入社团</p>
                </article>
                <article class="club-panel-muted p-5">
                  <PiggyBank class="h-5 w-5 text-[#9fc0f7]" />
                  <p class="mt-3 font-display text-2xl font-bold text-white">
                    {{ applications.filter(item => item.content?.application_key === 'activity_fund').length }}
                  </p>
                  <p class="mt-2 text-sm text-slate-400">历史经费申请</p>
                </article>
                <article class="club-panel-muted p-5">
                  <FileClock class="h-5 w-5 text-emerald-300" />
                  <p class="mt-3 font-display text-2xl font-bold text-white">
                    {{ applications.filter(item => item.status === 'pending').length }}
                  </p>
                  <p class="mt-2 text-sm text-slate-400">等待审批中</p>
                </article>
              </div>
            </div>

            <div class="club-panel-muted p-5">
              <p class="text-sm text-slate-400">申请须知</p>
              <div class="mt-4 space-y-3 text-sm leading-7 text-slate-300">
                <p>加入社团申请由对应社团管理员审批，通过后会自动写入成员信息。</p>
                <p>活动经费、资源支持申请会进入后台审批队列，便于统一留痕。</p>
                <p>提交后可在右侧列表持续查看处理状态、备注和时间。</p>
              </div>
            </div>
          </div>
        </section>

        <section class="club-panel p-6 md:p-8">
          <div class="mb-6">
            <p class="text-sm text-slate-400">New Application</p>
            <h3 class="mt-1 font-display text-2xl font-bold text-white">发起申请</h3>
          </div>

          <div
            v-if="message.text"
            class="mb-5 rounded-2xl border px-4 py-3 text-sm leading-6"
            :class="message.type === 'success'
              ? 'border-emerald-400/18 bg-emerald-400/10 text-emerald-100'
              : 'border-rose-400/18 bg-rose-400/10 text-rose-100'"
          >
            {{ message.text }}
          </div>

          <form class="space-y-4" @submit.prevent="handleSubmit">
            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">申请类型</label>
              <select v-model="form.typeKey" class="club-input w-full px-4 py-4">
                <option v-for="item in applicationTypes" :key="item.key" :value="item.key">
                  {{ item.name }}
                </option>
              </select>
              <p class="text-xs text-slate-500">{{ selectedType.description }}</p>
            </div>

            <div v-if="selectedType.scope === 'club' || form.typeKey === 'activity_fund'" class="space-y-2">
              <label class="text-sm font-medium text-slate-300">目标社团</label>
              <select v-model="form.clubId" class="club-input w-full px-4 py-4">
                <option value="">请选择社团</option>
                <option v-for="club in clubs" :key="club.id" :value="club.id">{{ club.name }}</option>
              </select>
            </div>

            <div v-if="form.typeKey === 'activity_fund'" class="space-y-2">
              <label class="text-sm font-medium text-slate-300">关联活动</label>
              <select v-model="form.activityId" class="club-input w-full px-4 py-4">
                <option value="">请选择活动</option>
                <option v-for="activity in selectedActivityOptions" :key="activity.id" :value="activity.id">
                  {{ activity.title }}
                </option>
              </select>
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">申请标题</label>
              <input
                v-model="form.title"
                type="text"
                placeholder="例如：社团纳新申请 / 迎新晚会经费申请"
                class="club-input w-full px-4 py-4"
              />
            </div>

            <div v-if="form.typeKey === 'activity_fund'" class="space-y-2">
              <label class="text-sm font-medium text-slate-300">预算金额</label>
              <input
                v-model="form.amount"
                type="number"
                min="0"
                placeholder="请输入申请金额"
                class="club-input w-full px-4 py-4"
              />
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">申请理由</label>
              <textarea
                v-model="form.reason"
                rows="4"
                placeholder="简要说明你的申请诉求、加入原因或预算用途"
                class="club-input w-full resize-none px-4 py-4"
              />
            </div>

            <div class="space-y-2">
              <label class="text-sm font-medium text-slate-300">补充说明</label>
              <textarea
                v-model="form.detail"
                rows="3"
                placeholder="可填写个人特长、经费明细、执行计划等内容"
                class="club-input w-full resize-none px-4 py-4"
              />
            </div>

            <button
              type="submit"
              :disabled="submitting || loading"
              class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:opacity-60"
            >
              <Loader2 v-if="submitting" class="h-5 w-5 animate-spin" />
              <template v-else>
                <Send class="h-5 w-5" />
                提交申请
              </template>
            </button>
          </form>
        </section>
      </div>

      <section class="club-panel p-6 md:p-8">
        <div class="mb-6 flex items-center justify-between">
          <div>
            <p class="text-sm text-slate-400">My Applications</p>
            <h3 class="mt-1 font-display text-2xl font-bold text-white">我的申请记录</h3>
          </div>
          <div class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
            共 {{ applications.length }} 条
          </div>
        </div>

        <div v-if="loading" class="flex justify-center py-16">
          <Loader2 class="h-8 w-8 animate-spin text-[#f2ddae]" />
        </div>

        <div v-else-if="applications.length" class="grid gap-4 lg:grid-cols-2">
          <article
            v-for="item in applications"
            :key="item.id"
            class="card-hover club-panel-muted rounded-[24px] p-5"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <p class="text-sm text-slate-400">{{ item.application_types?.name || item.content?.application_name || '自定义申请' }}</p>
                <h4 class="mt-2 text-xl font-semibold text-white">
                  {{ item.content?.title || item.content?.club_name || '未命名申请' }}
                </h4>
              </div>
              <span
                class="rounded-full border px-3 py-1 text-xs"
                :class="applicationStatusTheme[item.status] || applicationStatusTheme.pending"
              >
                {{ applicationStatusLabel[item.status] || '处理中' }}
              </span>
            </div>

            <p class="mt-4 line-clamp-3 text-sm leading-6 text-slate-300">
              {{ item.content?.reason || '暂无申请说明。' }}
            </p>

            <div class="mt-5 flex flex-wrap gap-3 text-xs text-slate-500">
              <span v-if="item.content?.club_name" class="rounded-full border border-white/8 px-3 py-1">
                {{ item.content.club_name }}
              </span>
              <span v-if="item.content?.amount" class="rounded-full border border-white/8 px-3 py-1">
                {{ Number(item.content.amount).toLocaleString('zh-CN') }} 元
              </span>
              <span class="rounded-full border border-white/8 px-3 py-1">
                {{ new Date(item.created_at).toLocaleString('zh-CN') }}
              </span>
            </div>

            <div v-if="item.admin_remark" class="mt-4 rounded-2xl border border-white/8 bg-white/5 px-4 py-3 text-sm text-slate-300">
              审批备注：{{ item.admin_remark }}
            </div>
          </article>
        </div>

        <div
          v-else
          class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center"
        >
          <ClipboardList class="h-8 w-8 text-slate-500" />
          <p class="mt-4 font-display text-2xl font-bold text-white">你还没有提交任何申请</p>
          <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
            这里会展示加入社团、活动经费和资源支持等申请的完整处理记录。
          </p>
        </div>
      </section>
    </div>
  </div>
</template>
