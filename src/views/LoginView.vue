<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'
import {
  ArrowRight,
  CalendarDays,
  Compass,
  GraduationCap,
  Loader2,
  Lock,
  Mail,
  ShieldCheck,
  Sparkles,
  UserRound,
  Users
} from 'lucide-vue-next'

const router = useRouter()
const authStore = useAuthStore()

const isLogin = ref(true)
const email = ref('')
const password = ref('')
const fullName = ref('')
const selectedRole = ref('student')
const loading = ref(false)
const errorMessage = ref('')
const infoMessage = ref('')

const roleOptions = [
  {
    value: 'student',
    label: '学生身份',
    description: '报名校园活动、加入学生社团、查看个人参与记录',
    icon: GraduationCap
  },
  {
    value: 'league_committee',
    label: '校团委',
    description: '统筹社团事务、审核申请流程、管理全校活动信息',
    icon: ShieldCheck
  }
]

const overviewStats = [
  { label: '在册社团', value: '68+', icon: Users },
  { label: '本学期活动', value: '240+', icon: CalendarDays },
  { label: '学生参与', value: '12k+', icon: Sparkles }
]

const showcaseCards = [
  {
    title: '青年志愿者协会',
    summary: '公益报名、值班安排与服务时长登记正在同步更新',
    image: 'https://picsum.photos/seed/school-volunteer-club/900/1200',
    className: 'md:col-span-2 md:row-span-2'
  },
  {
    title: '校园艺术团',
    summary: '节目排练、演出通知与社团活动发布统一管理',
    image: 'https://picsum.photos/seed/school-art-club/800/900',
    className: 'md:col-span-1 md:row-span-1'
  },
  {
    title: '科技创新社',
    summary: '项目招募、竞赛通知与成果资料集中归档',
    image: 'https://picsum.photos/seed/school-tech-club/800/900',
    className: 'md:col-span-1 md:row-span-1'
  }
]

const toggleMode = (nextMode?: boolean) => {
  isLogin.value = nextMode ?? !isLogin.value
  errorMessage.value = ''
  infoMessage.value = ''
}

const handleSubmit = async () => {
  if (!email.value || !password.value) {
    errorMessage.value = '请填写邮箱和密码'
    return
  }

  if (password.value.length < 6) {
    errorMessage.value = '密码长度至少为 6 位'
    return
  }

  loading.value = true
  errorMessage.value = ''
  infoMessage.value = ''

  try {
    if (isLogin.value) {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: email.value,
        password: password.value
      })

      if (error) {
        if (error.message === 'Invalid login credentials') {
          throw new Error('邮箱或密码错误')
        }
        if (error.message === 'Email not confirmed') {
          throw new Error('请先前往邮箱完成账号激活')
        }
        throw error
      }

      if (data.user) {
        await authStore.fetchUser()
        router.push('/dashboard')
      }
      return
    }

    if (!fullName.value.trim()) {
      errorMessage.value = '请输入真实姓名'
      return
    }

    const { data, error } = await supabase.auth.signUp({
      email: email.value,
      password: password.value,
      options: {
        data: {
          full_name: fullName.value.trim(),
          username: email.value.split('@')[0],
          role: selectedRole.value
        }
      }
    })

    if (error) throw error

    if (data.user && data.session) {
      await authStore.fetchUser()
      router.push('/dashboard')
    } else {
      infoMessage.value = '注册成功，请查收邮件并完成确认后再登录系统。'
      toggleMode(true)
    }
  } catch (error: any) {
    errorMessage.value = error.message || '发生未知错误，请稍后再试'
    console.error('Auth error:', error)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="club-shell px-4 py-4 md:px-6 lg:px-10">
    <header class="club-panel mx-auto flex max-w-7xl items-center justify-between gap-4 px-5 py-4 md:px-6">
      <div class="flex items-center gap-3">
        <div class="flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-[#c0a26a] to-[#e7d29c] text-[#161616] shadow-[0_16px_28px_-18px_rgba(231,210,156,0.85)]">
          <Compass class="h-5 w-5" />
        </div>
        <div>
          <p class="font-display text-lg font-bold text-white">中北大学社团活动</p>
          <p class="text-sm text-slate-400">服务学校社团招新、活动组织与日常管理</p>
        </div>
      </div>

      <div class="hidden items-center gap-2 lg:flex">
        <span class="club-pill px-4 py-2 text-sm">活动统筹</span>
        <span class="club-status-chip px-4 py-2 text-sm">社团治理</span>
        <span class="club-status-chip px-4 py-2 text-sm">成长档案</span>
      </div>

      <button
        type="button"
        class="rounded-full px-5 py-3 text-sm font-semibold club-button-secondary"
        @click="toggleMode()"
      >
        {{ isLogin ? '切换到注册' : '返回登录' }}
      </button>
    </header>

    <main class="mx-auto mt-6 grid max-w-7xl gap-6 lg:grid-cols-[1.1fr_0.9fr]">
      <section class="flex flex-col justify-between gap-6">
        <div class="club-panel overflow-hidden px-6 py-7 md:px-8 lg:px-10">
          <div class="mb-6 club-section-label text-sm font-medium">
            <Sparkles class="h-4 w-4" />
            学校社团统一登录入口，面向学生、社团干部与校团委老师。
          </div>

          <div class="grid gap-8 lg:grid-cols-[1.05fr_0.95fr]">
            <div class="space-y-6">
              <div class="space-y-4">
                <h1 class="max-w-xl font-display text-4xl font-bold leading-tight text-white md:text-5xl xl:text-6xl">中北大学社团活动</h1>
                <p class="max-w-xl text-base leading-7 text-slate-300 md:text-lg">
                  围绕招新、发布、报名、审核、签到与归档，建立更清晰的校园社团协作路径。
                </p>
              </div>

              <div class="grid gap-3 sm:grid-cols-3">
                <div
                  v-for="item in overviewStats"
                  :key="item.label"
                  class="club-panel-muted px-4 py-4"
                >
                  <component :is="item.icon" class="mb-3 h-5 w-5 text-[#e7d29c]" />
                  <p class="font-display text-2xl font-bold text-white">{{ item.value }}</p>
                  <p class="mt-1 text-sm text-slate-400">{{ item.label }}</p>
                </div>
              </div>

              <div class="grid gap-4 md:grid-cols-[1.15fr_0.85fr]">
                <div class="club-panel-muted p-5">
                  <p class="mb-2 text-sm font-medium text-[#f2ddae]">为什么适合学校使用</p>
                  <p class="text-lg font-semibold text-white">
                    社团招新、活动申请、报名签到与反馈归档都不再分散。
                  </p>
                </div>
                <div class="club-panel-muted p-5">
                  <p class="mb-2 text-sm font-medium text-slate-400">平台特性</p>
                  <p class="text-lg font-semibold text-white">统一入口、分角色权限与社团业务协同</p>
                </div>
              </div>
            </div>

            <div class="grid auto-rows-[170px] gap-4 md:grid-cols-2">
              <article
                v-for="card in showcaseCards"
                :key="card.title"
                :class="['group club-panel-muted overflow-hidden card-hover', card.className]"
              >
                <div class="relative h-full">
                  <img
                    :src="card.image"
                    :alt="card.title"
                    class="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
                  />
                  <div class="absolute inset-0 bg-gradient-to-t from-[#05070d] via-[#05070d]/28 to-transparent" />
                  <div class="absolute inset-x-0 bottom-0 p-5">
                    <p class="font-display text-xl font-bold text-white">{{ card.title }}</p>
                    <p class="mt-2 max-w-xs text-sm leading-6 text-slate-200">{{ card.summary }}</p>
                  </div>
                </div>
              </article>
            </div>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-[1.15fr_0.85fr]">
          <div class="club-panel-muted p-5">
            <div class="mb-3 flex items-center gap-2 text-[#f2ddae]">
              <ShieldCheck class="h-4 w-4" />
              <span class="text-sm font-medium">统一认证与权限写入</span>
            </div>
            <p class="text-sm leading-7 text-slate-300">
              注册后自动写入学校社团平台身份信息，便于后续区分学生、社团管理员与校团委角色。
            </p>
          </div>
          <div class="club-panel-muted p-5">
            <div class="mb-3 flex items-center gap-2 text-[#9fc0f7]">
              <CalendarDays class="h-4 w-4" />
              <span class="text-sm font-medium">更柔和的微动效</span>
            </div>
            <p class="text-sm leading-7 text-slate-300">
              页面切换、按钮反馈与身份选择都保持柔和过渡，更贴合年轻校园社团的使用氛围。
            </p>
          </div>
        </div>
      </section>

      <section class="club-panel h-fit p-5 md:p-6 lg:p-7">
        <div class="mb-6 flex items-center justify-between gap-3">
          <div>
            <p class="text-sm text-slate-400">{{ isLogin ? '欢迎回到校园社团平台' : '创建你的社团平台账号' }}</p>
            <h2 class="mt-1 font-display text-3xl font-bold text-white">
              {{ isLogin ? '登录系统' : '完成注册' }}
            </h2>
          </div>
          <div class="rounded-2xl border border-white/8 bg-white/4 px-3 py-2 text-right">
            <p class="text-xs text-slate-400">适用场景</p>
            <p class="font-semibold text-white">学校社团统一入口</p>
          </div>
        </div>

        <div class="mb-6 grid grid-cols-2 rounded-2xl bg-[#0d1220] p-1">
          <button
            type="button"
            class="rounded-2xl px-4 py-3 text-sm font-semibold"
            :class="isLogin ? 'club-button-primary' : 'text-slate-300'"
            @click="toggleMode(true)"
          >
            登录
          </button>
          <button
            type="button"
            class="rounded-2xl px-4 py-3 text-sm font-semibold"
            :class="!isLogin ? 'club-button-primary' : 'text-slate-300'"
            @click="toggleMode(false)"
          >
            注册
          </button>
        </div>

        <form class="space-y-4" @submit.prevent="handleSubmit">
          <div v-if="!isLogin" class="space-y-3">
            <label class="text-sm font-medium text-slate-300">选择校园身份</label>
            <div class="grid gap-3">
              <label
                v-for="role in roleOptions"
                :key="role.value"
                class="cursor-pointer"
              >
                <input v-model="selectedRole" type="radio" :value="role.value" class="sr-only" />
                <div
                  class="rounded-2xl border px-4 py-4 transition-all"
                  :class="selectedRole === role.value
                    ? 'border-[#e7d29c]/40 bg-[#e7d29c]/10 shadow-[0_18px_30px_-18px_rgba(231,210,156,0.55)]'
                    : 'border-white/8 bg-white/[0.03] hover:border-white/14 hover:bg-white/[0.05]'"
                >
                  <div class="flex items-start gap-3">
                    <div
                      class="flex h-11 w-11 items-center justify-center rounded-2xl"
                      :class="selectedRole === role.value ? 'bg-[#e7d29c]/18 text-[#f2ddae]' : 'bg-white/6 text-slate-300'"
                    >
                      <component :is="role.icon" class="h-5 w-5" />
                    </div>
                    <div>
                      <p class="font-semibold text-white">{{ role.label }}</p>
                      <p class="mt-1 text-sm leading-6 text-slate-400">{{ role.description }}</p>
                    </div>
                  </div>
                </div>
              </label>
            </div>
          </div>

          <div v-if="!isLogin" class="space-y-2">
            <label class="text-sm font-medium text-slate-300">真实姓名</label>
            <div class="relative">
              <UserRound class="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
              <input
                v-model="fullName"
                type="text"
                placeholder="例如：张若溪"
                class="club-input w-full py-4 pl-11 pr-4"
              />
            </div>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-slate-300">学校邮箱或常用邮箱</label>
            <div class="relative">
              <Mail class="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
              <input
                v-model="email"
                type="email"
                placeholder="name@example.com"
                class="club-input w-full py-4 pl-11 pr-4"
              />
            </div>
          </div>

          <div class="space-y-2">
            <label class="text-sm font-medium text-slate-300">平台登录密码</label>
            <div class="relative">
              <Lock class="pointer-events-none absolute left-4 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
              <input
                v-model="password"
                type="password"
                placeholder="至少 6 位密码"
                class="club-input w-full py-4 pl-11 pr-4"
              />
            </div>
          </div>

          <div
            v-if="errorMessage"
            class="rounded-2xl border border-rose-400/20 bg-rose-400/10 px-4 py-3 text-sm leading-6 text-rose-100"
          >
            {{ errorMessage }}
          </div>

          <div
            v-if="infoMessage"
            class="rounded-2xl border border-emerald-400/20 bg-emerald-400/10 px-4 py-3 text-sm leading-6 text-emerald-100"
          >
            {{ infoMessage }}
          </div>

          <button
            type="submit"
            :disabled="loading"
            class="flex w-full items-center justify-center gap-2 rounded-2xl px-5 py-4 text-base font-semibold disabled:cursor-not-allowed disabled:opacity-60 club-button-primary"
          >
            <Loader2 v-if="loading" class="h-5 w-5 animate-spin" />
            <template v-else>
              <span>{{ isLogin ? '进入仪表盘' : '创建账号' }}</span>
              <ArrowRight class="h-5 w-5" />
            </template>
          </button>
        </form>

          <div class="mt-6 grid gap-4 md:grid-cols-2">
            <div class="rounded-3xl border border-white/8 bg-white/[0.03] p-4">
              <p class="text-sm font-medium text-[#f2ddae]">注册后可直接使用</p>
              <p class="mt-2 text-sm leading-6 text-slate-300">
                我的社团、活动报名、个人中心与参与记录会统一归档到同一账户。
              </p>
            </div>
            <div class="rounded-3xl border border-white/8 bg-white/[0.03] p-4">
              <p class="text-sm font-medium text-[#9fc0f7]">更贴近校园场景</p>
              <p class="mt-2 text-sm leading-6 text-slate-300">
                表单、角色切换和入口组织都围绕学校社团的实际管理路径设计。
              </p>
            </div>
          </div>
      </section>
    </main>
  </div>
</template>
