# C23 Permission Studio – Agent Build Spec

## Feature: User Permission Summary (v1)
Build a new tool that lets an admin search for a Salesforce User and view a summarized breakdown of the user’s permissions across:
- Profile
- Permission Sets (assigned)
- Permission Set Groups (assigned)
- Muting Permission Sets (where applicable)

### Constraints
- Net-new only. Do not modify existing components/pages yet.
- All LWC names must be prefixed with c23.
- All Apex must be prefixed c23_.
- Compute values in JS (no template expressions).
- Keep logging lightweight.

### Deliverables
- LWC: c23UserPermissionSummary (container + results)
- LWC: c23UserLookup (typeahead search)
- Apex: c23_UserPermissionSummaryService (user search + summary endpoint)
