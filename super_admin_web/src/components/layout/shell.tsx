'use client';

import Link from 'next/link';
import {usePathname, useRouter} from 'next/navigation';
import {useQuery} from '@tanstack/react-query';
import {api, csrf} from '@/lib/api/client';

const links=[
  ['لوحة التحكم','/dashboard'],['المستأجرون','/tenants'],['الفروع','/branches'],['المستخدمون','/users'],
  ['الخطط','/plans'],['الاشتراكات','/subscriptions'],['التحليلات','/analytics'],['سجل التدقيق','/audit-logs'],
  ['مدراء المنصة','/platform-admins'],['الإعلانات','/announcements'],['صحة النظام','/system/health'],['الإعدادات','/settings'],
];
type Me={data:{id:number,name:string,email:string,roles:string[],permissions:string[]}};

export function Shell({children}:{children:React.ReactNode}){
  const pathname=usePathname();const router=useRouter();
  const me=useQuery({queryKey:['me'],queryFn:()=>api<Me>('/auth/me'),retry:false,staleTime:60_000});
  async function logout(){try{await csrf();await api('/auth/logout',{method:'POST'});}finally{router.replace('/login');}}
  if(me.isLoading)return <main className="app-loading" aria-live="polite">جارٍ تحميل جلسة الإدارة…</main>;
  if(me.isError){if(typeof window!=='undefined')router.replace('/login');return <main className="app-loading">جارٍ توجيهك لتسجيل الدخول…</main>}
  return <div className="shell"><aside className="side"><Link className="brand" href="/dashboard">Cafe 6:18<span>Platform Operations</span></Link><nav className="nav" aria-label="التنقل الرئيسي">{links.map(([label,href])=>{const active=pathname===href||href!=='/dashboard'&&pathname.startsWith(`${href}/`);return <Link className={active?'active':''} href={href} key={href}>{label}</Link>})}</nav><div className="side-bottom"><Link href="/profile">{me.data?.data.name}</Link><button className="link-button" onClick={logout}>تسجيل الخروج</button></div></aside><main className="main"><header className="top"><div><strong>إدارة المنصة</strong><div className="muted">تشغيل ومتابعة Cafe 6:18</div></div><Link className="profile-link" href="/profile">{me.data?.data.email}</Link></header>{children}</main></div>
}
