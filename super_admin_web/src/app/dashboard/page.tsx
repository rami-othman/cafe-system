'use client';

import Link from 'next/link';
import { useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { ArrowUpLeft, BellRing, Building2, CalendarDays, ChartSpline, CircleAlert, CreditCard, Users } from 'lucide-react';
import { api, queryString } from '@/lib/api/client';
import { Shell } from '@/components/layout/shell';

type Dashboard = { data: { generatedAt: string; metrics: Record<string, number>; salesByCurrency: { currency: string; gross_sales: number; orders: number }[]; salesTrend: { date: string; currency: string; gross_sales: number; orders: number }[]; subscriptionMix: { status: string; total: number }[]; alerts: { severity: string; title: string; detail: string; href: string }[]; recentActivity: { id: number; action: string; actor_name?: string; created_at: string }[] } };

const labels: Record<string, { label: string; href: string; icon: typeof Users }> = {
  activeTenants: { label: 'المستأجرون النشطون', href: '/tenants', icon: Users }, newTenants: { label: 'مستأجرون جدد', href: '/tenants', icon: Building2 },
  trialsEndingSoon: { label: 'تجارب تنتهي قريبًا', href: '/subscriptions', icon: CalendarDays }, suspendedTenants: { label: 'حسابات موقوفة', href: '/tenants', icon: CircleAlert },
  activeSubscriptions: { label: 'اشتراكات نشطة', href: '/subscriptions', icon: CreditCard }, totalBranches: { label: 'إجمالي الفروع', href: '/branches', icon: Building2 },
};

const money = (value: number, currency: string) => new Intl.NumberFormat('en', { style: 'currency', currency, maximumFractionDigits: 0 }).format(value);

export default function DashboardPage() {
  const [days, setDays] = useState('30');
  const until = new Date(); const from = new Date(until); from.setDate(until.getDate() - Number(days) + 1);
  const query = useQuery({ queryKey: ['dashboard', days], queryFn: () => api<Dashboard>(`/dashboard${queryString({ from: from.toISOString().slice(0, 10), to: until.toISOString().slice(0, 10) })}`) });
  const data = query.data?.data;
  const maxSales = useMemo(() => Math.max(1, ...(data?.salesTrend.map(item => Number(item.gross_sales)) ?? [1])), [data]);

  return <Shell><div className="page-header">
    <div><h1>نظرة شاملة، بقرار أسرع</h1><p>مؤشرات المنصة الأساسية خلال الفترة المحددة.</p></div>
    <div className="actions"><select aria-label="الفترة" value={days} onChange={event => setDays(event.target.value)}><option value="7">آخر 7 أيام</option><option value="30">آخر 30 يومًا</option><option value="90">آخر 90 يومًا</option></select><span className="muted">آخر تحديث: {data ? new Date(data.generatedAt).toLocaleString('ar') : '—'}</span></div>
  </div>
  {query.isLoading ? <div className="panel empty">جارٍ تحميل لوحة التحكم…</div> : query.isError ? <div className="panel error">تعذّر تحميل لوحة التحكم. حاول التحديث مجددًا.</div> : <>
    <section className="grid">{Object.entries(data?.metrics ?? {}).filter(([key]) => labels[key]).map(([key, value]) => { const item = labels[key]; const Icon = item.icon; return <Link className="metric" href={item.href} key={key}><Icon size={18}/><p>{item.label}</p><strong>{value}</strong><small>ضمن الفترة المحددة <ArrowUpLeft size={12}/></small></Link>; })}</section>
    <section className="two-col"><div className="panel"><h2><BellRing size={17}/> التنبيهات والإجراءات</h2><div className="alert-list">{data?.alerts.length ? data.alerts.map((alert, index) => <Link className={`alert ${alert.severity}`} href={alert.href} key={index}><CircleAlert size={18}/><div><strong>{alert.title}</strong><p>{alert.detail}</p></div></Link>) : <div className="empty">لا توجد تنبيهات تحتاج إلى إجراء حاليًا.</div>}</div></div><div className="panel"><h2><CreditCard size={17}/> المبيعات حسب العملة</h2><div className="chart-list">{data?.salesByCurrency.length ? data.salesByCurrency.map(item => <div className="status-row" key={item.currency}><span>{item.currency}</span><strong>{money(Number(item.gross_sales), item.currency)}</strong><small>{item.orders} طلب</small></div>) : <div className="empty">لا توجد مبيعات للفترة.</div>}</div></div></section>
    <section className="two-col"><div className="panel"><h2><ChartSpline size={17}/> اتجاه المبيعات</h2><div className="chart-list">{data?.salesTrend.slice(-12).map(item => <div className="bar-row" key={`${item.date}${item.currency}`}><span>{item.date}</span><div className="bar" aria-label={`${item.date}: ${item.gross_sales}`}><span style={{ width: `${Number(item.gross_sales) / maxSales * 100}%` }}/></div><strong>{money(Number(item.gross_sales), item.currency)}</strong></div>) || <div className="empty">لا توجد بيانات كافية.</div>}</div></div><div className="panel"><h2>مزيج الاشتراكات</h2><div className="status-grid">{data?.subscriptionMix.length ? data.subscriptionMix.map(item => <Link className="status-row" href={`/subscriptions?status=${item.status}`} key={item.status}><span>{item.status}</span><strong>{item.total}</strong></Link>) : <div className="empty">لا توجد بيانات اشتراكات.</div>}</div></div></section>
    <section className="two-col"><div className="panel"><h2>آخر نشاطات المنصة</h2><div className="timeline">{data?.recentActivity.length ? data.recentActivity.map(item => <div className="timeline-item" key={item.id}><strong>{item.action}</strong><p>{item.actor_name ?? 'النظام'} · {new Date(item.created_at).toLocaleString('ar')}</p></div>) : <div className="empty">لا توجد نشاطات مسجلة.</div>}</div></div><div className="panel"><h2>لمحة تشغيلية</h2><div className="empty">تتحدّث هذه اللوحة تلقائيًا مع أحدث البيانات التشغيلية.</div></div></section>
  </>}</Shell>;
}
