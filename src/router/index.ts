import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import LoginView from '../views/LoginView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'login',
      component: LoginView,
      meta: { requiresAuth: false }
    },
    {
      path: '/dashboard',
      name: 'dashboard',
      component: () => import('../views/DashboardView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('../views/ProfileView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/create-club',
      name: 'create-club',
      component: () => import('../views/CreateClubView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/activity/:id',
      name: 'activity-detail',
      component: () => import('../views/ActivityDetailView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/activity/publish',
      name: 'activity-publish',
      component: () => import('../views/ActivityPublishView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/club-admin',
      name: 'club-admin',
      component: () => import('../views/ClubAdminView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/club/members',
      name: 'member-management',
      component: () => import('../views/MemberManagementView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/news',
      name: 'news',
      component: () => import('../views/NewsView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/applications',
      name: 'applications',
      component: () => import('../views/ApplicationCenterView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/community',
      name: 'community',
      component: () => import('../views/CommunityView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/club/tasks',
      name: 'club-tasks',
      component: () => import('../views/ClubTasksView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/clubs',
      name: 'clubs-list',
      component: () => import('../views/ClubsListView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/club/:id',
      name: 'club-detail',
      component: () => import('../views/ClubDetailView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/league-admin',
      name: 'league-admin',
      component: () => import('../views/LeagueAdminView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/rules',
      name: 'rules',
      component: () => import('../views/RulesView.vue'),
      meta: { requiresAuth: true }
    }
  ]
})

// 导航守卫
router.beforeEach(async (to, _from, next) => {
  const authStore = useAuthStore()
  const user = await authStore.ensureUser()
  const isAuthenticated = !!user

  if (to.meta.requiresAuth && !isAuthenticated) {
    next('/')
  } else if (to.name === 'login' && isAuthenticated) {
    next('/dashboard')
  } else {
    next()
  }
})

export default router
