---
name: frontend-taste
description: Replace default frontend design instincts with a stronger taste system -- deliberate layout, real typography, restrained color, and mandatory visual verification. Applies to all websites, apps, landing pages, and UI work. Routes to nested sub-skills based on task direction.
---

# Frontend Taste System

Replace default frontend design instincts with a stronger taste system. Applied to every frontend task -- not "make it prettier" in the moment, but a standing design philosophy.

## Trigger Conditions

- ALL frontend design and implementation work
- Building websites, apps, landing pages, dashboards, or UI components
- Redesigning or restyling existing projects
- User asks for anything visual

## Setup Interview

On first use, ask for 2-3 sites or apps the user admires and why. These become taste references applied to all future work.

## Core Rules

### Layout
- **Deliberate variance** -- no default hero-plus-three-cards pattern. Every page justifies its layout from the content, not from a template
- **Real grids** -- explicit column structures, not flex-wrap jumbles
- **Intentional whitespace** -- generous spacing that serves hierarchy, not crammed or arbitrarily padded
- **Asymmetric when appropriate** -- symmetry is a choice, not a default

### Typography
- **Real type scale** -- defined ratios between heading levels (1.25, 1.333, or 1.5), not browser defaults
- **Restrained pairings** -- one display/heading face, one body face. No font salad
- **Readable measure** -- 45-75 characters per line for body text
- **No default-stack sloppiness** -- every font size, weight, and line-height is intentional

### Color
- **Restrained palette** -- 3-5 colors total, not a gradient sampler
- **One accent doing real work** -- interactive elements, key emphasis, data highlights all share one accent
- **No purple-gradient-on-white cliches** -- no default framework color schemes
- **Accessible contrast** -- text meets WCAG AA minimums (4.5:1 for body, 3:1 for large text)

### Visual Verification (Mandatory)
1. Screenshot the result
2. Inspect critically: layout, spacing, typography, color, responsiveness
3. Fix what's weak
4. Repeat until it holds up under scrutiny
5. Only then call it done

## Nested Sub-Skills

The core skill routes to these based on the task:

### Sub-Skill: Minimalist / Editorial UI
- Maximum white space, minimum chrome
- Single column at comfortable reading width
- Type does all the heavy lifting
- Color is accent-only, never decorative
- Reference: Linear, Stripe docs, Medium

### Sub-Skill: Data-Dense Dashboard UI
- Information density without clutter
- Clear visual hierarchy through size, weight, position
- Tables with proper alignment (numbers right, text left)
- Color used for data encoding, not decoration
- Reference: Bloomberg Terminal, Grafana, Vercel Analytics

### Sub-Skill: Premium Landing Pages
- Strong visual narrative from top to bottom
- Social proof integrated, not tacked on
- One clear CTA path, not a buffet
- Motion/choreography considered
- Reference: Apple product pages, Linear homepage, Vercel homepage

### Sub-Skill: Redesigning Existing Projects
- Audit the current design first: what works, what doesn't, what's load-bearing
- Ship incrementally -- never redesign and break functionality simultaneously
- Match existing component API surfaces so nothing breaks
- Improve one dimension at a time: layout, then type, then color
- Screenshot before and after each change

## Verification

Build one landing page section and run the visual verification loop: screenshot, inspect, fix, repeat. Capture the iterations.
