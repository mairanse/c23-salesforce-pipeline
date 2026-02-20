# C23 Experience Cloud Bundle – Agent Charter

## Scope
Build a bundle of killer Experience Cloud LWCs:
- c23PortalGlobalSearch (Multi-Object Global Search)
- c23KnowledgeExplorerPro (Knowledge Explorer Pro + AI Summary UX)
- c23SmartCtaBanner (Smart CTA Banner)
- c23HeroSection (Hero w/ conditional variants)
- c23AnnouncementBar (Announcement/Notification bar)

## Naming rules
- All LWCs must be prefixed with c23
- All Apex must be prefixed with c23_

## Development rules
- Compute template-ready values in JS (no template expressions)
- Keep logging lightweight
- Prefer SLDS utilities/tokens; minimal custom CSS
- This is dev org: tests optional

## Autonomous loop contract
For each milestone:
1) PLAN (short bullet plan in chat)
2) IMPLEMENT (smallest changes for milestone)
3) VALIDATE (run: ./scripts/deploy-fast.sh dev)
4) FIX (up to 6 attempts)
5) COMMIT + PUSH (clear message)
Stop and report when all milestones complete.

## Milestones
M1: Scaffold + baseline render for all 5 LWCs (no data)
M2: Smart CTA Banner + Announcement Bar (config-driven, targeted visibility, click/dismiss persistence)
M3: Hero Section conditional variants (config-driven, targeting)
M4: Global Search (multi-object search + results grouping + filters v1)
M5: Knowledge Explorer Pro (facets + results + article view + AI summary panel UX + Apex stubs)

## Configuration approach
Prefer Custom Metadata Types (CMT) for admin-configurable content/targeting rules.
Targeting rules should support:
- Audience: guest/authenticated, profile/permission set (optional), user fields (optional)
- Context: recordId/accountId (optional), page route (optional)
- Scheduling: start/end dates
- Priority + fallback
Persist per-user UI state (dismissed announcements) using:
- localStorage for unauthenticated/guest
- Platform Cache / Custom Object (optional) for authenticated (agent chooses best)
