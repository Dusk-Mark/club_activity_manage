# 校园社团活动管理平台

一个面向高校社团场景的前后端一体化管理系统，围绕社团创建、活动发布、报名审核、成员管理、公告通知与互动交流等日常事务展开，适合课程设计、校园信息化实践与功能演示场景。

项目基于 Vue 3 + TypeScript + Vite 开发，数据层接入 Supabase，前端可直接部署到 Vercel。

## 项目亮点

- 覆盖学生、社团管理员、校团委、系统管理员等多角色使用场景
- 包含登录注册、个人中心、新闻公告、规章制度、社团列表、活动详情、活动发布、互动交流等核心页面
- 提供校团委综合后台，可管理用户角色、社团状态、活动信息、申请审批与网站配置
- 使用 Supabase 完成认证、数据表设计与权限控制，便于快速落地课程项目
- 使用 Vue Router History 模式，已补充 Vercel 单页应用路由重写配置

## 功能概览

### 前台功能

- 用户登录、注册与身份切换
- 首页仪表盘与活动日历预览
- 新闻公告与规章制度查看
- 社团浏览、社团详情与加入申请
- 活动发布、活动详情、活动报名与签到反馈
- 互动社区、个人中心、我的申请与个人信息维护

### 后台功能

- 校团委综合后台
- 用户角色管理
- 社团状态管理
- 活动总览与活动删除
- 申请类型维护
- 用户申请审批
- 网站配置项维护
- 社团负责人指派与治理支持

## 技术栈

- 前端框架：Vue 3
- 开发语言：TypeScript
- 构建工具：Vite
- 路由管理：Vue Router
- 状态管理：Pinia
- 后端服务：Supabase
- 部署平台：Vercel

## 项目结构

```text
club-activity-manager/
├─ public/                 静态资源
├─ src/
│  ├─ components/          通用组件
│  ├─ lib/                 Supabase 与业务常量
│  ├─ router/              路由配置与鉴权守卫
│  ├─ stores/              Pinia 状态管理
│  └─ views/               页面视图
├─ database.sql            Supabase 数据库初始化脚本
├─ vercel.json             Vercel 路由重写配置
└─ .env.example            环境变量示例
```

## 本地运行

### 1. 安装依赖

```bash
npm install
```

### 2. 配置环境变量

复制示例文件并填写你自己的 Supabase 项目配置：

```bash
cp .env.example .env.local
```

Windows PowerShell 可使用：

```powershell
Copy-Item .env.example .env.local
```

需要填写的变量如下：

```env
VITE_SUPABASE_URL=你的 Supabase 项目地址
VITE_SUPABASE_ANON_KEY=你的 Supabase 匿名公钥
```

### 3. 初始化数据库

将 [database.sql](./database.sql) 中的 SQL 脚本复制到 Supabase SQL Editor 执行，用于创建项目所需的数据表、枚举类型、函数与权限策略。

### 4. 启动开发环境

```bash
npm run dev
```

### 5. 生产构建

```bash
npm run build
```

## 部署到 Vercel

### 环境变量

在 Vercel 项目设置中添加以下变量：

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

### 构建配置

- Build Command：`npm run build`
- Output Directory：`dist`

项目已经提供 `vercel.json`，用于处理 Vue Router History 模式下的刷新与直达路由问题，部署后访问 `/dashboard`、`/clubs`、`/activity/:id` 等页面不会因为刷新而返回 404。

## 上传 GitHub 前的处理

为避免泄露本地配置与 IDE/Agent 工作文件，仓库已补充忽略规则：

- `.env`
- `.env.*`（保留 `.env.example`）
- `.trae/`
- `.agents/`
- `.shared/`
- `node_modules/`
- `dist/`

如果这些文件此前已经被 Git 跟踪，需要在首次提交前移出版本控制缓存。

## 适用场景

- 小学期课程设计
- 校园管理系统原型展示
- 基于 Supabase 的全栈练习项目
- 前后端协同开发的毕业设计或功能拓展基础工程

## 后续可扩展方向

- 接入真实图片上传与对象存储
- 增加消息通知与站内信
- 完善活动签到二维码流程
- 增加数据统计看板与导出能力
- 细化角色权限与 RLS 策略

## 说明

当前仓库保留了数据库初始化脚本与前端源码，适合直接二次开发。如果你准备继续完善毕业设计或课程项目，建议优先补充：

- 数据字典与接口说明
- 测试账号说明
- 页面截图或演示视频
- 更细致的部署文档
