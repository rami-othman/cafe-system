'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ArrowLeft } from 'lucide-react';
import { api, csrf } from '@/lib/api/client';

export default function Login() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setLoading(true);
    const form = new FormData(event.currentTarget);

    try {
      await csrf();
      await api('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email: form.get('email'), password: form.get('password') }),
      });
      router.replace('/dashboard');
    } catch {
      setError('تعذّر تسجيل الدخول. تحقّق من البريد الإلكتروني وكلمة المرور.');
    } finally {
      setLoading(false);
    }
  }

  return <main className="login-page"><section className="login">
    <div className="login-brand">
      <div className="brand-mark">6:18</div>
      <div><strong>Cafe 6:18</strong><span>Platform Operations</span></div>
    </div>
    <h1>مرحبًا بعودتك</h1>
    <p className="muted">سجّل الدخول لإدارة وتشغيل المنصة من مكان واحد.</p>
    <form onSubmit={submit}>
      <label>البريد الإلكتروني<input className="input" name="email" type="email" placeholder="name@company.com" required /></label>
      <label>كلمة المرور<input className="input" name="password" type="password" placeholder="••••••••" required /></label>
      <button className="button" disabled={loading}>{loading ? 'جارٍ تسجيل الدخول…' : <>تسجيل الدخول <ArrowLeft size={16}/></>}</button>
      {error && <p className="error">{error}</p>}
    </form>
  </section></main>;
}
