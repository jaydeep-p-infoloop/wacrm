# Running the OpsDeck demo locally

Run OpsDeck end-to-end on your machine: a local Supabase stack, realistic
sample data, and **no Meta / WhatsApp account**.

## What you get

- **Team account "Harbor Digital"** (a fictional agency) with three users:

  | Email                 | Name        | Role  |
  | --------------------- | ----------- | ----- |
  | `demo@opsdeck.test`   | Alex Morgan | owner |
  | `priya@opsdeck.test`  | Priya Shah  | admin |
  | `jordan@opsdeck.test` | Jordan Lee  | agent |

  Password for all three: `OpsDeckDemo!2026`. It exists only in your local database.
- **18 contacts** with tags, custom fields and notes.
- **14 WhatsApp conversations**, 48 messages in total, in a mix of states: assigned, unassigned, unread, waiting for a reply, closed, and one failed send.
- **"Agency Sales" pipeline** with 14 deals in USD: 3 won and 1 lost.
- **4 message templates** and **4 quick replies**.
- **3 broadcasts**: two sent with delivery/read stats, one draft.

Every timestamp is relative to the moment you seed, so the dashboard always looks current.

## What demo mode does (`NEXT_PUBLIC_DEMO_MODE=true`)

- **Replies are simulated.** For an account with **no** WhatsApp config, inbox replies are saved as *sent* with a synthetic `demo-…` id instead of failing.
- **The UI says so.** The inbox shows a "Demo mode" notice and the dashboard chip reads "Demo mode · WhatsApp not connected".
- **Real connections are never faked.** An account that **has** a WhatsApp config still sends through Meta for real.
- **Not covered:** new broadcast sends, reactions, inbound messages and the AI features still need real credentials.

## Prerequisites

- Node.js ≥ 22.12
- Docker, running
- Supabase CLI. Running it through `npx` is fine; the commands below pin the version CI uses.

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Start local Supabase. This applies every migration in `supabase/migrations/` and then `supabase/seed.sql`:

   ```bash
   npx supabase@2.113.0 start
   ```

3. Print the local URL and keys (well-known local-only dev defaults):

   ```bash
   npx supabase@2.113.0 status -o env
   ```

4. Create `.env.local`. It is gitignored, so never commit it:

   ```bash
   NEXT_PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
   NEXT_PUBLIC_SUPABASE_ANON_KEY=<ANON_KEY from step 3>
   SUPABASE_SERVICE_ROLE_KEY=<SERVICE_ROLE_KEY from step 3>
   ENCRYPTION_KEY=<64 hex chars, see below>
   META_APP_SECRET=<any random string — no Meta app in demo mode>
   NEXT_PUBLIC_SITE_URL=http://localhost:3000
   NEXT_PUBLIC_DEMO_MODE=true
   WHATSAPP_TEMPLATES_DRY_RUN=true
   ```

   Generate the encryption key with:

   ```bash
   node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
   ```

5. Run the app:

   ```bash
   npm run dev
   ```

6. Open <http://localhost:3000> and sign in as `demo@opsdeck.test`.

> `NEXT_PUBLIC_*` values are inlined at build time. If you use
> `npm run build && npm start` instead of `npm run dev`, rebuild after
> changing them.

## Resetting the demo data

This wipes the **local** database, re-applies all migrations, and re-seeds:

```bash
npx supabase@2.113.0 db reset --local
```

The seed is idempotent: running `supabase/seed.sql` again on an already seeded database does nothing.

## A 5-minute demo script

1. **Dashboard.**
   - Point out the reply queue, waiting customers, and the failed-message card.
   - Show KPIs: median first reply, deals won, broadcast read rate.
2. **Inbox → "Assigned to me".**
   - Open *Marcus Chen* and reply.
   - Show the contact panel: tags, linked deal, notes.
3. **Inbox → "Unassigned".**
   - Assign *Raj Malhotra* to Jordan. Jordan gets a notification.
4. **Pipelines.**
   - Drag *Meridian Hotels* into **Won**. The deal is marked won and the analytics update.
5. **Contacts.**
   - Filter by the `VIP` tag and open a contact.
6. **Broadcasts.**
   - Open *March performance reports* to show delivery and read stats.
7. **Settings → Team members.**
   - Show roles and the invite link.

## Never against production

`supabase/seed.sql` creates users with a published password.

- `supabase db push` does **not** run it unless you pass `--include-seed`, so never pass that flag to a hosted project.
- Leave `NEXT_PUBLIC_DEMO_MODE` unset in production.
