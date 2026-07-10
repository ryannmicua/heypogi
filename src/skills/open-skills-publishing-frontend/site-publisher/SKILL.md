---
name: site-publisher
description: Take a finished page or artifact and publish it to a personal/company website as a real shareable URL -- design matching, slug, OG image, indexing controls, local verification, and deploy. Use only when explicitly asked to publish, never auto-triggered.
---

# Personal Site Publisher

Take a finished page or artifact and publish it to your website as a real, share-ready URL. Everything that separates "an HTML file" from "a published page."

## Trigger Conditions

- ONLY when the user explicitly asks to publish, ship, or put something on their site
- Never auto-triggered -- publishing is always explicit

## Setup Interview

On first use, explore the user's website repo and ask:
- Repo path and stack (Next.js, Hugo, Jekyll, Astro, plain HTML, etc.)
- How routes/pages are added (file-based routing, config, manual)
- Deploy command and any verification steps
- Design language (or which existing pages to match for style)
- Default indexing preference for share pages (public vs. unlisted/noindex)

## Full Procedure

### 1. Clean Slug
- Derive from page title: lowercase, hyphens, no stop words, no dates unless relevant
- Example: "How I Built a GPU Cluster" -> `gpu-cluster-build`
- Check slug isn't already in use

### 2. Page Creation
- Create page file matching site conventions (file name, directory, frontmatter)
- Apply the site's design language: reuse layouts, components, and styles from existing pages
- Match existing page structure: same nav, footer, metadata patterns

### 3. Open Graph Image (1200x630)
- Generate a page-specific OG image (route through `image-gateway` skill if available)
- Include the page title or key visual, site branding
- Save to the site's asset/public directory
- Set `og:image`, `og:image:width`, `og:image:height` meta tags

### 4. Meta Tags
- `title`: page title + site name (if convention)
- `description`: 1-2 sentence share description
- `og:title`, `og:description`, `og:image`, `og:url`, `og:type`
- `twitter:card`: `summary_large_image`
- Indexing: `<meta name="robots" content="noindex">` if unlisted

### 5. Local Verification (Before Deploy)
- Build the site locally
- View the page: check layout, images, links, OG tags in `<head>`
- Run Lighthouse or basic perf check
- Verify at mobile, tablet, and desktop widths

### 6. Deploy
- Run the site's deploy command
- Wait for deployment to complete
- Confirm the live URL resolves

### 7. Post-Publish Checks
- Visit the live URL, confirm it loads
- Test OG preview with a tool like opengraph.xyz or a manual share preview
- Confirm indexing is correct (noindex if unlisted, indexable if public)

## Verification

Publish one unlisted test page end to end. Verify: live URL loads, OG image renders in share preview, design matches the rest of the site.
