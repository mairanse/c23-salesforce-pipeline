# C23 Permission Studio – Agent Build Spec

## Feature: User Permission Summary (v1)

Build a new tool that lets an admin search for a Salesforce User and view a summarized breakdown of their permissions across:
- Profile
- Permission Sets
- Permission Set Groups
- Muting Permission Sets (later)

## Constraints
- Net-new only.
- All LWC must be prefixed with c23.
- All Apex must be prefixed with c23_.
- Compute values in JS (no template expressions).
- Always work in small commits.
- After meaningful change: run ./scripts/deploy-fast.sh dev
- Never commit directly to main.

## Current Objective
Implement user search typeahead + selected user header display.

---

## Autonomous Loop Contract

You must follow this loop for any implementation work:

1) PLAN
   - Write a short implementation plan in chat before editing files.

2) IMPLEMENT
   - Make the smallest possible changes needed for the current milestone.
   - Do not modify unrelated files.
   - Net-new only for this feature.

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

### Safety Rules
- Never commit directly to main.
- Work only in the current branch.
- Never commit unrelated metadata.
- Compute values in JS (no template expressions).
- Keep logging lightweight.


---

## Autonomous Loop Contract

You must follow this loop for any implementation work:

1) PLAN
   - Write a short implementation plan in chat before editing files.

2) IMPLEMENT
   - Make the smallest possible changes needed for the current milestone.
   - Do not modify unrelated files.
   - Net-new only for this feature.

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

### Safety Rules
- Never commit directly to main.
- Work only in the current branch.
- Never commit unrelated metadata.
- Compute values in JS (no template expressions).
- Keep logging lightweight.


---

## Autonomous Loop Contract

You must follow this loop for any implementation work:

1) PLAN
   - Write a short implementation plan in chat before editing files.

2) IMPLEMENT
   - Make the smallest possible changes needed for the current milestone.
   - Do not modify unrelated files.
   - Net-new only for this feature.

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

### Safety Rules
- Never commit directly to main.
- Work only in the current branch.
- Never commit unrelated metadata.
- Compute values in JS (no template expressions).
- Keep logging lightweight.

