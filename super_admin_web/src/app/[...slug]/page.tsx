import { ModulePage } from '@/components/pages/module-page';

export default async function CatchAllPage({params}:{params:Promise<{slug:string[]}>}){
  const {slug}=await params;
  return <ModulePage slug={slug}/>;
}
