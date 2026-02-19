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
