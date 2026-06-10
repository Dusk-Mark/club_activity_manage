export type ApplicationDraft = {
  key: string
  name: string
  description: string
  scope: 'club' | 'activity' | 'system'
}

export const roleLabelMap: Record<string, string> = {
  student: '学生用户',
  leader: '社团负责人',
  club_admin: '社团管理员',
  league_committee: '校团委',
  admin: '系统管理员'
}

export const clubMemberRoleLabelMap: Record<string, string> = {
  member: '普通成员',
  leader: '社团负责人',
  admin: '社团管理员'
}

export const defaultApplicationTypes: ApplicationDraft[] = [
  {
    key: 'join_club',
    name: '加入社团申请',
    description: '提交加入目标社团的个人申请，由社团管理员审批。',
    scope: 'club'
  },
  {
    key: 'activity_fund',
    name: '活动经费申请',
    description: '围绕具体活动提交经费预算，由校团委或管理员审批。',
    scope: 'activity'
  },
  {
    key: 'resource_support',
    name: '资源支持申请',
    description: '申请场地、设备或宣传资源支持，用于活动执行。',
    scope: 'system'
  }
]

export const applicationStatusTheme: Record<string, string> = {
  pending: 'border-amber-400/18 bg-amber-400/10 text-amber-100',
  approved: 'border-emerald-400/18 bg-emerald-400/10 text-emerald-100',
  rejected: 'border-rose-400/18 bg-rose-400/10 text-rose-100'
}

export const applicationStatusLabel: Record<string, string> = {
  pending: '待审批',
  approved: '已通过',
  rejected: '已驳回'
}
