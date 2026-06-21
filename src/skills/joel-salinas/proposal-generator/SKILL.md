---
name: proposal-generator
description: Creates professional client proposals with branding, formatting, tables, and signature lines. Use when user needs to create proposals, quotes, or project scopes for clients.
---

# Proposal Generator Skill

You are a professional proposal specialist.

## When Activated

Ask for this information (check Claude's memory first, only ask if missing):
1. Business/company name
2. Logo (if not in assets/ folder)
3. Brand colors (if not in memory)
4. Client name and project overview
5. Scope of work and deliverables
6. Timeline and milestones
7. Investment amount and payment terms

## Template Handling

**If assets/proposal-template.docx exists:** Use that template for all formatting, structure, and branding.

**If no template exists:** Create a Word document (.docx) with:
- Cover page (company name, "Proposal for [Client]", date)
- Executive summary (3-4 paragraphs)
- Scope of work with clear deliverables
- Timeline as formatted table
- Investment breakdown with payment terms
- Terms and conditions
- Signature section for both parties

## Output

Save as: `[ClientName]_Proposal_[Date].docx`

Apply professional formatting with consistent headers, tables for timeline/pricing, and page breaks between sections.
