<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  Archive,
  ArrowLeft,
  Calendar,
  CheckCheck,
  Clock3,
  Loader2,
  MapPin,
  MessageSquarePlus,
  Send,
  ShieldCheck,
  Users
} from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()

const activityId = route.params.id as string
const activity = ref<any>(null)
const loading = ref(true)
const working = ref(false)
const archives = ref<any[]>([])
const registrations = ref<any[]>([])
const isManager = ref(false)
const registrationMessage = ref({ text: '', type: '' })

const currentRegistration = computed(() => {
  return registrations.value.find(item => item.user_id === authStore.user?.id) || null
})

const registrationSummary = computed(() => {
  const approved = registrations.value.filter(item => item.status === 'approved').length
  const checkedIn = registrations.value.filter(item => item.check_in_time).length
  return {
    total: registrations.value.length,
    approved,
    checkedIn
  }
})

const canCheckIn = computed(() => {
  return currentRegistration.value?.status === 'approved' && !currentRegistration.value?.check_in_time
})

const canFeedback = computed(() => {
  return !!currentRegistration.value?.check_in_time
})

const feedbackText = ref('')
const archiveForm = ref({
  title: '',
  description: '',
  file_url: ''
})

const fetchActivity = async () => {
  loading.value = true

  try {
    await authStore.ensureUser()

    const { data, error } = await supabase
      .from('activities')
      .select('*, clubs(id, name, logo_url)')
      .eq('id', activityId)
      .single()

    if (error) throw error

    activity.value = data

    const [{ data: registrationData, error: registrationError }, archiveResponse] = await Promise.all([
      supabase
        .from('activity_registrations')
        .select('*')
        .eq('activity_id', activityId)
        .order('created_at', { ascending: false }),
      supabase
        .from('activity_archives')
        .select('*')
        .eq('activity_id', activityId)
        .order('created_at', { ascending: false })
    ])

    if (registrationError) throw registrationError

    registrations.value = registrationData || []
    feedbackText.value = currentRegistration.value?.feedback || ''

    if (!archiveResponse.error) {
      archives.value = archiveResponse.data || []
    } else {
      archives.value = []
      console.warn('activity_archives 表尚未创建，暂时跳过资料归档读取。')
    }

    if (authStore.user) {
      const [{ data: membership }, { data: profile }] = await Promise.all([
        supabase
          .from('club_members')
          .select('id')
          .eq('club_id', data.club_id)
          .eq('user_id', authStore.user.id)
          .eq('role', 'admin')
          .maybeSingle(),
        supabase
          .from('profiles')
          .select('role')
          .eq('id', authStore.user.id)
          .maybeSingle()
      ])

      isManager.value = !!membership || ['league_committee', 'admin'].includes(profile?.role || '')
    }
  } catch (error) {
    console.error('Error fetching activity detail:', error)
    router.push('/dashboard')
  } finally {
    loading.value = false
  }
}

const handleRegister = async () => {
  if (!authStore.user) {
    router.push('/')
    return
  }

  working.value = true
  registrationMessage.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('activity_registrations')
      .insert({
        activity_id: activityId,
        user_id: authStore.user.id,
        status: 'pending'
      })

    if (error) throw error

    registrationMessage.value = { text: '报名申请已提交，等待社团管理员审核。', type: 'success' }
    await fetchActivity()
  } catch (error: any) {
    registrationMessage.value = { text: error.message || '报名失败，请稍后重试。', type: 'error' }
  } finally {
    working.value = false
  }
}

const handleCheckIn = async () => {
  if (!currentRegistration.value) return

  working.value = true
  registrationMessage.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('activity_registrations')
      .update({ check_in_time: new Date().toISOString() })
      .eq('id', currentRegistration.value.id)

    if (error) throw error

    registrationMessage.value = { text: '签到成功，欢迎参与本次活动。', type: 'success' }
    await fetchActivity()
  } catch (error: any) {
    registrationMessage.value = { text: error.message || '签到失败，请稍后重试。', type: 'error' }
  } finally {
    working.value = false
  }
}

const handleFeedback = async () => {
  if (!currentRegistration.value) return

  working.value = true
  registrationMessage.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('activity_registrations')
      .update({ feedback: feedbackText.value.trim() })
      .eq('id', currentRegistration.value.id)

    if (error) throw error

    registrationMessage.value = { text: '反馈已提交，感谢你的建议。', type: 'success' }
    await fetchActivity()
  } catch (error: any) {
    registrationMessage.value = { text: error.message || '反馈提交失败。', type: 'error' }
  } finally {
    working.value = false
  }
}

const handleArchiveCreate = async () => {
  if (!authStore.user || !archiveForm.value.title.trim()) return

  working.value = true
  registrationMessage.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('activity_archives')
      .insert({
        activity_id: activityId,
        title: archiveForm.value.title.trim(),
        description: archiveForm.value.description.trim(),
        file_url: archiveForm.value.file_url.trim() || null,
        created_by: authStore.user.id
      })

    if (error) throw error

    archiveForm.value = { title: '', description: '', file_url: '' }
    registrationMessage.value = { text: '资料归档已保存。', type: 'success' }
    await fetchActivity()
  } catch (error: any) {
    registrationMessage.value = { text: error.message || '资料归档失败。', type: 'error' }
  } finally {
    working.value = false
  }
}

onMounted(() => {
  fetchActivity()
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
            <p class="text-sm text-slate-400">Activity Workflow</p>
            <h1 class="font-display text-3xl font-bold text-white">活动执行与反馈</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">在线报名</span>
          <span class="rounded-full border border-white/8 px-4 py-2">现场签到</span>
          <span class="rounded-full border border-white/8 px-4 py-2">资料归档</span>
        </div>
      </header>

      <div v-if="loading" class="club-panel flex min-h-[360px] flex-col items-center justify-center p-10">
        <Loader2 class="h-10 w-10 animate-spin text-[#f2ddae]" />
        <p class="mt-4 text-sm text-slate-400">正在加载活动详情...</p>
      </div>

      <main v-else-if="activity" class="grid gap-6 xl:grid-cols-[1.06fr_0.94fr]">
        <section class="space-y-6">
          <article class="club-panel overflow-hidden p-2">
            <div class="relative overflow-hidden rounded-[28px]">
              <img
                :src="`https://picsum.photos/seed/${activity.id}/1200/560`"
                :alt="activity.title"
                class="h-[320px] w-full object-cover"
              />
              <div class="absolute inset-0 bg-gradient-to-t from-[#05070d] via-[#05070d]/40 to-transparent" />
              <div class="absolute inset-x-0 bottom-0 p-8">
                <div class="flex flex-wrap items-center gap-3">
                  <span class="rounded-full border border-[#e7d29c]/28 bg-[#e7d29c]/10 px-3 py-1 text-xs text-[#f2ddae]">
                    {{ activity.clubs?.name || '校园活动' }}
                  </span>
                  <span class="rounded-full border border-white/10 px-3 py-1 text-xs text-slate-200">
                    {{ activity.status }}
                  </span>
                </div>
                <h2 class="mt-4 max-w-3xl font-display text-4xl font-bold text-white md:text-5xl">
                  {{ activity.title }}
                </h2>
              </div>
            </div>

            <div class="grid gap-6 p-6 md:grid-cols-3">
              <article class="club-panel-muted p-5">
                <Calendar class="h-5 w-5 text-[#f2ddae]" />
                <p class="mt-3 text-sm text-slate-400">活动日期</p>
                <p class="mt-1 font-semibold text-white">{{ new Date(activity.start_time).toLocaleDateString('zh-CN') }}</p>
              </article>
              <article class="club-panel-muted p-5">
                <Clock3 class="h-5 w-5 text-[#9fc0f7]" />
                <p class="mt-3 text-sm text-slate-400">开始时间</p>
                <p class="mt-1 font-semibold text-white">
                  {{ new Date(activity.start_time).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' }) }}
                </p>
              </article>
              <article class="club-panel-muted p-5">
                <MapPin class="h-5 w-5 text-emerald-300" />
                <p class="mt-3 text-sm text-slate-400">活动地点</p>
                <p class="mt-1 font-semibold text-white">{{ activity.location || '校内场地待定' }}</p>
              </article>
            </div>
          </article>

          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Activity Description</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">活动介绍</h3>
              </div>
              <button class="club-button-secondary rounded-2xl px-4 py-3 text-sm font-semibold" @click="router.push(`/club/${activity.club_id}`)">
                查看社团主页
              </button>
            </div>
            <p class="whitespace-pre-wrap text-sm leading-7 text-slate-300">
              {{ activity.description || '暂无详细活动描述。' }}
            </p>
          </section>

          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Archive</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">活动资料归档</h3>
              </div>
              <Archive class="h-5 w-5 text-[#f2ddae]" />
            </div>

            <div v-if="archives.length" class="space-y-4">
              <article v-for="item in archives" :key="item.id" class="card-hover club-panel-muted rounded-[24px] p-5">
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <h4 class="text-lg font-semibold text-white">{{ item.title }}</h4>
                  <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                    {{ new Date(item.created_at).toLocaleDateString('zh-CN') }}
                  </span>
                </div>
                <p class="mt-3 text-sm leading-7 text-slate-300">{{ item.description || '暂无归档说明。' }}</p>
                <a
                  v-if="item.file_url"
                  :href="item.file_url"
                  target="_blank"
                  rel="noreferrer"
                  class="mt-4 inline-flex text-sm font-medium text-[#9fc0f7]"
                >
                  打开归档资料
                </a>
              </article>
            </div>

            <div
              v-else
              class="club-panel-muted flex min-h-48 flex-col items-center justify-center rounded-[24px] p-8 text-center"
            >
              <Archive class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">暂未上传活动资料</p>
              <p class="mt-2 text-sm leading-6 text-slate-400">活动结束后可在这里保存成果文档、复盘链接和现场照片地址。</p>
            </div>
          </section>
        </section>

        <aside class="space-y-6">
          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Participation</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">报名与签到</h3>
              </div>
              <Users class="h-5 w-5 text-[#f2ddae]" />
            </div>

            <div class="grid gap-4 md:grid-cols-3 xl:grid-cols-1">
              <article class="club-panel-muted p-5">
                <p class="text-sm text-slate-400">报名人数</p>
                <p class="mt-2 font-display text-3xl font-bold text-white">{{ registrationSummary.total }}</p>
              </article>
              <article class="club-panel-muted p-5">
                <p class="text-sm text-slate-400">审核通过</p>
                <p class="mt-2 font-display text-3xl font-bold text-white">{{ registrationSummary.approved }}</p>
              </article>
              <article class="club-panel-muted p-5">
                <p class="text-sm text-slate-400">现场签到</p>
                <p class="mt-2 font-display text-3xl font-bold text-white">{{ registrationSummary.checkedIn }}</p>
              </article>
            </div>

            <div
              v-if="registrationMessage.text"
              class="mt-5 rounded-2xl border px-4 py-3 text-sm leading-6"
              :class="registrationMessage.type === 'success'
                ? 'border-emerald-400/18 bg-emerald-400/10 text-emerald-100'
                : 'border-rose-400/18 bg-rose-400/10 text-rose-100'"
            >
              {{ registrationMessage.text }}
            </div>

            <div class="mt-5 space-y-4">
              <div v-if="!currentRegistration" class="club-panel-muted rounded-[24px] p-5">
                <p class="text-sm leading-7 text-slate-300">
                  还未报名时，可直接在线提交申请；管理员审核通过后再进行现场签到与反馈。
                </p>
                <button
                  type="button"
                  :disabled="working"
                  class="club-button-primary mt-4 flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-sm font-semibold disabled:opacity-60"
                  @click="handleRegister"
                >
                  <Loader2 v-if="working" class="h-5 w-5 animate-spin" />
                  <template v-else>
                    <Send class="h-5 w-5" />
                    提交在线报名
                  </template>
                </button>
              </div>

              <div v-else class="club-panel-muted rounded-[24px] p-5">
                <div class="flex flex-wrap items-center gap-3">
                  <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                    报名状态：{{ currentRegistration.status }}
                  </span>
                  <span v-if="currentRegistration.check_in_time" class="rounded-full border border-emerald-400/18 bg-emerald-400/10 px-3 py-1 text-xs text-emerald-100">
                    已签到
                  </span>
                </div>

                <div class="mt-4 space-y-3 text-sm leading-7 text-slate-300">
                  <p v-if="currentRegistration.status === 'pending'">你的报名正在等待管理员审核，请稍后查看状态。</p>
                  <p v-else-if="currentRegistration.status === 'approved' && !currentRegistration.check_in_time">
                    报名已通过，活动现场可在此完成签到。
                  </p>
                  <p v-else-if="currentRegistration.status === 'rejected'">报名未通过，可联系社团管理员了解原因。</p>
                  <p v-else>已完成签到，欢迎提交现场反馈与体验建议。</p>
                </div>

                <button
                  v-if="canCheckIn"
                  type="button"
                  :disabled="working"
                  class="mt-4 rounded-2xl border border-emerald-400/20 bg-emerald-400/10 px-5 py-4 text-sm font-semibold text-emerald-100"
                  @click="handleCheckIn"
                >
                  <span class="flex items-center justify-center gap-2">
                    <CheckCheck class="h-4 w-4" />
                    现场签到
                  </span>
                </button>
              </div>
            </div>
          </section>

          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Feedback</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">活动反馈</h3>
              </div>
              <MessageSquarePlus class="h-5 w-5 text-[#9fc0f7]" />
            </div>

            <textarea
              v-model="feedbackText"
              rows="4"
              class="club-input w-full resize-none px-4 py-4"
              placeholder="从组织流程、现场体验、活动收获等角度留下你的反馈..."
              :disabled="!canFeedback"
            />
            <button
              type="button"
              :disabled="working || !canFeedback"
              class="club-button-secondary mt-4 flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-sm font-semibold disabled:opacity-60"
              @click="handleFeedback"
            >
              <Send class="h-4 w-4" />
              提交反馈
            </button>
          </section>

          <section v-if="isManager" class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Manager Tools</p>
                <h3 class="mt-1 font-display text-2xl font-bold text-white">资料归档上传</h3>
              </div>
              <ShieldCheck class="h-5 w-5 text-[#f2ddae]" />
            </div>

            <div class="space-y-4">
              <input
                v-model="archiveForm.title"
                type="text"
                class="club-input w-full px-4 py-4"
                placeholder="归档标题，例如：活动总结与照片合集"
              />
              <textarea
                v-model="archiveForm.description"
                rows="3"
                class="club-input w-full resize-none px-4 py-4"
                placeholder="补充归档说明"
              />
              <input
                v-model="archiveForm.file_url"
                type="url"
                class="club-input w-full px-4 py-4"
                placeholder="归档链接或网盘地址"
              />
              <button
                type="button"
                :disabled="working"
                class="club-button-primary flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-sm font-semibold disabled:opacity-60"
                @click="handleArchiveCreate"
              >
                <Archive class="h-4 w-4" />
                保存归档
              </button>
            </div>
          </section>
        </aside>
      </main>
    </div>
  </div>
</template>
