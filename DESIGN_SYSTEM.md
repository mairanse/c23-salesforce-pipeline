# Permission Studio – Design System (Lightweight)

## Goals
- Strong visual hierarchy
- Max vertical space for data
- Consistent spacing, sectioning, and header patterns
- Salesforce-native feel (SLDS), but intentional and modern

## Layout Patterns
- Single compact header area: title/context + actions
- Content region: internal scroll when lists are long
- Avoid stacking multiple “page headers” inside a page

## Spacing & Density
- Prefer compact spacing for table/list heavy screens
- Use SLDS utilities for spacing; avoid one-off CSS where possible

## Components
- Use consistent section blocks:
  - section header: label + count
  - section body: list with empty state

## UX Rules
- Don’t hide essential info behind too many clicks
- Prefer progressive disclosure: show counts + first items, expand for the rest
