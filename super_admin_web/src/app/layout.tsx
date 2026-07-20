import './globals.css';
import { Providers } from '@/components/providers';
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="ar" dir="rtl"><body><Providers>{children}</Providers></body></html>}
