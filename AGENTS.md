# C23 Permission Studio – Agent Charter

## Primary Objective
Build a net-new “User Permission Summary” tool that:
1) Lets an admin search and select a user, then summarizes effective permissions across Profile + Permission Sets + Permission Set Groups.
2) Adds a comparison mode to compare up to 4 users side-by-side (assignments only first), showing common/shared/unique/missing.

## Naming Rules
- All LWCs must be prefixed with `c23` (e.g., c23UserCompare).
- All Apex must be prefixed with `c23_` (e.g., c23_UserPermissionSummaryService).

## Development Rules
- Compute template-ready properties in JS (avoid template expressions).
- Keep logging lightweight.
- Prefer SLDS utilities/tokens for layout and hierarchy.
- This is a dev org: prioritize speed; tests are optional for now.

## Working Rules (Autonomous Loop Contract)
You must follow this loop for any milestone:

1) PLAN
   - Write a short plan in chat before editing files.

2) IMPLEMENT
   - Make the smallest possible changes needed for the milestone.
   - Avoid unrelated refactors.

3) VALIDATE
   - Run: ./scripts/deploy-fast.sh dev

4) IF DEPLOY FAILS
   - Read the error carefully.
   - Fix the root cause.
   - Re-run deploy.
   - Maximum 6 attempts per milestone.

5) SUCCESS CONDITION
   - Deploy succeeds.
   - Summarize what changed.
   - Commit with a clear message.
   - Push to origin.

## Scope Boundaries
- It’s OK to modify existing files in this repo if needed (dev org, low risk),
  but prefer keeping this feature largely net-new and isolated.
- Never commit secret tokens or auth output.

---

## Feature: User Permission Summary + Compare (3 phases)

### Phase 1 (DONE)
- User search typeahead (c23UserLookup) + selected user header (c23UserPermissionSummary).
- Apex: searchUsers(query) returns DTO list with user basics.

### Phase 2 (TODO): Assignments Summary for a single user
After selecting a user, fetch and display:
- Profile Name
- Permission Set Assignments (count + list)
- Permission Set Group Assignments (count + list)
- Muting Permission Sets derived from groups (count + list)

Apex:
- Add @AuraEnabled(cacheable=true) getAssignments(userId) returning a single DTO:
  - profileName
  - permissionSets: [{id,name}]
  - permissionSetGroups: [{id,name,mutingPermissionSetId,mutingPermissionSetName}]
  - mutingPermissionSets: [{id,name}]
  - counts for each category

Data sources (tight queries):
- PermissionSetAssignment (exclude profile-owned perm sets)
- PermissionSetGroupAssignment (include group + group muting permission set id)
- PermissionSet (to resolve muting names)

UI:
- Three sections (expand/collapse is optional in v1) with counts + lists.
- Keep layout simple; improve hierarchy lightly (header + sections + internal scroll if needed).

### Phase 3 (TODO): Compare up to 4 users (Assignments-only first)
Allow selecting up to 4 users and show side-by-side comparison for:
- Permission Sets
- Permission Set Groups
- Muting Permission Sets

Comparison outputs:
- Common: present for all selected users
- Unique: present for exactly one user (grouped by user)
- Missing: for each user, items that at least one other user has but they do not

Apex:
- Add @AuraEnabled(cacheable=true) getAssignmentsBulk(List<Id> userIds)
  returning List<UserAssignmentSummary> (same DTO shape per user).
- Bulkify queries (single query per assignment object, map by AssigneeId).

UI:
- New container LWC: c23UserCompare
- Multi-select user picker (reuse c23UserLookup or create c23UserMultiLookup).
- Enforce max 4 users with clear message.
- Render N columns (N = selected users).
- Compute comparison sets in JS:
  - common lists
  - unique per user
  - missing per user
