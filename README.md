# OpsDeck — WhatsApp CRM for agency teams

> Shared WhatsApp inbox, contacts, sales pipeline, campaigns and team
> management for agencies — built by Infoloop on top of the open-source
> [wacrm](https://github.com/ArnasDon/wacrm) template (MIT).

**Try it locally without a WhatsApp account:** see
[docs/demo-mode.md](./docs/demo-mode.md). It covers a local Supabase
stack, realistic sample data and a 5-minute demo script.

What OpsDeck adds on top of upstream wacrm:

- OpsDeck branding: name, logo, default blue theme, light mode by default.
- Demo mode (`NEXT_PUBLIC_DEMO_MODE`) plus `supabase/seed.sql` sample data.
- The pipeline "Won" stage keeps deal status in sync when deals are dragged
  (migration 060).
- Explicit Data API table grants, so the schema works on newer Supabase
  stacks (migration 061).
- An "Assigned to me" inbox filter.
- Next.js 16.4.4 (security update).

---

## Upstream: wacrm

[![License: MIT](https://img.shields.io/badge/License-MIT-violet.svg)](./LICENSE)
[![CI](https://github.com/ArnasDon/wacrm/actions/workflows/ci.yml/badge.svg)](https://github.com/ArnasDon/wacrm/actions/workflows/ci.yml)
[![Next.js 16](https://img.shields.io/badge/Next.js-16-black?logo=nextdotjs)](https://nextjs.org)
[![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20Auth-3ecf8e?logo=supabase)](https://supabase.com)
[![Stars](https://img.shields.io/github/stars/ArnasDon/wacrm?style=social)](https://github.com/ArnasDon/wacrm/stargazers)

The marketing site and self-host docs live in a separate repo:
[ArnasDon/wacrm-site](https://github.com/ArnasDon/wacrm-site)
([wacrm.tech](https://wacrm.tech)). This repo is the product —
clone or fork it to run your own CRM.

## What you get out of the box

- **Shared inbox** on the official WhatsApp Business API — multiple
  agents working one number, per-conversation assignment, status, and
  notes.
- **Contacts + tags + custom fields**, CSV import, deduplication.
- **Sales pipelines** (Kanban) with deals linked to conversations.
- **Broadcasts** with Meta-approved templates, delivery + read
  tracking, per-recipient variable substitution.
- **No-code automations** — triggers on inbound messages, new
  contacts, keywords, or schedule; conditional branches, waits,
  tags, webhooks. Visual builder.
- **AI reply assistant** — bring your own OpenAI or Anthropic key
  (stored encrypted; no per-seat AI fee, your data stays yours).
  One-click AI-drafted replies in the inbox, plus an optional
  auto-reply bot with a per-conversation cap and clean human handoff.
  Add a **knowledge base** (FAQs, policies, product docs) and it
  answers from your own content — hybrid retrieval (Postgres full-text,
  or semantic pgvector when an embeddings key is set).
- **Real-time dashboard** — response times, daily volume, pipeline
  value, cross-module activity feed.
- **Team accounts** — invite teammates by link, role-based access
  (owner / admin / agent / viewer), ownership transfer. Every install
  is account-scoped, so one shared inbox can be staffed by a whole
  team. Solo use stays single-user with zero setup.
- **Account management** — email, password, avatar, global sign-out.
- **Public REST API** (`/api/v1`) with scoped, revocable API keys —
  build your own automations on top of your CRM. See
  [docs/public-api.md](./docs/public-api.md).
- **MCP server** — drive your CRM from Claude, Cursor, and other AI
  assistants over the [Model Context Protocol](https://modelcontextprotocol.io).
  Read-only by default, opt-in writes. See [docs/mcp.md](./docs/mcp.md)
  (server in [`mcp-server/`](./mcp-server)).

## Why fork this?

This is a **template**, not a product. Forking means you get:

- **Full ownership** — your code, your Supabase project, your domain,
  your data. No SaaS lock-in, no seat pricing, no trust dance.
- **Full customisation** — add the fields your team needs, remove the
  modules you don't, redesign anything. The stack is boring on
  purpose (Next.js + Supabase + Tailwind) so the learning curve is
  short.
- **Zero ops to start** — any managed Node.js host (or the bundled
  Dockerfile) runs it. No Kubernetes, no infra team needed.
- **Real security primitives** — token encryption (AES-256-GCM), RLS
  on every table, HMAC-verified webhooks, CSP, rate limiting, CI
  typecheck/build on every PR.

Not a framework. Not an SDK. A concrete, working CRM you can stand up
in an afternoon and make yours.

## Quick start

```bash
# Fork on GitHub first: https://github.com/ArnasDon/wacrm → Fork
git clone https://github.com/<your-username>/wacrm.git
cd wacrm
npm install
cp .env.local.example .env.local   # fill in Supabase + Meta creds
npm run dev
```

Open <http://localhost:3000>. You'll be redirected to `/login` (or
`/dashboard` if already signed in).

The UI ships in English, Korean, Brazilian Portuguese and Spanish — set
`NEXT_PUBLIC_APP_LOCALE` to `en`, `ko`, `pt` or `es` in `.env.local`
(catalogues live in `messages/`).

Prefer containers? See [docs/docker.md](./docs/docker.md) for the
Dockerfile + Docker Compose setup.

## Documentation

Full self-host documentation — Supabase migrations, WhatsApp Business
API config, and production deploy — lives at
**[wacrm.tech/docs](https://wacrm.tech/docs)**
(source: [ArnasDon/wacrm-site](https://github.com/ArnasDon/wacrm-site)).

Key pages:
- [Getting started](https://wacrm.tech/docs/getting-started)
- [Supabase setup](https://wacrm.tech/docs/supabase-setup)
- [WhatsApp setup](https://wacrm.tech/docs/whatsapp-setup)
- [Environment variables](https://wacrm.tech/docs/environment-variables)
- [Architecture](https://wacrm.tech/docs/architecture)
- [Troubleshooting](https://wacrm.tech/docs/troubleshooting)
- [WhatsApp connection troubleshooting](./docs/whatsapp-connection-troubleshooting.md)
  — what each "Save Configuration" error means, and the Meta code /
  trace id to quote to Meta support
- [Several WABAs on one deployment](./docs/multi-waba.md) — one Meta
  App or several; how `META_APP_SECRET` takes a comma-separated list
- [Auth emails](./docs/auth-emails.md) — what Supabase must allow so
  confirmation and password-reset links come back to *your* domain
  instead of `localhost:3000`, and how `/auth/callback` handles them

## Stack

- **App** — Next.js 16 (App Router), React 19, TypeScript, Tailwind v4.
- **Data** — Supabase (Postgres + Auth + Storage + RLS).
- **WhatsApp** — Meta Cloud API (official WhatsApp Business API).

## Contributing

This is a template, not a collaborative product — the expected flow is
fork → customise → deploy, **not** upstream contribution. Bug reports
and security issues are welcome; feature PRs often belong in your fork
rather than here. Details in
[`CONTRIBUTING.md`](./CONTRIBUTING.md) and
[`.github/SECURITY.md`](./.github/SECURITY.md).

## License

[MIT](./LICENSE). OpsDeck is a derivative of
[wacrm](https://github.com/ArnasDon/wacrm), © 2026 Arnas Donauskas,
used under the MIT License. The original copyright and permission
notice are preserved in [`LICENSE`](./LICENSE).

WhatsApp is a trademark of its owner. OpsDeck is not affiliated with or
endorsed by it.
