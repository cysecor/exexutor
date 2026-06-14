---
name: validation-contracts
description: Format and quality rules for the validation contract — the flat, numbered, falsifiable assertion list every feature must satisfy. Activate when planning a mission or when validating one.
---

# Validation contracts

The validation contract is a flat, numbered list of assertions about the
system's behaviour. It is the source of truth for "is the mission done." It
is written **before** any code and is **immutable** once approved.

## Assertion format

Each assertion is one line:

```
AS-NNN: <single observable behaviour, present tense, no implementation detail>
```

Good examples:

- `AS-014: A user can send a message to a channel they have joined.`
- `AS-015: A user cannot send a message to a channel they have not joined; the API returns 403.`
- `AS-032: The unread count for a channel resets to 0 when the user opens that channel.`
- `AS-067: A new user's email is verified before they can send messages; unverified users see a banner prompting verification.`

Reject and rewrite examples:

- `AS-014: Auth works correctly.` — not falsifiable
- `AS-015: The MessageService class has a sendMessage method.` — implementation, not behaviour
- `AS-032: Users will be happy with the unread count.` — not observable
- `AS-067: The system should be secure.` — too broad to assign or verify

## Quality rules

1. **Testable in one sentence.** If you can't imagine the test, the assertion is too vague.
2. **Behaviour, not structure.** Never mention class names, function names, or file paths.
3. **Independently failable.** Each assertion can fail on its own without taking three others down with it.
4. **Negative cases explicit.** For every positive assertion, ask: what's the matching negative? `users CAN do X` deserves a sibling `users CANNOT do Y`.
5. **No compound assertions.** Split anything containing "and" into separate IDs.

## Coverage

Every assertion in the contract is assigned to at least one feature in
`plan.md`. The union of feature assignments equals the full contract. A
mission is **done** only when every assertion is GREEN across both the
scrutiny validator and (where behavioural) the UX validator.

## Updates after approval

Once `missions/<id>/APPROVED` exists, the contract is locked. Real life will
surface gaps anyway. When that happens:

- **NEVER** modify or delete an existing assertion ID.
- **MAY** append new assertion IDs with new numbers (skip gaps freely — never renumber).
- **MUST** create new features to cover the new assertions and add them to `plan.md` in the appropriate milestone.

This rule exists because a worker or validator may be referencing an old
assertion ID in a half-written test or report. Renumbering breaks them
silently.
