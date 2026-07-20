const fs = require('fs');
const path = require('path');

const output = path.join(__dirname, '..', '..', 'output', 'pdf', 'super_admin_dashboard_plan.pdf');
fs.mkdirSync(path.dirname(output), { recursive: true });

const W = 595.28, H = 841.89;
const M = 48;
const C = {
  ink: [0.137, 0.063, 0.020], muted: [0.42, 0.35, 0.31],
  primary: [0.231, 0.141, 0.090], accent: [0.769, 0.478, 0.227],
  sand: [0.98, 0.969, 0.949], line: [0.91, 0.89, 0.85],
  white: [1, 1, 1], good: [0.15, 0.42, 0.28], warn: [0.66, 0.36, 0.08],
};
const esc = s => String(s).replace(/\\/g, '\\\\').replace(/\(/g, '\\(').replace(/\)/g, '\\)');
const rgb = c => `${c.map(v => v.toFixed(3)).join(' ')} rg`;
const lineRgb = c => `${c.map(v => v.toFixed(3)).join(' ')} RG`;
const approx = (text, size) => Math.max(1, Math.floor((text.length * size * 0.52)));
function wrap(text, width, size) {
  const result = [];
  let line = '';
  for (const word of String(text).split(/\s+/)) {
    const candidate = line ? `${line} ${word}` : word;
    if (approx(candidate, size) > width && line) { result.push(line); line = word; }
    else line = candidate;
  }
  if (line) result.push(line);
  return result;
}
function text(x, y, value, size=9, font='F1', color=C.ink) {
  return `BT ${rgb(color)} /${font} ${size} Tf 1 0 0 1 ${x.toFixed(2)} ${y.toFixed(2)} Tm (${esc(value)}) Tj ET\n`;
}
function rect(x, y, w, h, fill, stroke=null, lw=0.5) {
  let out = `${rgb(fill)} ${x.toFixed(2)} ${y.toFixed(2)} ${w.toFixed(2)} ${h.toFixed(2)} re f\n`;
  if (stroke) out += `${lineRgb(stroke)} ${lw} w ${x.toFixed(2)} ${y.toFixed(2)} ${w.toFixed(2)} ${h.toFixed(2)} re S\n`;
  return out;
}
function rule(x1, y1, x2, y2, color=C.line, lw=.5) { return `${lineRgb(color)} ${lw} w ${x1} ${y1} m ${x2} ${y2} l S\n`; }

class Page {
  constructor(number, title='') {
    this.number = number; this.title = title; this.y = 744; this.s = '';
    this.s += rect(0, 0, W, H, C.sand);
    this.s += rect(0, H-58, W, 58, C.primary);
    this.s += text(M, H-35, 'CAFE 6:18  /  PLATFORM OPERATIONS', 8, 'F2', C.white);
    this.s += text(W-M, H-35, title.toUpperCase(), 7.5, 'F1', [0.94,0.89,0.85]);
    this.s += rule(M, 29, W-M, 29, C.line);
    this.s += text(M, 16, 'Cafe 6:18 Platform - Super Admin Dashboard Plan', 7.2, 'F1', C.muted);
    this.s += text(W-M-28, 16, `Page ${number}`, 7.2, 'F1', C.muted);
  }
  heading(value) { this.s += text(M, this.y, value, 17, 'F2', C.primary); this.y -= 30; }
  subheading(value) { this.s += text(M, this.y, value, 11.5, 'F2', C.primary); this.y -= 20; }
  para(value, opts={}) {
    const size=opts.size || 9.2, leading=opts.leading || 13, x=opts.x || M, width=opts.width || W-2*M, color=opts.color || C.ink;
    for (const line of wrap(value,width,size)) { this.s += text(x,this.y,line,size,opts.font || 'F1',color); this.y -= leading; }
    this.y -= opts.after === undefined ? 6 : opts.after;
  }
  bullets(items) { for (const item of items) { this.para(`- ${item}`, {width: W-2*M-5, x:M+5, after:2}); } this.y -= 3; }
  callout(label, value, accent=C.accent) {
    const lines=wrap(value,W-2*M-24,8.6); const h=36 + lines.length*12;
    this.s += rect(M,this.y-h,W-2*M,h,C.white,C.line);
    this.s += rect(M,this.y-h,4,h,accent);
    this.s += text(M+13,this.y-14,label.toUpperCase(),7.6,'F2',accent);
    let yy=this.y-27; for (const line of lines) { this.s += text(M+13,yy,line,8.6,'F1',C.ink); yy -= 12; }
    this.y -= h+12;
  }
  table(headers, rows, widths) {
    const x=M, total=widths.reduce((a,b)=>a+b,0), fs=7.25, lead=9.5;
    const drawRow=(cells, y, isHeader) => {
      const lines=cells.map((c,i)=>wrap(c,widths[i]-10,isHeader?7.1:fs));
      const height=Math.max(...lines.map(a=>a.length))*(isHeader?9:lead)+10;
      this.s += rect(x,y-height,total,height,isHeader?C.primary:C.white,C.line);
      let xx=x;
      for(let i=0;i<cells.length;i++){
        if(i>0) this.s += rule(xx,y-height,xx,y,C.line,.35);
        let yy=y-(isHeader?12:11);
        for(const l of lines[i]){ this.s += text(xx+5,yy,l,isHeader?7.1:fs,isHeader?'F2':'F1',isHeader?C.white:C.ink); yy -= isHeader?9:lead; }
        xx += widths[i];
      }
      return height;
    };
    let y=this.y; y -= drawRow(headers,y,true);
    for (const row of rows) y -= drawRow(row,y,false);
    this.y = y-12;
  }
}

const pages=[];
function page(title) { const p=new Page(pages.length+1,title); pages.push(p); return p; }

let p=page('Dashboard Plan');
p.y=650;
p.s += text(M,p.y,'Super Admin',27,'F2',C.primary); p.y-=34;
p.s += text(M,p.y,'Dashboard Plan',27,'F2',C.primary); p.y-=29;
p.para('Product, operations, and delivery blueprint for the Cafe 6:18 multi-tenant platform.', {size:11,leading:16,color:C.muted,after:24});
p.callout('Purpose','Define the first production-ready dashboard for platform operators. It should answer: Is the platform healthy? Are tenants growing and compliant? What requires action now?');
p.subheading('Document scope');
p.para('This plan covers the Super Admin web dashboard, not the cafe POS or an individual tenant back-office dashboard. It is designed for staff who operate the Cafe 6:18 SaaS platform.');
p.table(['Audience','Primary outcome','Frequency'],[
  ['Platform operator','Detect urgent tenant, revenue, and platform issues.','Daily'],
  ['Platform manager','Track adoption, commercial health, and operational trends.','Weekly'],
  ['Support / finance','Find tenants needing follow-up or reconciliation.','On demand'],
],[100,270,129]);
p.subheading('Recommended delivery order');
p.para('First make the dashboard reliable and actionable; then add drill-down analytics. Avoid decorative charts before permissions, data freshness, and operational alerts are in place.');
p.para('Prepared: 20 July 2026  |  Language: English  |  Version: 1.0',{size:7.8,color:C.muted,after:0});

p=page('Goals & structure');
p.heading('1. Product goals and principles');
p.bullets([
  'Provide a five-second health summary of the SaaS platform.',
  'Turn important changes into clear, permission-aware actions.',
  'Make every card traceable to a filtered tenant list, report, or detail page.',
  'Expose data freshness and calculation context; never show unexplained totals.',
  'Keep the first version desktop-first, responsive down to tablet width, and ready for Arabic RTL in the next localization slice.',
]);
p.callout('Non-goals for V1','Do not duplicate POS operational screens, create a full BI warehouse, or replace dedicated tenant, billing, audit-log, and system-health pages. The dashboard should summarize and route users to those modules.',C.warn);
p.heading('2. Information architecture');
p.para('The dashboard should use one global time range and one global comparison period. A compact filter bar should remain visible at the top of the content area.');
p.table(['Zone','Content','Why it exists'],[
  ['Global header','Date range, timezone, currency display mode, refresh status, operator menu.','Sets reporting context and confidence.'],
  ['Attention strip','Critical alerts and recommended actions.','Surfaces issues before metrics.'],
  ['KPI row','Tenants, subscriptions, sales, orders, payment health.','Fast business pulse.'],
  ['Trends','Sales / orders trend, tenant growth, subscription distribution.','Shows direction and anomalies.'],
  ['Operational queues','At-risk trials, suspended tenants, failed jobs, support follow-ups.','Makes the page actionable.'],
  ['Recent activity','Tenant events, security events, major platform changes.','Provides accountability and context.'],
],[92,242,165]);

p=page('Layout & KPIs');
p.heading('3. Dashboard layout - recommended V1');
p.para('Use a responsive twelve-column grid on desktop. At medium widths, stack charts and queues; retain the action strip and KPI row. This is a content blueprint, not a visual mockup.');
p.table(['Row','Modules','Interaction'],[
  ['1','Context bar: date range, comparison, refresh timestamp.','Changing filters refreshes all modules.'],
  ['2','Attention strip: 0-5 highest-priority alerts.','Each alert opens its relevant detail or filtered list.'],
  ['3','Six KPI cards.','Each card links to a drill-down with the same filters.'],
  ['4','Sales & orders trend (8 cols) | subscription mix (4 cols).','Hover tooltips and accessible data-table fallback.'],
  ['5','Tenant growth (6 cols) | platform health summary (6 cols).','Click a status segment to apply its filter.'],
  ['6','Action queue (7 cols) | recent activity (5 cols).','Deep links and acknowledgement where permitted.'],
],[38,268,193]);
p.heading('4. Required KPI cards');
p.para('Every KPI card must show a current value, delta versus the comparison period, definition tooltip, and data freshness. Amounts should be grouped by currency unless the platform has an approved conversion policy.');
p.table(['KPI','Definition','Primary drill-down','Priority'],[
  ['Active tenants','Tenants active at the end of the selected period.','Tenants filtered by status=active.','P0'],
  ['New tenants','Tenants created during the selected period.','Tenant directory filtered by creation date.','P0'],
  ['Trials ending soon','Trial subscriptions ending in next 7 / 14 days.','Subscriptions filtered by expiry.','P0'],
  ['Suspended tenants','Tenants currently suspended.','Tenants filtered by status=suspended.','P0'],
  ['Gross sales','Tenant order gross sales by original currency.','Analytics with same date range.','P1'],
  ['Completed orders','Paid or completed orders, per agreed status contract.','Analytics / orders report.','P1'],
  ['Subscription health','Active, trialing, past due, cancelled counts.','Subscriptions filtered by status.','P0'],
  ['Platform health','Critical services and failed background jobs.','System Health.','P0'],
],[90,174,178,57]);

p=page('Operations & API');
p.heading('5. Charts, queues, and activity');
p.table(['Module','Minimum content','Rules'],[
  ['Sales and orders trend','Daily gross sales and completed orders; selectable 7, 30, 90 days.','Separate currencies or label an approved conversion policy.'],
  ['Tenant growth','Created, activated, suspended tenants over time.','Use grouped bars or lines; period comparison available.'],
  ['Subscription mix','Counts by plan and status.','Click a segment to open a filtered subscriptions list.'],
  ['Action queue','Trials ending, past due, suspensions, onboarding failures, health incidents.','Rank by urgency; show owner, due date, and direct action.'],
  ['Recent activity','Tenant created, status changed, plan changed, admin login/security event.','Show actor, timestamp, target, and audit-log deep link.'],
  ['Platform health','API availability, queue failures, scheduled task health, error rate.','Show state, threshold, last check, and incident-history link.'],
],[92,202,205]);
p.callout('Actionability rule','A dashboard item that cannot be investigated or acted on should not be promoted to the main page. Every warning needs an owner, a threshold, and a destination.',C.good);
p.heading('6. States, permissions, and trust');
p.table(['Concern','Required behavior'],[
  ['Authentication','Route guard calls /auth/me before rendering secured content. Unauthenticated users go to /login.'],
  ['Authorization','Hide actions without permission, but enforce the same permission on Laravel APIs. Show a clear 403 state for denied direct URLs.'],
  ['Loading and errors','Use skeletons for metrics/charts. Preserve successful modules and show retry for failed modules; never show failed data as zero.'],
  ['Data freshness','Display Last updated and an explicit refresh control; show stale-data warning after an agreed threshold.'],
  ['Accessibility and RTL','Keyboard navigation, visible focus, semantic tables, chart text equivalents, translation keys, and RTL-safe layout.'],
],[120,379]);

p=page('Delivery roadmap');
p.heading('7. API and data requirements');
p.para('The current backend exposes login, current user, dashboard metrics, tenant search/onboarding/detail, and tenant status updates. Dashboard V1 needs a stable aggregate contract plus drill-down links. Prefer a single dashboard endpoint for summary data, while preserving module-level failure reporting in the UI.');
p.table(['Endpoint / source','Needed for dashboard','Status'],[
  ['GET /auth/me','Session bootstrap, user name, permissions.','Existing'],
  ['GET /dashboard','Core metrics, currency sales, recent tenants.','Existing; needs expansion'],
  ['GET /tenants','Drill-down lists, pagination, filtering.','Existing; UI integration needed'],
  ['GET /subscriptions','Trial/past-due queues, plan and status mix.','Required'],
  ['GET /analytics/overview','Trends, growth, and revenue aggregation.','Required'],
  ['GET /system/health','Service, queue, and status summary.','Required'],
  ['GET /audit-logs','Recent platform activity.','Required'],
  ['POST /auth/logout','Safe session termination.','Existing; UI integration needed'],
],[125,250,124]);
p.para('Recommended dashboard query parameters: from, to, compareTo, timezone, and currencyMode. Responses should include generatedAt, metric definitions/version, and a per-module status when feasible.',{size:8.4,leading:12,after:10});
p.heading('8. Delivery roadmap');
p.table(['Phase','Outcome','Key deliverables','Exit criteria'],[
  ['0 - Foundation','A buildable, secure shell.','Fix Next.js type error; route guard; logout; active navigation; shared loading/error components.','Production build passes; protected routes redirect correctly.'],
  ['1 - Core dashboard','Reliable daily operating view.','Context bar, attention strip, six KPI cards, expanded API, empty/error/freshness states.','Operators can identify active tenants, trials, suspensions, sales, and platform status.'],
  ['2 - Tenant operations','Actionable tenant lifecycle.','Tenant details, status-change UI, search/filter/pagination, onboarding validation.','Operator can find, inspect, onboard, and change tenant status.'],
  ['3 - Commercial & health','Trends and exceptions.','Subscriptions, analytics trends, system health, audit logs, alert queue.','Every chart and alert has a verified drill-down.'],
  ['4 - Hardening','Operational confidence.','RTL/i18n, accessibility audit, tests, performance checks, export jobs.','Acceptance checks pass and Arabic readiness is confirmed.'],
],[60,88,204,147]);

p=page('Acceptance & decisions');
p.heading('9. Acceptance checklist');
p.bullets([
  'The page builds and type-checks successfully in the production pipeline.',
  'A signed-out user never sees protected data; a signed-in user only sees actions allowed by platform permissions.',
  'All KPI values have clear definitions, timeframe, comparison, and freshness information.',
  'The dashboard never treats a failed API call as zero data.',
  'Each card, chart segment, alert, and activity item reaches a valid filtered detail view.',
  'Currency presentation follows an approved policy and cannot silently mix currencies.',
  'Desktop, tablet, keyboard, and screen-reader behavior meet the agreed baseline.',
  'Automated tests cover authentication guard, loading/error/empty states, filter propagation, and major drill-down links.',
]);
p.heading('10. Decisions to confirm before implementation');
p.table(['Decision','Why it matters','Suggested default'],[
  ['Revenue currency policy','Determines whether totals can be combined.','Show original-currency totals; add conversion only with a trusted FX source.'],
  ['Completed order definition','Affects all sales/order metrics.','Document exact order and payment statuses in the API contract.'],
  ['Alert ownership','Prevents ignored dashboard warnings.','Assign a team/role and escalation path to every alert type.'],
  ['Data refresh target','Sets user expectations and implementation cost.','On-demand refresh plus visible timestamp; optimize live updates later.'],
  ['Initial roles','Shapes which actions are visible.','Platform Super Admin, Operations, Support, Finance, Read-only Analyst.'],
],[130,194,215]);
p.callout('Recommended next step','Approve Phase 0 and the V1 KPI definitions, then implement the dashboard API contract and protected web shell together. This prevents visual work from being built on unstable data or unsecured routes.');

const objects = [];
const add = body => { objects.push(body); return objects.length; };
const catalog = add('<< /Type /Catalog /Pages 2 0 R >>');
const pagesRoot = add('');
const f1 = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>');
const f2 = add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>');
const pageRefs=[];
for (const pg of pages) {
  const stream = pg.s;
  const contentRef = add(`<< /Length ${Buffer.byteLength(stream,'binary')} >>\nstream\n${stream}endstream`);
  const pageRef = add(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${W} ${H}] /Resources << /Font << /F1 ${f1} 0 R /F2 ${f2} 0 R >> >> /Contents ${contentRef} 0 R >>`);
  pageRefs.push(pageRef);
}
objects[pagesRoot-1] = `<< /Type /Pages /Count ${pageRefs.length} /Kids [${pageRefs.map(n=>`${n} 0 R`).join(' ')}] >>`;
const info = add('<< /Title (Super Admin Dashboard Plan) /Author (Cafe 6:18 Platform) /Subject (Product and delivery blueprint) >>');
let pdf='%PDF-1.4\n%PDF\n'; const offsets=[0];
objects.forEach((body,i)=>{ offsets.push(Buffer.byteLength(pdf,'binary')); pdf += `${i+1} 0 obj\n${body}\nendobj\n`; });
const xref = Buffer.byteLength(pdf,'binary');
pdf += `xref\n0 ${objects.length+1}\n0000000000 65535 f \n`;
for(let i=1;i<offsets.length;i++) pdf += `${String(offsets[i]).padStart(10,'0')} 00000 n \n`;
pdf += `trailer\n<< /Size ${objects.length+1} /Root ${catalog} 0 R /Info ${info} 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
fs.writeFileSync(output,pdf,'binary');
console.log(`${output} (${pages.length} pages, ${Buffer.byteLength(pdf,'binary')} bytes)`);
console.log(`Layout bottoms: ${pages.map(pg => `${pg.number}:${pg.y.toFixed(1)}`).join(', ')}`);
