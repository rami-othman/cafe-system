export const apiUrl=process.env.NEXT_PUBLIC_API_URL??'http://localhost:8000/api/super-admin/v1';
export type ApiError=Error&{status?:number;errors?:Record<string,string[]>};
let csrfToken:string|undefined;
export async function api<T>(path:string,init:RequestInit={}) : Promise<T>{const response=await fetch(`${apiUrl}${path}`,{credentials:'include',headers:{Accept:'application/json','Content-Type':'application/json',...(csrfToken?{'X-CSRF-TOKEN':csrfToken}:{}),...init.headers},...init});const body=await response.json().catch(()=>null);if(!response.ok){const error=Object.assign(new Error(body?.message??'Request failed'),{status:response.status,errors:body?.errors}) as ApiError;throw error}return body as T}
export async function csrf(){const result=await api<{data:{csrfToken:string}}>('/auth/csrf');csrfToken=result.data.csrfToken;}
export function queryString(values:Record<string,string|number|undefined|null>){const params=new URLSearchParams();Object.entries(values).forEach(([key,value])=>{if(value!==undefined&&value!==null&&value!=='')params.set(key,String(value))});const result=params.toString();return result?`?${result}`:''}
