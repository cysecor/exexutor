---
name: discovery-questions
description: How to run the two-round multiple-choice discovery questionnaire. Defines the 30 default round-1 questions across 6 categories, how to adapt them per project type, and how to generate the 15 round-2 follow-ups from gaps and contradictions.
---

# Discovery questions

The discovery phase produces shared understanding before any planning. Two
rounds:

- **Round 1**: 30 broad questions across 6 categories. Default set below; adapt to project type.
- **Round 2**: 15 follow-ups dynamically generated from round-1 answers.

Every question has exactly 4 lettered options. The user may also write a
custom answer for any question (`7: custom — ...`).

## Presentation format

Emit all questions of a round in **one message**. Use this structure:

```markdown
# Discovery — Round 1 of 2 (30 questions)

Reply with one line per question: `1: a`, `2: c`, etc.
For a question where none of the options fit, write your own: `7: custom — internal teams plus selected partners`.

---

## A. Users & Access

**1. Who are the primary users?**
- (a) Internal team only
- (b) External customers (B2C or B2B)
- (c) Public / anonymous OK
- (d) Mixed — some signed-in, some public

**2. Expected user count at v1?**
- (a) <10
- (b) 10–1,000
- (c) 1,000–100,000
- (d) >100,000

... and so on
```

Keep options short (≤8 words each) and mutually exclusive within a question.

## The default 30 round-1 questions (web-app baseline)

Adapt these per project type — see "Adapting" below.

### A. Users & Access (5)

1. **Primary users?** (a) internal team / (b) external customers / (c) public anonymous / (d) mixed
2. **User count at v1?** (a) <10 / (b) 10–1k / (c) 1k–100k / (d) >100k
3. **Auth method?** (a) email + password / (b) magic link / passwordless / (c) OAuth (Google/GitHub/etc) / (d) SSO / SAML (enterprise)
4. **Role model?** (a) single role / (b) 2–3 roles (user/admin) / (c) granular RBAC / (d) per-resource permissions
5. **Signup model?** (a) open self-signup / (b) invite-only / (c) admin-provisioned / (d) waitlist

### B. Data (5)

6. **Primary data store?** (a) Postgres / (b) MySQL / (c) SQLite / (d) NoSQL (Mongo/DynamoDB)
7. **Data volume at v1?** (a) <1 GB / (b) 1–100 GB / (c) 100 GB–1 TB / (d) >1 TB
8. **Real-time needs?** (a) none / (b) polling is fine / (c) WebSockets/SSE for some features / (d) real-time is core
9. **File/media storage?** (a) none / (b) small files (<10 MB) / (c) large files / video / (d) third-party (S3 / Cloudinary)
10. **Data retention / deletion?** (a) keep forever / (b) soft delete only / (c) hard delete after period / (d) per-user export + delete (GDPR-style)

### C. Interface (5)

11. **Primary interface?** (a) web app / (b) native mobile / (c) CLI / (d) API only
12. **Rendering strategy?** (a) SSR (Next/Remix) / (b) SPA (React/Vue) / (c) static + progressive / (d) classic server-rendered
13. **Design system?** (a) Tailwind + shadcn/ui / (b) MUI / Chakra / Mantine / (c) custom CSS / (d) I'll provide designs
14. **Responsive priority?** (a) desktop-first / (b) mobile-first / (c) both equal / (d) desktop only
15. **Accessibility target?** (a) WCAG AA / (b) basic only / (c) WCAG AAA / (d) not yet a priority

### D. Integrations (5)

16. **Payments?** (a) none / (b) Stripe / (c) other (Paddle/LemonSqueezy) / (d) crypto
17. **Email?** (a) none / (b) transactional only (Resend/Postmark/SES) / (c) marketing only (Mailchimp etc.) / (d) both
18. **AI/LLM features?** (a) none / (b) Anthropic / (c) OpenAI / (d) multi-provider via OpenRouter/LiteLLM
19. **Search?** (a) none / (b) DB full-text / (c) Elasticsearch/Meilisearch self-hosted / (d) Algolia/Typesense Cloud
20. **Analytics?** (a) none / (b) privacy-friendly (PostHog/Plausible) / (c) GA/Mixpanel / (d) custom

### E. Deployment & Ops (5)

21. **Hosting?** (a) Vercel/Netlify / (b) Railway/Render/Fly / (c) AWS/GCP/Azure / (d) self-hosted / on-prem
22. **CI/CD?** (a) GitHub Actions / (b) GitLab CI / (c) other / (d) none yet
23. **Environments?** (a) prod only / (b) prod + preview / (c) prod + staging + preview / (d) prod + staging + dev
24. **Monitoring/errors?** (a) Sentry / (b) Datadog/New Relic / (c) basic logging only / (d) none
25. **Backup/DR?** (a) provider-managed / (b) manual periodic / (c) automated cross-region / (d) not yet

### F. Quality & Constraints (5)

26. **Test coverage target?** (a) 90%+ / (b) 70–90% / (c) critical paths only / (d) end-to-end only
27. **Performance budget (p95)?** (a) <100 ms / (b) <500 ms / (c) <2 s / (d) not a priority yet
28. **Internationalization?** (a) English only / (b) plan for i18n later / (c) multi-lang from day one / (d) includes RTL languages
29. **Compliance?** (a) none / (b) GDPR / (c) HIPAA / (d) SOC2 / enterprise
30. **Documentation?** (a) code comments only / (b) README + API docs / (c) user docs + dev docs / (d) full docs site

## Adapting per project type

Use the description.md to detect the project type and swap entire categories or specific questions:

- **CLI tool** → Replace category C (Interface) questions with: TTY rendering (plain/colour/TUI), flags vs interactive, exit-code conventions, config file format, output format (JSON/human/both). Drop questions 14, 15.
- **API-only service** → Replace category C with: API shape (REST/GraphQL/RPC), versioning (URL/header/none), rate limiting (per-key/per-IP/none), pagination (cursor/offset), response format (JSON/Protobuf).
- **Mobile app** → Replace category E with: app stores (iOS only/Android only/both), distribution (App Store/TestFlight/sideload), update strategy, native vs cross-platform (React Native/Flutter/native).
- **Library / SDK** → Replace categories C and E with: target runtimes, package registry, semver policy, types/typings, sample code maintenance.

When you adapt, keep the 30-question total and the 6-category structure. Note any substitutions in a header comment at the top of round-1.md.

## Round 2 — generating the 15 follow-ups

After parsing round-1 answers, identify gaps using these heuristics:

1. **Real-time + heavy data + Postgres** → ask about Realtime implementation (logical replication, dedicated WS service, broker like Redis pub/sub, third-party like Ably/Pusher).
2. **Enterprise SSO + compliance** → ask which IdPs (Okta/Azure AD/Google Workspace/custom), SAML vs OIDC, SCIM provisioning needs.
3. **AI/LLM features** → ask about prompt management (in-code/PromptLayer/Helicone), evaluation framework, fallback model, latency tolerance, streaming UX.
4. **Payments + subscriptions** → ask about pricing model (flat/tiered/usage-based), trial mechanic, dunning, tax handling.
5. **Multi-tenant + B2B** → ask about org/tenant isolation (row-level/schema-per-tenant/DB-per-tenant), invitations, switching context, billing per tenant.
6. **Marketing email** → ask about list management, unsubscribe handling, segmentation, sender reputation strategy.
7. **HIPAA / GDPR / SOC2** → ask which specific controls are in scope, audit logging requirements, data residency.
8. **Large files / video** → ask about transcoding, CDN, signed URLs, max upload size.
9. **Custom auth combinations** → ask the disambiguator (e.g. "OAuth + invite-only" → can the OAuth-authenticated user join without an invite?).
10. **Ambiguous deploy + monitoring combos** → ask about alerting routes (Slack/PagerDuty/email-only), on-call expectation.

Compose exactly 15 follow-ups that maximize information gain. Each must have 4 lettered options.

### Round-2 format

Same single-message structure as round 1, but with a 1-line preamble at the top:

```markdown
# Discovery — Round 2 of 2 (15 follow-ups)

Based on your round-1 answers, these gaps need clarifying.

---
```

## What NOT to ask

- Implementation choices the planner should make (file structure, naming conventions). Those come from the plan, not from the user.
- Questions whose answer is fully determined by description.md.
- Questions where 3 of the 4 options would be obviously wrong for this project.
- Yes/no questions. Always 4 meaningful options.

## What round-1.md and round-2.md should look like on disk

```markdown
# Discovery Round 1

_Captured: <UTC>_  _Adaptations from defaults: <none | list>_

## A. Users & Access

**1. Who are the primary users?**
- (a) Internal team only
- (b) External customers (B2C or B2B)         ← chosen
- (c) Public / anonymous OK
- (d) Mixed — some signed-in, some public

**2. Expected user count at v1?**
- (a) <10
- (b) 10–1,000                                  ← chosen
- (c) 1,000–100,000
- (d) >100,000

...
```

Custom answers go below the four options as `← custom: <user text>`.
