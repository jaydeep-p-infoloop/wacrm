-- ============================================================
-- OpsDeck demo seed — LOCAL DEVELOPMENT / DEMOS ONLY
-- ============================================================
--
-- Applied automatically by the Supabase CLI on `supabase start`
-- (fresh volume) and `supabase db reset --local`. CI runs with
-- `--no-seed`, and `supabase db push` to a hosted project does NOT run
-- it unless you pass `--include-seed` — never do that against a real
-- project: it creates users with a published password.
--
-- Re-run by hand (idempotent — skips if the demo owner exists):
--   psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -f supabase/seed.sql
--
-- Demo logins (password for all three: OpsDeckDemo!2026)
--   demo@opsdeck.test    Alex Morgan   owner
--   priya@opsdeck.test   Priya Shah    admin
--   jordan@opsdeck.test  Jordan Lee    agent
--
-- Everything is fictional: phone numbers come from ranges reserved for
-- fiction/testing (US 555-01xx, UK 07700 900xxx, AU 0491 570xxx),
-- emails use the reserved `.example` / `.test` TLDs, and company names
-- are invented. Timestamps are relative to now() so the dashboard,
-- reply queue and 24h-window filters always look current.
--
-- No WhatsApp config is created: pair this with NEXT_PUBLIC_DEMO_MODE=true
-- so inbox replies are recorded locally instead of failing.
-- ============================================================

DO $seed$
DECLARE
  v_owner  uuid := 'a0000000-0000-4000-8000-000000000001';
  v_admin  uuid := 'a0000000-0000-4000-8000-000000000002';
  v_agent  uuid := 'a0000000-0000-4000-8000-000000000003';
  v_pw     text := extensions.crypt('OpsDeckDemo!2026', extensions.gen_salt('bf'));
  v_account uuid;
  v_pipeline uuid;
  v_bc_1 uuid;
  v_bc_2 uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = 'demo@opsdeck.test') THEN
    RAISE NOTICE 'OpsDeck demo seed already applied — skipping.';
    RETURN;
  END IF;

  -- ----------------------------------------------------------
  -- 1. Users. The on_auth_user_created trigger (017) creates a
  --    personal account + owner profile for each.
  -- ----------------------------------------------------------
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
  )
  SELECT '00000000-0000-0000-0000-000000000000', u.id, 'authenticated',
         'authenticated', u.email, v_pw, now() - interval '90 days',
         '{"provider":"email","providers":["email"]}'::jsonb,
         jsonb_build_object('full_name', u.full_name),
         now() - interval '90 days', now(), '', '', '', ''
  FROM (VALUES
    (v_owner, 'demo@opsdeck.test',   'Alex Morgan'),
    (v_admin, 'priya@opsdeck.test',  'Priya Shah'),
    (v_agent, 'jordan@opsdeck.test', 'Jordan Lee')
  ) AS u(id, email, full_name);

  INSERT INTO auth.identities (
    user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  )
  SELECT u.id, u.id::text,
         jsonb_build_object('sub', u.id::text, 'email', u.email,
                            'email_verified', true),
         'email', now(), now() - interval '90 days', now()
  FROM auth.users u
  WHERE u.id IN (v_owner, v_admin, v_agent);

  -- ----------------------------------------------------------
  -- 2. One shared team account, owned by Alex. Priya and Jordan
  --    are moved in (what redeeming an invite does) and their empty
  --    personal accounts are removed.
  -- ----------------------------------------------------------
  SELECT account_id INTO v_account FROM public.profiles WHERE user_id = v_owner;

  UPDATE public.accounts
  SET name = 'Harbor Digital', default_currency = 'USD', reply_target_minutes = 30
  WHERE id = v_account;

  CREATE TEMP TABLE _old_accounts ON COMMIT DROP AS
    SELECT account_id AS id FROM public.profiles WHERE user_id IN (v_admin, v_agent);

  UPDATE public.profiles SET account_id = v_account, account_role = 'admin'
  WHERE user_id = v_admin;
  UPDATE public.profiles SET account_id = v_account, account_role = 'agent'
  WHERE user_id = v_agent;

  DELETE FROM public.accounts WHERE id IN (SELECT id FROM _old_accounts);

  INSERT INTO public.member_presence (user_id, account_id, status, last_seen_at) VALUES
    (v_owner, v_account, 'online', now()),
    (v_admin, v_account, 'online', now() - interval '2 minutes'),
    (v_agent, v_account, 'away',   now() - interval '25 minutes');

  -- Assignment notifications (027 trigger) read the actor from
  -- auth.uid(); act as Alex for the rest of the seed.
  PERFORM set_config('request.jwt.claims',
                     json_build_object('sub', v_owner::text, 'role', 'authenticated')::text,
                     true);

  -- ----------------------------------------------------------
  -- 3. Tags + custom fields
  -- ----------------------------------------------------------
  CREATE TEMP TABLE _tag ON COMMIT DROP AS
  SELECT gen_random_uuid() AS id, t.name, t.color
  FROM (VALUES
    ('Lead',           '#3b82f6'),
    ('Client',         '#22c55e'),
    ('Retainer',       '#8b5cf6'),
    ('Website build',  '#f97316'),
    ('SEO',            '#14b8a6'),
    ('Paid media',     '#eab308'),
    ('VIP',            '#ec4899'),
    ('Urgent',         '#ef4444')
  ) AS t(name, color);

  INSERT INTO public.tags (id, user_id, account_id, name, color)
  SELECT id, v_owner, v_account, name, color FROM _tag;

  CREATE TEMP TABLE _field ON COMMIT DROP AS
  SELECT gen_random_uuid() AS id, f.name
  FROM (VALUES ('Monthly budget (USD)'), ('Lead source'), ('Website')) AS f(name);

  INSERT INTO public.custom_fields (id, user_id, account_id, field_name, field_type)
  SELECT id, v_owner, v_account, name, 'text' FROM _field;

  -- ----------------------------------------------------------
  -- 4. Contacts
  -- ----------------------------------------------------------
  CREATE TEMP TABLE _contact ON COMMIT DROP AS
  SELECT gen_random_uuid() AS id, c.*
  FROM (VALUES
    -- key        name                phone            email                          company                  days  tags                              budget    source            website
    ('sarah',   'Sarah Whitfield',  '+12125550101', 'sarah@brightpeakoutdoors.example', 'Brightpeak Outdoors',   62, ARRAY['Client','Retainer','SEO','VIP'], '$6,500',  'Referral',      'brightpeakoutdoors.example'),
    ('marcus',  'Marcus Chen',      '+14155550123', 'marcus@lumenfintech.example',      'Lumen Fintech',         41, ARRAY['Lead','Website build'],          '$40,000', 'LinkedIn',      'lumenfintech.example'),
    ('olivia',  'Olivia Grant',     '+447700900111','olivia@greywharf.example',         'Greywharf Studios',     35, ARRAY['Client','Paid media'],           '$12,000', 'Website form',  'greywharf.example'),
    ('daniel',  'Daniel Okafor',    '+447700900222','daniel@kitepath.example',          'Kitepath Logistics',    28, ARRAY['Lead','SEO'],                    '$3,000',  'Google Ads',    'kitepath.example'),
    ('emma',    'Emma Lindqvist',   '+61491570110', 'emma@saltandsage.example',         'Salt & Sage Kitchens',  55, ARRAY['Client','Retainer','Website build'], '$8,000', 'Referral',  'saltandsage.example'),
    ('raj',     'Raj Malhotra',     '+13125550144', 'raj@novaclinics.example',          'Nova Dental Clinics',   19, ARRAY['Lead','Paid media','Urgent'],    '$15,000', 'Webinar',       'novaclinics.example'),
    ('chloe',   'Chloé Martin',     '+447700900333','chloe@atelierfleur.example',       'Atelier Fleur',         47, ARRAY['Client','SEO'],                  '$2,500',  'Instagram',     'atelierfleur.example'),
    ('james',   'James Holloway',   '+16465550177', 'james@ironbarkfit.example',        'Ironbark Fitness',      12, ARRAY['Lead','Website build'],          '$22,000', 'Website form',  'ironbarkfit.example'),
    ('aisha',   'Aisha Rahman',     '+61491570220', 'aisha@tidewaterlegal.example',     'Tidewater Legal',       73, ARRAY['Client','Retainer','VIP'],       '$9,500',  'Referral',      'tidewaterlegal.example'),
    ('lucas',   'Lucas Ferreira',   '+13105550188', 'lucas@northstarsaas.example',      'Northstar SaaS',         6, ARRAY['Lead','Paid media'],             '$18,000', 'LinkedIn',      'northstarsaas.example'),
    ('hannah',  'Hannah Becker',    '+447700900444','hannah@copperleaf.example',        'Copperleaf Coffee',     30, ARRAY['Client','Paid media'],           '$4,000',  'Google Ads',    'copperleaf.example'),
    ('tom',     'Tom Ashby',        '+61491570330', 'tom@redgumbuild.example',          'Redgum Builders',        3, ARRAY['Lead'],                          '$5,000',  'Website form',  'redgumbuild.example'),
    ('nina',    'Nina Petrov',      '+12065550199', 'nina@polarisedu.example',          'Polaris Learning',      24, ARRAY['Lead','Website build','SEO'],    '$30,000', 'Conference',    'polarisedu.example'),
    ('ben',     'Ben Carter',       '+447700900555','ben@harrowmotors.example',         'Harrow Motors',         88, ARRAY['Client'],                        '$3,500',  'Referral',      'harrowmotors.example'),
    ('grace',   'Grace Kim',        '+12135550166', 'grace@bloomskincare.example',      'Bloom Skincare',        15, ARRAY['Lead','Paid media'],             '$10,000', 'Instagram',     'bloomskincare.example'),
    ('omar',    'Omar Haddad',      '+61491570440', 'omar@meridianhotels.example',      'Meridian Boutique Hotels', 9, ARRAY['Lead','Website build','VIP'],  '$48,000', 'Referral',      'meridianhotels.example'),
    ('sofia',   'Sofia Romano',     '+447700900666','sofia@vespacafe.example',          'Vespa Café Group',      51, ARRAY['Client','SEO'],                  '$2,800',  'Google Ads',    'vespacafe.example'),
    ('ethan',   'Ethan Brooks',     '+17185550155', 'ethan@cedarandpine.example',       'Cedar & Pine Realty',    2, ARRAY['Lead'],                          '$7,500',  'Website form',  'cedarandpine.example')
  ) AS c(key, name, phone, email, company, days, tags, budget, source, website);

  INSERT INTO public.contacts (id, user_id, account_id, name, phone, email, company, created_at, updated_at)
  SELECT id, v_owner, v_account, name, phone, email, company,
         now() - make_interval(days => days), now() - make_interval(days => days)
  FROM _contact;

  INSERT INTO public.contact_tags (contact_id, tag_id)
  SELECT c.id, t.id
  FROM _contact c CROSS JOIN LATERAL unnest(c.tags) AS tn(name)
  JOIN _tag t ON t.name = tn.name;

  INSERT INTO public.contact_custom_values (contact_id, custom_field_id, value)
  SELECT c.id, f.id,
         CASE f.name WHEN 'Monthly budget (USD)' THEN c.budget
                     WHEN 'Lead source' THEN c.source
                     ELSE c.website END
  FROM _contact c CROSS JOIN _field f;

  INSERT INTO public.contact_notes (contact_id, user_id, account_id, note_text, created_at)
  SELECT c.id, n.author, v_account, n.note, now() - make_interval(days => n.days)
  FROM (VALUES
    ('sarah',  v_owner, 'Renewed SEO retainer for another 12 months. Wants a quarterly strategy call — next one mid-month.', 20),
    ('sarah',  v_admin, 'Prefers WhatsApp over email for quick approvals. Decision maker on marketing spend.', 45),
    ('marcus', v_owner, 'Discovery call done. Needs marketing site + investor pages before Series A announcement. Tight timeline (6 weeks).', 5),
    ('olivia', v_agent, 'Running Meta + Google campaigns. CPA target $38. Monthly performance report due on the 3rd.', 12),
    ('raj',    v_owner, 'Opening 3 new clinics — wants local paid search per location. Budget approved by CFO, waiting on contract.', 2),
    ('emma',   v_admin, 'Website relaunch shipped. Next phase: online booking integration.', 18),
    ('omar',   v_owner, 'Group of 4 boutique hotels. Full rebrand + booking site. Competitive pitch against two other agencies.', 4),
    ('nina',   v_agent, 'Asked for case studies from education sector. Sent Brightpeak + Tidewater examples.', 7),
    ('aisha',  v_owner, 'Long-term client since last year. Always pays on time. Interested in adding LinkedIn ads.', 30)
  ) AS n(key, author, note, days)
  JOIN _contact c ON c.key = n.key;

  -- ----------------------------------------------------------
  -- 5. Conversations + messages
  --    mins = minutes before now(). Conversation metadata
  --    (last message, inbound/reply times) is derived below.
  -- ----------------------------------------------------------
  CREATE TEMP TABLE _conv ON COMMIT DROP AS
  SELECT gen_random_uuid() AS id, v.*
  FROM (VALUES
    -- contact   status     assignee  unread
    ('sarah',  'open',    v_owner,  0),
    ('marcus', 'open',    v_owner,  2),
    ('olivia', 'open',    v_agent,  0),
    ('daniel', 'pending', v_agent,  0),
    ('emma',   'closed',  v_admin,  0),
    ('raj',    'open',    NULL,     3),
    ('chloe',  'open',    v_agent,  1),
    ('james',  'open',    v_admin,  0),
    ('aisha',  'closed',  v_owner,  0),
    ('lucas',  'open',    NULL,     1),
    ('hannah', 'pending', v_agent,  0),
    ('tom',    'open',    NULL,     1),
    ('omar',   'open',    v_owner,  1),
    ('grace',  'open',    v_admin,  0)
  ) AS v(contact_key, status, assignee, unread);

  CREATE TEMP TABLE _msg (
    contact_key text, sender text, body text, mins int, status text,
    content_type text DEFAULT 'text', template_name text DEFAULT NULL,
    error_title text DEFAULT NULL
  ) ON COMMIT DROP;

  INSERT INTO _msg (contact_key, sender, body, mins, status) VALUES
    -- Sarah — happy retainer client, quick approval
    ('sarah', 'customer', 'Hi Alex! Just saw the March SEO report — organic traffic up 34%, amazing work 🙌', 1500, 'read'),
    ('sarah', 'agent',    'Thanks Sarah! The new category pages are doing the heavy lifting. Want me to walk you through it on a quick call?', 1490, 'read'),
    ('sarah', 'customer', 'Yes please. Also — can we add two more blog posts a month? Happy to increase the retainer.', 1480, 'read'),
    ('sarah', 'agent',    'Absolutely. I''ll send an updated proposal today: +2 posts/month, $1,200 added to the retainer.', 1470, 'read'),
    ('sarah', 'customer', 'Perfect, approved 👍', 95, 'read'),
    ('sarah', 'agent',    'Brilliant — I''ve updated the plan and the writers start Monday. Invoice will reflect it from next month.', 88, 'read'),

    -- Marcus — hot lead, waiting on a reply (unread)
    ('marcus', 'customer', 'Hey, we spoke on LinkedIn. We need a new marketing site before our Series A announcement.', 2900, 'read'),
    ('marcus', 'agent',    'Great to hear from you Marcus! What''s the target launch date, and do you have brand guidelines ready?', 2880, 'read'),
    ('marcus', 'customer', 'Launch in 6 weeks. Brand guide is done. We need ~8 pages plus an investor section.', 2860, 'read'),
    ('marcus', 'agent',    'That''s very doable. I''ll put a proposal together — expect it by Thursday.', 2850, 'read'),
    ('marcus', 'customer', 'Got the proposal, thanks. Two questions: can you do it in 5 weeks, and is CMS training included?', 22, 'delivered'),
    ('marcus', 'customer', 'Also our CFO wants to see a payment schedule.', 18, 'delivered'),

    -- Olivia — paid media client, campaign check-in
    ('olivia', 'customer', 'Morning! The new ad creatives look great. When do they go live?', 400, 'read'),
    ('olivia', 'agent',    'Morning Olivia! Scheduled for 9am tomorrow across Meta and Google. I''ll share first-day numbers by Friday.', 380, 'read'),
    ('olivia', 'customer', 'Perfect. Can we shift 20% of budget from Google to Meta? Meta CPA has been lower.', 120, 'read'),
    ('olivia', 'agent',    'Good call — Meta CPA is $31 vs $44 on Google. I''ll rebalance today and keep an eye on volume.', 110, 'read'),

    -- Daniel — pending, waiting on client
    ('daniel', 'customer', 'Hi, interested in SEO for our logistics company. What does your audit include?', 4400, 'read'),
    ('daniel', 'agent',    'Hi Daniel! Our audit covers technical health, content gaps, competitor keywords and a 90-day plan. It''s $750, credited if you sign a retainer.', 4380, 'read'),
    ('daniel', 'customer', 'Sounds good. Let me check with my director and get back to you.', 4300, 'read'),
    ('daniel', 'agent',    'No problem — I''ve attached a sample audit so he can see the format.', 4290, 'read'),

    -- Emma — closed, project delivered
    ('emma', 'customer', 'The new site is live and bookings are already coming in. Thank you all!', 7300, 'read'),
    ('emma', 'agent',    'So glad to hear it Emma! I''ll schedule a 30-day review to look at conversion data.', 7280, 'read'),
    ('emma', 'customer', 'Sounds great. Closing this thread — speak soon!', 7200, 'read'),

    -- Raj — unassigned urgent lead, outside 24h window risk
    ('raj', 'customer', 'Hello, we''re opening 3 new dental clinics next month and need local paid search for each location.', 1600, 'read'),
    ('raj', 'customer', 'Budget is about $15k/month across all three. Can someone call me?', 1590, 'read'),
    ('raj', 'customer', 'Following up — we need to start this week if possible.', 50, 'delivered'),

    -- Chloé — SEO client question
    ('chloe', 'customer', 'Bonjour! Quick one — should we add French-language pages for our Paris customers?', 300, 'read'),
    ('chloe', 'agent',    'Bonjour Chloé! Yes — hreflang tags + 5 core pages in French would be a strong start. I''ll scope it.', 280, 'read'),
    ('chloe', 'customer', 'Merci! Also can you send last month''s ranking report again? I can''t find the email.', 35, 'delivered'),

    -- James — website lead, proposal stage
    ('james', 'customer', 'Hi, we need a new site with class booking and memberships. Do you work with gyms?', 3000, 'read'),
    ('james', 'agent',    'Hi James! Yes — we''ve built booking sites for 4 fitness brands. Do you use Mindbody or another platform?', 2990, 'read'),
    ('james', 'customer', 'We''re on Mindbody. Need it integrated.', 2900, 'read'),
    ('james', 'agent',    'Perfect, we''ve integrated Mindbody before. Proposal coming tomorrow with timeline and a $22k fixed quote.', 240, 'read'),

    -- Aisha — closed, retainer renewed
    ('aisha', 'customer', 'Signed the renewal. Looking forward to the LinkedIn ads pilot!', 10100, 'read'),
    ('aisha', 'agent',    'Thank you Aisha! Kick-off call booked for Tuesday. 🎉', 10080, 'read'),

    -- Lucas — new inbound lead (unassigned)
    ('lucas', 'customer', 'Hi! Saw your case study on B2B SaaS paid acquisition. We''re spending $18k/mo on LinkedIn with poor results. Can you help?', 12, 'delivered'),

    -- Hannah — pending approval
    ('hannah', 'agent',    'Hi Hannah, the spring promo creatives are ready for review — 6 variants attached.', 900, 'read'),
    ('hannah', 'customer', 'Love variants 2 and 5. Waiting on our owner to sign off, should be tomorrow.', 860, 'read'),

    -- Tom — brand-new lead, unassigned
    ('tom', 'customer', 'G''day, looking for someone to build a site for our building company. Rough cost?', 6, 'delivered'),

    -- Omar — VIP pitch, failed send to show the failed-message flow
    ('omar', 'customer', 'Hi Alex, the board liked your rebrand pitch. Can you share the timeline for all 4 hotel sites?', 600, 'read'),
    ('omar', 'agent',    'Thanks Omar! Phased plan: brand system in 4 weeks, then 2 sites per month. Full deck coming shortly.', 590, 'read'),
    ('omar', 'customer', 'Great. We''ll decide by end of next week.', 40, 'delivered'),

    -- Grace — skincare lead
    ('grace', 'customer', 'Hi! We want to scale Instagram + TikTok ads for our new serum launch.', 1440, 'read'),
    ('grace', 'agent',    'Exciting launch Grace! What''s your monthly test budget and target CPA?', 1430, 'read'),
    ('grace', 'customer', 'Around $10k/month to start. CPA under $25 would be ideal.', 1400, 'read'),
    ('grace', 'agent',    'Very achievable for skincare. I''ll send a 90-day test plan by tomorrow.', 70, 'read');

  -- A message that "failed" to deliver, so the dashboard's failed-
  -- message card and the inbox failure state have something to show.
  INSERT INTO _msg (contact_key, sender, body, mins, status, error_title) VALUES
    ('omar', 'agent', 'Here''s the full rebrand deck and phased timeline 📎', 30, 'failed',
     'Message failed to send because more than 24 hours have passed since the customer last replied');

  -- A template message (sent via a broadcast-style follow up).
  INSERT INTO _msg (contact_key, sender, body, mins, status, content_type, template_name) VALUES
    ('daniel', 'agent', 'Hi Daniel, just following up on the SEO audit proposal we sent. Any questions? Reply here and we''ll get right back to you.', 1440, 'delivered', 'template', 'proposal_follow_up');

  INSERT INTO public.conversations (
    id, user_id, account_id, contact_id, status, assigned_agent_id, unread_count, created_at
  )
  SELECT cv.id, v_owner, v_account, c.id, cv.status, cv.assignee, cv.unread,
         now() - make_interval(mins => (SELECT max(m.mins) FROM _msg m WHERE m.contact_key = cv.contact_key) + 5)
  FROM _conv cv JOIN _contact c ON c.key = cv.contact_key;

  INSERT INTO public.messages (
    conversation_id, sender_type, sender_id, content_type, content_text,
    template_name, message_id, status, error_title, created_at
  )
  SELECT cv.id, m.sender,
         CASE WHEN m.sender = 'agent'
              THEN COALESCE(cv.assignee, v_owner) END,
         m.content_type, m.body, m.template_name,
         'demo-' || gen_random_uuid(),
         m.status, m.error_title,
         now() - make_interval(mins => m.mins)
  FROM _msg m JOIN _conv cv ON cv.contact_key = m.contact_key
  ORDER BY m.mins DESC;

  -- Derived conversation metadata (what the webhook/send path keeps up
  -- to date at runtime).
  UPDATE public.conversations cv
  SET last_message_text = lm.content_text,
      last_message_at   = lm.created_at,
      first_inbound_at  = (SELECT min(m.created_at) FROM public.messages m
                           WHERE m.conversation_id = cv.id AND m.sender_type = 'customer'),
      updated_at        = lm.created_at
  FROM (
    SELECT DISTINCT ON (conversation_id) conversation_id, content_text, created_at
    FROM public.messages
    ORDER BY conversation_id, created_at DESC
  ) lm
  WHERE lm.conversation_id = cv.id
    AND cv.account_id = v_account;

  UPDATE public.conversations
  SET closed_at = last_message_at
  WHERE account_id = v_account AND status = 'closed';

  -- ----------------------------------------------------------
  -- 6. Sales pipeline + deals (USD)
  -- ----------------------------------------------------------
  INSERT INTO public.pipelines (user_id, account_id, name, created_at)
  VALUES (v_owner, v_account, 'Agency Sales', now() - interval '90 days')
  RETURNING id INTO v_pipeline;

  CREATE TEMP TABLE _stage ON COMMIT DROP AS
  SELECT gen_random_uuid() AS id, s.*
  FROM (VALUES
    ('New Lead',      '#3b82f6', 0, NULL),
    ('Qualified',     '#eab308', 1, NULL),
    ('Proposal Sent', '#f97316', 2, NULL),
    ('Negotiation',   '#8b5cf6', 3, NULL),
    ('Won',           '#22c55e', 4, 'won')
  ) AS s(name, color, position, outcome);

  INSERT INTO public.pipeline_stages (id, pipeline_id, name, color, position, outcome)
  SELECT id, v_pipeline, name, color, position, outcome FROM _stage;

  INSERT INTO public.deals (
    user_id, account_id, pipeline_id, stage_id, contact_id, conversation_id,
    title, value, currency, status, expected_close_date, assigned_to, notes,
    created_at, closed_at
  )
  SELECT v_owner, v_account, v_pipeline, st.id, c.id, cv.id,
         d.title, d.value, 'USD', d.status,
         (now() + make_interval(days => d.close_in))::date,
         -- deals.assigned_to references profiles.id (not auth user id).
         (SELECT p.id FROM public.profiles p WHERE p.user_id = d.owner), d.notes,
         now() - make_interval(days => d.age),
         CASE WHEN d.status IN ('won','lost')
              THEN now() - make_interval(days => d.closed_ago) END
  FROM (VALUES
    -- contact   stage            title                                   value   status  close_in age closed_ago owner    notes
    ('tom',    'New Lead',      'Redgum Builders — website',              5000,  'open',  30, 0,  0, NULL::uuid, 'Inbound via WhatsApp. Needs a quote.'),
    ('lucas',  'New Lead',      'Northstar SaaS — LinkedIn ads rescue',  18000,  'open',  21, 0,  0, NULL,       'Spending $18k/mo on LinkedIn with poor CPL.'),
    ('ethan',  'New Lead',      'Cedar & Pine — local SEO',               7500,  'open',  45, 2,  0, v_agent,    NULL),
    ('raj',    'Qualified',     'Nova Dental — 3-clinic paid search',    45000,  'open',  14, 1,  0, v_owner,    '$15k/mo × 3 months initial term.'),
    ('grace',  'Qualified',     'Bloom Skincare — serum launch ads',     30000,  'open',  20, 1,  0, v_admin,    '90-day test plan, $10k/mo.'),
    ('nina',   'Qualified',     'Polaris Learning — site + SEO',         30000,  'open',  40, 7,  0, v_agent,    'Wants education case studies.'),
    ('marcus', 'Proposal Sent', 'Lumen Fintech — Series A marketing site',40000, 'open',  10, 2,  0, v_owner,    'Asked for 5-week timeline and payment schedule.'),
    ('james',  'Proposal Sent', 'Ironbark Fitness — booking website',    22000,  'open',  18, 2,  0, v_admin,    'Mindbody integration required.'),
    ('omar',   'Negotiation',   'Meridian Hotels — rebrand + 4 sites',   48000,  'open',   9, 4,  0, v_owner,    'Competitive pitch. Board decision end of next week.'),
    ('daniel', 'Negotiation',   'Kitepath Logistics — SEO retainer',      9000,  'open',  12, 3,  0, v_agent,    '$750 audit credited against retainer.'),
    ('sarah',  'Won',           'Brightpeak — SEO retainer expansion',   14400,  'won',    0, 20, 1, v_owner,    '+2 posts/month, $1,200/mo uplift × 12.'),
    ('aisha',  'Won',           'Tidewater Legal — retainer renewal',    28500,  'won',    0, 30, 7, v_owner,    '12-month renewal + LinkedIn pilot.'),
    ('emma',   'Won',           'Salt & Sage — booking integration',     12000,  'won',    0, 18, 5, v_admin,    'Phase 2 after relaunch.'),
    ('ben',    'Negotiation',   'Harrow Motors — paid search',            6000,  'lost',   0, 25, 3, v_agent,    'Went with an in-house hire.')
  ) AS d(contact_key, stage_name, title, value, status, close_in, age, closed_ago, owner, notes)
  JOIN _contact c ON c.key = d.contact_key
  JOIN _stage st ON st.name = d.stage_name
  LEFT JOIN _conv cv ON cv.contact_key = d.contact_key;

  -- ----------------------------------------------------------
  -- 7. Message templates (marked APPROVED with demo ids — never
  --    submitted to Meta) + quick replies
  -- ----------------------------------------------------------
  INSERT INTO public.message_templates (
    user_id, account_id, name, category, language, body_text, footer_text,
    status, meta_template_id, quality_score, created_at
  ) VALUES
    (v_owner, v_account, 'proposal_follow_up', 'Marketing', 'en_US',
     'Hi {{1}}, just following up on the {{2}} proposal we sent. Any questions? Reply here and we''ll get right back to you.',
     'Harbor Digital', 'APPROVED', 'demo-tpl-proposal-follow-up', 'GREEN', now() - interval '60 days'),
    (v_owner, v_account, 'monthly_report_ready', 'Utility', 'en_US',
     'Hi {{1}}, your {{2}} performance report is ready. Highlights: {{3}}. Reply REPORT for the full PDF.',
     'Harbor Digital', 'APPROVED', 'demo-tpl-monthly-report', 'GREEN', now() - interval '60 days'),
    (v_owner, v_account, 'discovery_call_reminder', 'Utility', 'en_US',
     'Hi {{1}}, a reminder of our discovery call on {{2}}. Reply 1 to confirm or 2 to reschedule.',
     NULL, 'APPROVED', 'demo-tpl-discovery-reminder', 'GREEN', now() - interval '45 days'),
    (v_owner, v_account, 'spring_offer_2026', 'Marketing', 'en_US',
     'Hi {{1}}! This spring we''re offering a free paid-media audit for existing clients. Want us to book yours?',
     'Reply STOP to opt out', 'PENDING', NULL, NULL, now() - interval '1 day');

  INSERT INTO public.quick_replies (account_id, user_id, title, kind, content_text) VALUES
    (v_account, v_owner, 'Thanks — on it',       'text', 'Thanks for the message! I''m on it and will update you within the hour.'),
    (v_account, v_owner, 'Book a call',          'text', 'Happy to talk it through — pick a time that suits you here: https://cal.example/harbor-digital'),
    (v_account, v_owner, 'Proposal timeline',    'text', 'You''ll have a detailed proposal with timeline and fixed pricing within 2 business days.'),
    (v_account, v_owner, 'Report request',       'text', 'Of course — I''ll resend this month''s performance report to your inbox right away.');

  -- ----------------------------------------------------------
  -- 8. Broadcast campaigns with delivery stats. Counts are
  --    maintained by the broadcast_recipients aggregate trigger.
  -- ----------------------------------------------------------
  INSERT INTO public.broadcasts (
    user_id, account_id, name, template_name, template_language, status,
    audience_filter, created_at, updated_at
  ) VALUES (
    v_owner, v_account, 'March performance reports', 'monthly_report_ready', 'en_US', 'sent',
    '{"type":"tags","tags":["Client"]}'::jsonb, now() - interval '9 days', now() - interval '9 days'
  ) RETURNING id INTO v_bc_1;

  INSERT INTO public.broadcasts (
    user_id, account_id, name, template_name, template_language, status,
    audience_filter, created_at, updated_at
  ) VALUES (
    v_owner, v_account, 'Proposal follow-ups — open leads', 'proposal_follow_up', 'en_US', 'sent',
    '{"type":"tags","tags":["Lead"]}'::jsonb, now() - interval '3 days', now() - interval '3 days'
  ) RETURNING id INTO v_bc_2;

  INSERT INTO public.broadcasts (
    user_id, account_id, name, template_name, template_language, status, created_at, updated_at
  ) VALUES (
    v_owner, v_account, 'Spring paid-media audit offer', 'spring_offer_2026', 'en_US', 'draft',
    now() - interval '1 day', now() - interval '1 day'
  );

  INSERT INTO public.broadcast_recipients (
    broadcast_id, contact_id, status, whatsapp_message_id,
    sent_at, delivered_at, read_at, replied_at, error_message, created_at
  )
  SELECT b.id, c.id, r.status, 'demo-' || gen_random_uuid(),
         CASE WHEN r.status <> 'failed' THEN b.created_at + interval '1 minute' END,
         CASE WHEN r.status IN ('delivered','read','replied') THEN b.created_at + interval '2 minutes' END,
         CASE WHEN r.status IN ('read','replied') THEN b.created_at + interval '40 minutes' END,
         CASE WHEN r.status = 'replied' THEN b.created_at + interval '2 hours' END,
         CASE WHEN r.status = 'failed' THEN 'Recipient phone number not on WhatsApp' END,
         b.created_at
  FROM (VALUES
    (1, 'sarah', 'replied'), (1, 'olivia', 'read'),    (1, 'emma',  'read'),
    (1, 'chloe', 'replied'), (1, 'aisha',  'read'),    (1, 'hannah','delivered'),
    (1, 'ben',   'read'),    (1, 'sofia',  'failed'),
    (2, 'marcus','replied'), (2, 'daniel', 'read'),    (2, 'raj',   'replied'),
    (2, 'james', 'read'),    (2, 'nina',   'delivered'),(2, 'grace', 'read'),
    (2, 'omar',  'replied'), (2, 'lucas',  'delivered'),(2, 'tom',   'sent'),
    (2, 'ethan', 'failed')
  ) AS r(bc, contact_key, status)
  JOIN _contact c ON c.key = r.contact_key
  JOIN public.broadcasts b ON b.id = CASE r.bc WHEN 1 THEN v_bc_1 ELSE v_bc_2 END;

  UPDATE public.broadcasts b
  SET total_recipients = (SELECT count(*) FROM public.broadcast_recipients r WHERE r.broadcast_id = b.id)
  WHERE b.id IN (v_bc_1, v_bc_2);

  PERFORM set_config('request.jwt.claims', '', true);

  RAISE NOTICE 'OpsDeck demo seed applied: account % (Harbor Digital).', v_account;
END
$seed$;
