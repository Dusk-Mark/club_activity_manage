<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowLeft,
  CalendarClock,
  ClipboardCheck,
  Loader2,
  Send,
  ShieldCheck,
  Users
} from 'lucide-vue-next'
import { clubMemberRoleLabelMap } from '../lib/portal'

const router = useRouter()
const authStore = useAuthStore()

const loading = ref(true)
const submitting = ref(false)
const pageMessage = ref({ text: '', type: '' })

const memberships = ref<any[]>([])
const members = ref<any[]>([])
const tasks = ref<any[]>([])
const userRole = ref('student')
const selectedClubId = ref('')

const taskForm = ref({
  title: '',
  description: '',
  priority: 'medium',
  due_date: '',
  assignee_id: '',
  status: 'todo'
})

const selectedMembership = computed(() => {
  return memberships.value.find(item => item.club_id === selectedClubId.value) || null
})

const selectedClubName = computed(() => {
  return selectedMembership.value?.clubs?.name || '社团任务'
})

const hasClubAdminFallback = computed(() => {
  return userRole.value === 'club_admin' && !!selectedMembership.value
})

const currentTaskPublisherLabel = computed(() => {
  if (['league_committee', 'admin'].includes(userRole.value)) {
    return userRole.value === 'league_committee' ? '校团委' : '系统管理员'
  }

  if (hasClubAdminFallback.value && !['leader', 'admin'].includes(selectedMembership.value?.role || '')) {
    return '社团管理员'
  }

  return clubMemberRoleLabelMap[selectedMembership.value?.role || 'member'] || '普通成员'
})

const canPublishTask = computed(() => {
  if (['league_committee', 'admin'].includes(userRole.value)) {
    return true
  }

  if (['leader', 'admin'].includes(selectedMembership.value?.role || '')) {
    return true
  }

  return hasClubAdminFallback.value
})

const resolveMemberName = (userId?: string | null) => {
  if (!userId) return '未知成员'

  const matched = members.value.find(item => item.user_id === userId)
  return matched?.profiles?.full_name || matched?.profiles?.username || '未知成员'
}

watch(selectedClubId, async () => {
  if (!selectedClubId.value) return
  await Promise.all([fetchMembers(), fetchTasks()])
})

const fetchBootstrap = async () => {
  loading.value = true

  try {
    const user = await authStore.ensureUser()

    if (!user) {
      router.push('/')
      return
    }

    const [{ data: profile }, { data: membershipData, error: membershipError }] = await Promise.all([
      supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle(),
      supabase
        .from('club_members')
        .select('club_id, role, clubs(id, name)')
        .eq('user_id', user.id)
    ])

    if (membershipError) throw membershipError

    userRole.value = profile?.role || 'student'
    memberships.value = membershipData || []

    if (memberships.value.length && !selectedClubId.value) {
      selectedClubId.value = memberships.value[0].club_id
    }

    if (selectedClubId.value) {
      await Promise.all([fetchMembers(), fetchTasks()])
    }
  } catch (error) {
    pageMessage.value = { text: '任务页面加载失败，请稍后重试。', type: 'error' }
    console.error('Error loading task page:', error)
  } finally {
    loading.value = false
  }
}

const fetchMembers = async () => {
  if (!selectedClubId.value) return

  const { data, error } = await supabase
    .from('club_members')
    .select('user_id, role, profiles(full_name, username, avatar_url)')
    .eq('club_id', selectedClubId.value)
    .order('joined_at', { ascending: true })

  if (error) throw error

  members.value = data || []
}

const fetchTasks = async () => {
  if (!selectedClubId.value) return

  const { data, error } = await supabase
    .from('club_tasks')
    .select('*')
    .eq('club_id', selectedClubId.value)
    .order('created_at', { ascending: false })

  if (error) throw error

  tasks.value = data || []
}

const resetForm = () => {
  taskForm.value = {
    title: '',
    description: '',
    priority: 'medium',
    due_date: '',
    assignee_id: '',
    status: 'todo'
  }
}

const handlePublishTask = async () => {
  if (!authStore.user || !selectedClubId.value) return

  if (!taskForm.value.title.trim()) {
    pageMessage.value = { text: '请先填写任务标题。', type: 'error' }
    return
  }

  if (!canPublishTask.value) {
    pageMessage.value = { text: '只有社团负责人、社团管理员或高权限账号可以发布任务。', type: 'error' }
    return
  }

  submitting.value = true
  pageMessage.value = { text: '', type: '' }

  try {
    const { error } = await supabase
      .from('club_tasks')
      .insert({
        club_id: selectedClubId.value,
        title: taskForm.value.title.trim(),
        description: taskForm.value.description.trim(),
        priority: taskForm.value.priority,
        status: taskForm.value.status,
        due_date: taskForm.value.due_date || null,
        assignee_id: taskForm.value.assignee_id || null,
        created_by: authStore.user.id
      })

    if (error) throw error

    resetForm()
    pageMessage.value = { text: '任务已发布。', type: 'success' }
    await fetchTasks()
  } catch (error: any) {
    pageMessage.value = { text: error.message || '任务发布失败。', type: 'error' }
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
          <div>
            <p class="text-sm text-slate-400">Club Tasks</p>
            <h1 class="font-display text-3xl font-bold text-white">社团任务中心</h1>
          </div>
        </div>

        <div class="flex flex-wrap items-center gap-3 text-sm text-slate-300">
          <span class="club-pill px-4 py-2">负责人发布</span>
          <span class="rounded-full border border-white/8 px-4 py-2">任务分配</span>
          <span class="rounded-full border border-white/8 px-4 py-2">执行追踪</span>
        </div>
      </header>

      <div v-if="loading" class="club-panel flex min-h-[320px] flex-col items-center justify-center p-10">
        <Loader2 class="h-10 w-10 animate-spin text-[#f2ddae]" />
        <p class="mt-4 text-sm text-slate-400">正在加载任务中心...</p>
      </div>

      <div v-else-if="!memberships.length" class="club-panel p-10 text-center">
        <Users class="mx-auto h-14 w-14 text-slate-500" />
        <h2 class="mt-5 font-display text-3xl font-bold text-white">你还没有加入任何社团</h2>
        <p class="mx-auto mt-3 max-w-xl text-sm leading-6 text-slate-400">
          先通过社团加入申请并完成审核，之后才能查看本社团任务；被指定为负责人后即可发布任务。
        </p>
        <button
          type="button"
          class="club-button-primary mt-6 rounded-2xl px-6 py-4 text-sm font-semibold"
          @click="router.push('/clubs')"
        >
          去申请加入社团
        </button>
      </div>

      <div v-else class="grid gap-6 xl:grid-cols-[0.92fr_1.08fr]">
        <aside class="space-y-6">
          <section class="club-panel p-6">
            <p class="text-sm text-slate-400">My Clubs</p>
            <h2 class="mt-1 font-display text-2xl font-bold text-white">社团切换</h2>

            <div class="mt-5 space-y-3">
              <button
                v-for="item in memberships"
                :key="item.club_id"
                type="button"
                class="card-hover flex w-full items-center justify-between rounded-[20px] border px-4 py-4 text-left transition-all"
                :class="selectedClubId === item.club_id
                  ? 'border-[#e7d29c]/30 bg-[#e7d29c]/10'
                  : 'border-white/8 bg-white/[0.03]'"
                @click="selectedClubId = item.club_id"
              >
                <div>
                  <p class="font-semibold text-white">{{ item.clubs?.name }}</p>
                  <p class="mt-1 text-sm text-slate-400">
                    {{ clubMemberRoleLabelMap[item.role] || item.role }}
                  </p>
                </div>
                <ShieldCheck class="h-5 w-5 text-[#f2ddae]" />
              </button>
            </div>
          </section>

          <section class="club-panel p-6">
            <p class="text-sm text-slate-400">Task Publisher</p>
            <h3 class="mt-1 font-display text-2xl font-bold text-white">{{ selectedClubName }}</h3>
            <div class="mt-5 rounded-[24px] border border-white/8 bg-white/[0.03] p-5">
              <p class="text-sm leading-7 text-slate-300">
                当前身份：
                <span class="text-[#f2ddae]">
                  {{ currentTaskPublisherLabel }}
                </span>
              </p>
              <p class="mt-3 text-sm leading-7 text-slate-400">
                只有被校团委指定为社团负责人、社团成员身份为管理员，或账号本身具备社团管理员权限时，才可以发布任务。
              </p>
            </div>
          </section>
        </aside>

        <main class="space-y-6">
          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Publish Task</p>
                <h2 class="mt-1 font-display text-2xl font-bold text-white">发布社团任务</h2>
              </div>
              <ClipboardCheck class="h-5 w-5 text-[#f2ddae]" />
            </div>

            <div
              v-if="pageMessage.text"
              class="mb-5 rounded-2xl border px-4 py-3 text-sm leading-6"
              :class="pageMessage.type === 'success'
                ? 'border-emerald-400/18 bg-emerald-400/10 text-emerald-100'
                : 'border-rose-400/18 bg-rose-400/10 text-rose-100'"
            >
              {{ pageMessage.text }}
            </div>

            <div v-if="canPublishTask" class="grid gap-4">
              <input
                v-model="taskForm.title"
                type="text"
                class="club-input w-full px-4 py-4"
                placeholder="任务标题，例如：迎新海报设计"
              />
              <textarea
                v-model="taskForm.description"
                rows="4"
                class="club-input w-full resize-none px-4 py-4"
                placeholder="填写任务说明、产出要求与协作方式"
              />
              <div class="grid gap-4 md:grid-cols-2">
                <select v-model="taskForm.priority" class="club-input w-full px-4 py-4">
                  <option value="low">低优先级</option>
                  <option value="medium">中优先级</option>
                  <option value="high">高优先级</option>
                </select>
                <select v-model="taskForm.assignee_id" class="club-input w-full px-4 py-4">
                  <option value="">暂不指定负责人</option>
                  <option v-for="member in members" :key="member.user_id" :value="member.user_id">
                    {{ member.profiles?.full_name || member.profiles?.username || '未命名成员' }}
                  </option>
                </select>
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <input v-model="taskForm.due_date" type="datetime-local" class="club-input w-full px-4 py-4" />
                <select v-model="taskForm.status" class="club-input w-full px-4 py-4">
                  <option value="todo">待开始</option>
                  <option value="doing">进行中</option>
                  <option value="done">已完成</option>
                </select>
              </div>
              <button
                type="button"
                :disabled="submitting"
                class="club-button-primary flex items-center justify-center gap-2 rounded-2xl px-5 py-4 text-sm font-semibold disabled:opacity-60"
                @click="handlePublishTask"
              >
                <Loader2 v-if="submitting" class="h-5 w-5 animate-spin" />
                <template v-else>
                  <Send class="h-4 w-4" />
                  发布任务
                </template>
              </button>
            </div>

            <div
              v-else
              class="club-panel-muted flex min-h-48 flex-col items-center justify-center rounded-[24px] p-8 text-center"
            >
              <ShieldCheck class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">当前还不能发布任务</p>
              <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                请等待校团委在后台将你设为社团负责人，或确认你的社团管理员身份已同步。
              </p>
            </div>
          </section>

          <section class="club-panel p-6 md:p-8">
            <div class="mb-5 flex items-center justify-between">
              <div>
                <p class="text-sm text-slate-400">Task List</p>
                <h2 class="mt-1 font-display text-2xl font-bold text-white">当前社团任务</h2>
              </div>
              <CalendarClock class="h-5 w-5 text-[#9fc0f7]" />
            </div>

            <div v-if="tasks.length" class="space-y-4">
              <article
                v-for="task in tasks"
                :key="task.id"
                class="card-hover club-panel-muted rounded-[24px] p-5"
              >
                <div class="flex flex-col gap-5 xl:flex-row xl:items-start xl:justify-between">
                  <div class="min-w-0 flex-1">
                    <div class="flex flex-wrap items-center gap-3">
                      <h3 class="text-xl font-semibold text-white">{{ task.title }}</h3>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-400">
                        {{ task.priority === 'high' ? '高优先级' : task.priority === 'low' ? '低优先级' : '中优先级' }}
                      </span>
                      <span class="rounded-full border border-white/8 px-3 py-1 text-xs text-slate-500">
                        {{ task.status === 'done' ? '已完成' : task.status === 'doing' ? '进行中' : '待开始' }}
                      </span>
                    </div>
                    <p class="mt-3 whitespace-pre-wrap text-sm leading-7 text-slate-300">
                      {{ task.description || '暂无任务说明。' }}
                    </p>
                    <div class="mt-4 flex flex-wrap gap-3 text-xs text-slate-500">
                      <span class="rounded-full border border-white/8 px-3 py-1">
                        发布人：{{ resolveMemberName(task.created_by) }}
                      </span>
                      <span v-if="task.assignee_id" class="rounded-full border border-white/8 px-3 py-1">
                        指派给：{{ resolveMemberName(task.assignee_id) }}
                      </span>
                      <span v-if="task.due_date" class="rounded-full border border-white/8 px-3 py-1">
                        截止：{{ new Date(task.due_date).toLocaleString('zh-CN') }}
                      </span>
                    </div>
                  </div>
                </div>
              </article>
            </div>

            <div
              v-else
              class="club-panel-muted flex min-h-56 flex-col items-center justify-center rounded-[24px] p-8 text-center"
            >
              <ClipboardCheck class="h-8 w-8 text-slate-500" />
              <p class="mt-4 font-display text-2xl font-bold text-white">当前社团还没有发布任务</p>
              <p class="mt-2 max-w-md text-sm leading-6 text-slate-400">
                被设为负责人后，就可以在这里给社员分配任务并追踪执行安排。
              </p>
            </div>
          </section>
        </main>
      </div>
    </div>
  </div>
</template>
