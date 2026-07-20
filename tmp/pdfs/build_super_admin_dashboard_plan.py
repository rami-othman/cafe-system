from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    KeepTogether,
    PageBreak,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "output" / "pdf" / "super_admin_dashboard_plan.pdf"
OUT.parent.mkdir(parents=True, exist_ok=True)

INK = colors.HexColor("#231005")
MUTED = colors.HexColor("#6B5A50")
PRIMARY = colors.HexColor("#3B2417")
ACCENT = colors.HexColor("#C47A3A")
SAND = colors.HexColor("#FAF7F2")
LINE = colors.HexColor("#E7E2DA")
WHITE = colors.white
GOOD = colors.HexColor("#256A48")
WARN = colors.HexColor("#A85D13")
RISK = colors.HexColor("#A32E2E")


styles = getSampleStyleSheet()
styles.add(ParagraphStyle(
    name="TitleCafe", parent=styles["Title"], fontName="Helvetica-Bold", fontSize=26,
    leading=31, textColor=INK, spaceAfter=7,
))
styles.add(ParagraphStyle(
    name="SubTitleCafe", parent=styles["Normal"], fontName="Helvetica", fontSize=10.5,
    leading=15, textColor=MUTED, spaceAfter=18,
))
styles.add(ParagraphStyle(
    name="H1Cafe", parent=styles["Heading1"], fontName="Helvetica-Bold", fontSize=17,
    leading=22, textColor=PRIMARY, spaceBefore=8, spaceAfter=9,
))
styles.add(ParagraphStyle(
    name="H2Cafe", parent=styles["Heading2"], fontName="Helvetica-Bold", fontSize=12.5,
    leading=16, textColor=PRIMARY, spaceBefore=8, spaceAfter=5,
))
styles.add(ParagraphStyle(
    name="BodyCafe", parent=styles["BodyText"], fontName="Helvetica", fontSize=9.2,
    leading=13.2, textColor=INK, spaceAfter=5,
))
styles.add(ParagraphStyle(
    name="SmallCafe", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.8,
    leading=10.4, textColor=MUTED,
))
styles.add(ParagraphStyle(
    name="CardTitle", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=8.4,
    leading=10.6, textColor=PRIMARY,
))
styles.add(ParagraphStyle(
    name="CardText", parent=styles["BodyText"], fontName="Helvetica", fontSize=8.1,
    leading=10.6, textColor=INK,
))
styles.add(ParagraphStyle(
    name="TableHead", parent=styles["BodyText"], fontName="Helvetica-Bold", fontSize=7.7,
    leading=9.5, textColor=WHITE,
))
styles.add(ParagraphStyle(
    name="TableCell", parent=styles["BodyText"], fontName="Helvetica", fontSize=7.55,
    leading=9.7, textColor=INK,
))


def p(text, style="BodyCafe"):
    return Paragraph(text, styles[style])


def bullets(items):
    return [p(f"- {item}") for item in items]


def table(rows, widths, header=True):
    content = []
    for row_index, row in enumerate(rows):
        style = "TableHead" if header and row_index == 0 else "TableCell"
        content.append([cell if hasattr(cell, "wrap") else p(str(cell), style) for cell in row])
    result = Table(content, colWidths=widths, repeatRows=1 if header else 0, hAlign="LEFT")
    commands = [
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("GRID", (0, 0), (-1, -1), 0.35, LINE),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]
    if header:
        commands += [("BACKGROUND", (0, 0), (-1, 0), PRIMARY)]
    for i in range(1 if header else 0, len(content)):
        if i % 2 == 0:
            commands.append(("BACKGROUND", (0, i), (-1, i), SAND))
    result.setStyle(TableStyle(commands))
    return result


def note(label, text, background=SAND, color=ACCENT):
    t = Table([[p(f"<b>{label}</b><br/>{text}", "CardText")]], colWidths=[170 * mm])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), background),
        ("BOX", (0, 0), (-1, -1), 0.7, color),
        ("LINEBEFORE", (0, 0), (0, -1), 4, color),
        ("LEFTPADDING", (0, 0), (-1, -1), 11),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t


class PlanDoc(BaseDocTemplate):
    def __init__(self, filename):
        super().__init__(filename, pagesize=A4, leftMargin=20*mm, rightMargin=20*mm,
                         topMargin=18*mm, bottomMargin=17*mm)

    def afterPage(self):
        canvas = self.canv
        canvas.saveState()
        w, h = A4
        canvas.setStrokeColor(LINE)
        canvas.setLineWidth(0.4)
        canvas.line(20*mm, 11*mm, w-20*mm, 11*mm)
        canvas.setFillColor(MUTED)
        canvas.setFont("Helvetica", 7.5)
        canvas.drawString(20*mm, 7*mm, "Cafe 6:18 Platform - Super Admin Dashboard Plan")
        canvas.drawRightString(w-20*mm, 7*mm, f"Page {canvas.getPageNumber()}")
        canvas.restoreState()


def section(title):
    return [Spacer(1, 3), p(title, "H1Cafe")]


def build():
    doc = PlanDoc(str(OUT))
    story = []

    story += [
        Spacer(1, 23*mm),
        p("Super Admin Dashboard Plan", "TitleCafe"),
        p("Cafe 6:18 Platform | Product, operations, and delivery blueprint", "SubTitleCafe"),
        note("Purpose", "Define the first production-ready dashboard for platform operators. The dashboard should answer: Is the platform healthy? Are tenants growing and compliant? What requires action now?"),
        Spacer(1, 12),
        p("Document scope", "H2Cafe"),
        p("This plan covers the <b>Super Admin</b> web dashboard, not the cafe POS or an individual tenant's back-office dashboard. It is designed for staff who operate the multi-tenant Cafe 6:18 platform."),
        Spacer(1, 6),
        table([
            ["Audience", "Primary outcome", "Frequency"],
            ["Platform operator", "Detect urgent tenant, revenue, and platform issues", "Daily"],
            ["Platform manager", "Track adoption, commercial health, and operational trends", "Weekly"],
            ["Support / finance", "Find tenants needing follow-up or reconciliation", "On demand"],
        ], [40*mm, 94*mm, 36*mm]),
        Spacer(1, 14),
        p("Recommended delivery order", "H2Cafe"),
        p("First make the dashboard reliable and actionable; then add drill-down analytics. Avoid building decorative charts before permissions, data freshness, and operational alerts are in place."),
        Spacer(1, 8),
        p("Prepared: 20 July 2026 | Language: English | Version: 1.0", "SmallCafe"),
        PageBreak(),
    ]

    story += section("1. Product goals and principles")
    story += bullets([
        "Provide a five-second health summary of the SaaS platform.",
        "Turn important changes into clear, permission-aware actions.",
        "Make every card traceable to a filtered tenant list, report, or detail page.",
        "Expose data freshness and calculation context; never show unexplained totals.",
        "Keep the first version desktop-first, responsive down to tablet width, and ready for Arabic RTL in the next localization slice.",
    ])
    story += [Spacer(1, 5), note("Non-goals for V1", "Do not duplicate POS operational screens, create a full BI warehouse, or replace dedicated tenant, billing, audit-log, and system-health pages. The dashboard should summarize and route users to those modules.", colors.HexColor("#F8F2E9"), WARN)]

    story += section("2. Information architecture")
    story += [
        p("The dashboard should use one global time range and one global comparison period. A compact filter bar should remain visible at the top of the content area."),
        table([
            ["Zone", "Content", "Why it exists"],
            ["Global header", "Date range, timezone, currency display mode, refresh status, operator menu", "Sets the reporting context and confidence"],
            ["Attention strip", "Critical alerts and recommended actions", "Surfaces issues before metrics"],
            ["KPI row", "Tenants, subscriptions, sales, orders, payment health", "Fast business pulse"],
            ["Trends", "Sales/orders trend, tenant growth, subscription distribution", "Shows direction and anomalies"],
            ["Operational queues", "At-risk trials, suspended tenants, failed jobs, support follow-ups", "Makes the page actionable"],
            ["Recent activity", "Tenant events, security events, major platform changes", "Provides accountability and context"],
        ], [31*mm, 65*mm, 74*mm]),
    ]

    story += section("3. Dashboard layout - recommended V1")
    story += [
        p("Use a responsive twelve-column grid on desktop. At medium widths, stack charts and queues; retain the action strip and KPI row. The layout below is a content blueprint, not a visual mockup."),
        table([
            ["Row", "Modules", "Interaction"],
            ["1", "Context bar: date range, comparison, refresh timestamp", "Changing filters refreshes all dashboard modules"],
            ["2", "Attention strip: 0-5 highest-priority alerts", "Each alert opens its relevant detail or filtered list"],
            ["3", "6 KPI cards", "Each card links to a drill-down view with the same filters"],
            ["4", "Sales & orders trend (8 cols) | subscription mix (4 cols)", "Hover tooltips; accessible data table fallback"],
            ["5", "Tenant growth (6 cols) | platform health summary (6 cols)", "Click a status segment to apply its filter"],
            ["6", "Action queue (7 cols) | recent activity (5 cols)", "Deep links; acknowledgement where permitted"],
        ], [18*mm, 102*mm, 50*mm]),
    ]

    story += section("4. Required KPI cards")
    story += [
        p("Every KPI card must show a current value, delta versus the comparison period, definition tooltip, and data freshness. Amounts should be grouped by currency unless the platform has an approved conversion policy."),
        table([
            ["KPI", "Definition", "Primary drill-down", "Priority"],
            ["Active tenants", "Tenants currently active at end of selected period", "Tenants filtered by status=active", "P0"],
            ["New tenants", "Tenants created during selected period", "Tenant directory filtered by creation date", "P0"],
            ["Trials ending soon", "Trial subscriptions ending in next 7 / 14 days", "Subscriptions filtered by expiry", "P0"],
            ["Suspended tenants", "Tenants currently suspended", "Tenants filtered by status=suspended", "P0"],
            ["Gross sales", "Tenant order gross sales by original currency", "Analytics with same date range", "P1"],
            ["Completed orders", "Paid or completed orders, per agreed status contract", "Analytics / orders report", "P1"],
            ["Subscription health", "Active, trialing, past due, cancelled counts", "Subscriptions filtered by status", "P0"],
            ["Platform health", "Critical services and failed background jobs", "System Health", "P0"],
        ], [31*mm, 63*mm, 51*mm, 25*mm]),
    ]

    story += [PageBreak()]
    story += section("5. Charts, queues, and activity")
    story += [
        table([
            ["Module", "Minimum content", "Rules"],
            ["Sales and orders trend", "Daily gross sales and completed orders; selectable 7, 30, 90 days", "Separate currencies or label conversion policy clearly; show no misleading combined total"],
            ["Tenant growth", "Created, activated, suspended tenants over time", "Use grouped bars or lines; period comparison available"],
            ["Subscription mix", "Counts by plan and status", "Clicking a segment opens a filtered subscriptions list"],
            ["Action queue", "Trials ending, past due, suspended with reason, onboarding failures, health incidents", "Rank by urgency; show owner, due date, and direct action"],
            ["Recent activity", "Tenant created, status changed, plan changed, admin login/security event", "Show actor, timestamp, target, and audit-log deep link"],
            ["Platform health", "API availability, queue failures, scheduled task health, error rate", "Show current state, threshold, last check, and incident history link"],
        ], [37*mm, 67*mm, 66*mm]),
        Spacer(1, 8),
        note("Actionability rule", "A dashboard item that cannot be investigated or acted on should not be promoted to the main page. Every warning needs an owner, a threshold, and a destination.", colors.HexColor("#EDF6F0"), GOOD),
    ]

    story += section("6. States, permissions, and trust")
    story += [
        table([
            ["Concern", "Required behavior"],
            ["Authentication", "Route guard calls /auth/me before rendering secured content. Unauthenticated users are redirected to /login."],
            ["Authorization", "Hide actions without permission, but enforce the same permission on Laravel APIs. Show a clear 403 state when a direct URL is denied."],
            ["Loading", "Use skeletons for the metric grid and chart areas; do not leave blank cards."],
            ["Empty data", "Explain why data is absent and provide a next step, such as creating a tenant or adjusting the date range."],
            ["Errors", "Show module-level retry actions and preserve successful modules. Do not hide a failed request behind zero values."],
            ["Data freshness", "Display 'Last updated' and an explicit refresh control; show stale-data warning after an agreed threshold."],
            ["Accessibility", "Keyboard navigation, visible focus, semantic tables, text equivalents for charts, and color-independent status labels."],
            ["Localization", "Build text through translation keys and make containers RTL-safe before Arabic translation is added."],
        ], [38*mm, 132*mm]),
    ]

    story += section("7. API and data requirements")
    story += [
        p("The current backend exposes login, current user, dashboard metrics, tenant search/onboarding/detail, and tenant status updates. The dashboard V1 needs a stable aggregate contract plus drill-down links. Prefer a single dashboard endpoint for summary data, while preserving module-level failure reporting in the UI."),
        table([
            ["Endpoint / source", "Needed for dashboard", "Status"],
            ["GET /auth/me", "Session bootstrap, user name, permissions", "Existing"],
            ["GET /dashboard", "Core metrics, currency sales, recent tenants", "Existing but needs expansion"],
            ["GET /tenants", "Drill-down lists, pagination, filtering", "Existing; UI integration needed"],
            ["GET /subscriptions", "Trial/past-due queues, plan/status mix", "Required"],
            ["GET /analytics/overview", "Trends, growth and revenue aggregation", "Required"],
            ["GET /system/health", "Service/queue/status summary", "Required"],
            ["GET /audit-logs", "Recent platform activity", "Required"],
            ["POST /auth/logout", "Safe session termination", "Existing; UI integration needed"],
        ], [50*mm, 77*mm, 43*mm]),
        Spacer(1, 6),
        p("Recommended dashboard query parameters: <b>from</b>, <b>to</b>, <b>compareTo</b>, <b>timezone</b>, and <b>currencyMode</b>. Responses should include <b>generatedAt</b>, metric definitions/version, and a per-module status when feasible.", "BodyCafe"),
    ]

    story += [PageBreak()]
    story += section("8. Delivery roadmap")
    story += [
        table([
            ["Phase", "Outcome", "Key deliverables", "Exit criteria"],
            ["0 - Foundation", "A buildable, secure shell", "Fix Next.js type error; route guard; logout; active navigation; shared loading/error components", "Production build passes; all protected routes redirect correctly"],
            ["1 - Core dashboard", "Reliable daily operating view", "Context bar, attention strip, 6 core KPI cards, expanded dashboard API, empty/error/freshness states", "Operators can identify active tenants, trials, suspensions, sales and platform status"],
            ["2 - Tenant operations", "Actionable tenant lifecycle", "Tenant details, status change UI, search/filter/pagination, onboarding validation", "An operator can find, inspect, onboard and change tenant status without API tools"],
            ["3 - Commercial & health", "Trends and exceptions", "Subscriptions, analytics trends, system health, audit logs, alert queue", "Every chart and alert has a verified drill-down"],
            ["4 - Hardening", "Operational confidence", "RTL/i18n, accessibility audit, tests, performance checks, export jobs", "Acceptance checks pass and Arabic readiness is confirmed"],
        ], [23*mm, 32*mm, 68*mm, 47*mm]),
    ]

    story += section("9. Acceptance checklist")
    story += bullets([
        "The page builds and type-checks successfully in the production pipeline.",
        "A signed-out user never sees protected data; a signed-in user only sees actions allowed by their platform permissions.",
        "All KPI values have clear definitions, timeframe, comparison, and freshness information.",
        "The dashboard never treats a failed API call as zero data.",
        "Each card, chart segment, alert, and activity item reaches a valid filtered detail view.",
        "Currency presentation follows an approved policy and cannot silently mix currencies.",
        "Desktop, tablet, keyboard, and screen-reader behavior meet the agreed baseline.",
        "Automated tests cover authentication guard, loading/error/empty states, filter propagation, and major drill-down links.",
    ])

    story += section("10. Decisions to confirm before implementation")
    story += [
        table([
            ["Decision", "Why it matters", "Suggested default"],
            ["Revenue currency policy", "Determines whether totals can be combined", "Show original-currency totals; add conversion only with a trusted FX source"],
            ["Completed order definition", "Affects all sales/order metrics", "Document exact order and payment statuses in the API contract"],
            ["Alert ownership", "Prevents ignored dashboard warnings", "Assign a team/role and escalation path to each alert type"],
            ["Data refresh target", "Sets user expectations and implementation cost", "On-demand refresh plus a visible timestamp; optimize live updates later"],
            ["Initial roles", "Shapes what actions are visible", "Platform Super Admin, Operations, Support, Finance, Read-only Analyst"],
        ], [45*mm, 75*mm, 50*mm]),
        Spacer(1, 12),
        note("Recommended next step", "Approve Phase 0 and the V1 KPI definitions, then implement the dashboard API contract and protected web shell together. This prevents visual work from being built on unstable data or unsecured routes."),
    ]

    doc.build(story)
    print(OUT)


if __name__ == "__main__":
    build()
