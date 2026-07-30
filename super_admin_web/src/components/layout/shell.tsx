'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { Activity, Bell, Building2, ChartNoAxesCombined, ClipboardList, Crown, LayoutDashboard, LogOut, Settings, ShieldCheck, Sparkles, Users, WalletCards } from 'lucide-react';
import { api, csrf } from '@/lib/api/client';

const links = [
  ['لوحة التحكم', '/dashboard', LayoutDashboard], ['المستأجرون', '/tenants', Building2], ['الفروع', '/branches', Activity], ['المستخدمون', '/users', Users],
  ['الخطط', '/plans', Crown], ['الاشتراكات', '/subscriptions', WalletCards], ['التحليلات', '/analytics', ChartNoAxesCombined], ['سجل التدقيق', '/audit-logs', ClipboardList],
  ['مدراء المنصة', '/platform-admins', ShieldCheck], ['الإعلانات', '/announcements', Bell], ['صحة النظام', '/system/health', Activity], ['الإعدادات', '/settings', Settings],
] as const;

type Me = { data: { id: number; name: string; email: string; roles: string[]; permissions: string[] } };

export function Shell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const me = useQuery({ queryKey: ['me'], queryFn: () => api<Me>('/auth/me'), retry: false, staleTime: 60_000 });

  async function logout() {
    try { await csrf(); await api('/auth/logout', { method: 'POST' }); }
    finally { router.replace('/login'); }
  }

  if (me.isLoading) return <main className="app-loading" aria-live="polite">جارٍ تحميل جلسة الإدارة…</main>;
  if (me.isError) {
    if (typeof window !== 'undefined') router.replace('/login');
    return <main className="app-loading">جارٍ توجيهك إلى تسجيل الدخول…</main>;
  }

  const initials = me.data?.data.name?.trim().slice(0, 2).toUpperCase() || 'SA';
  return <div className="shell">
    <aside className="side">
      <Link className="brand" href="/dashboard"><span className="brand-mark">6:18</span><div>Cafe 6:18<span>Platform Operations</span></div></Link>
      <nav className="nav" aria-label="التنقل الرئيسي">
        {links.map(([label, href, Icon]) => {
          const active = pathname === href || (href !== '/dashboard' && pathname.startsWith(`${href}/`));
          return <Link className={active ? 'active' : ''} href={href} key={href}><Icon />{label}</Link>;
        })}
      </nav>
      <div className="side-bottom">
        <Link className="user-chip" href="/profile"><span className="user-avatar">{initials}</span><span>{me.data?.data.name}</span></Link>
        <button className="link-button" onClick={logout}><LogOut size={14}/> تسجيل الخروج</button>
      </div>
    </aside>
    <main className="main">
      <header className="top"><div><div className="top-title"><span className="top-orb"/><strong>إدارة المنصة</strong></div><div className="muted">تشغيل ومتابعة Cafe 6:18</div></div><Link className="profile-link" href="/profile"><Sparkles size={13}/> {me.data?.data.email}</Link></header>
      {children}
    </main>
  </div>;
}
