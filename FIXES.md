# Fixes log

Running record of bugs found and fixed in this repo, with the evidence behind
each one. Newest session first.

---

## 2026-08-12 (later) — approval rejected with 400 on OCR decimal places

Found by running the fixed build on a real device. With the error now visible
(see bug 7 below), approving a real invoice showed:

```
items.0.unitPrice must be a number conforming to the specified constraints
items.0.lineTotal must be a number conforming to the specified constraints
```

### Bug 11 — OCR precision exceeds the API's money precision

`InvoiceItemDto` caps money at `@IsNumber({ maxDecimalPlaces: 2 })` and
quantity at 3. Gemini returned `unitPrice: 77.451` for an Olper's line item,
the review form displayed and posted it verbatim, and the API rejected it.
The form had no notion of the API's precision at all — its validators only
checked "is a non-negative number".

Note this is a **client-side fix**: 2 decimal places is the right precision for
PKR ledger amounts, so the API contract was left alone rather than widened.
If 3-decimal unit prices turn out to be genuinely needed for per-unit pricing,
that is a deliberate schema decision to make on the API side, not something to
paper over in the app.

**Fixed in `invoice_review_page.dart`:**

- Added `_moneyDecimals = 2` / `_quantityDecimals = 3` mirroring the DTO, with
  a comment pointing at the source of truth.
- `_formatNumber(value, decimals)` rounds and trims trailing zeros
  (`77.451` → `77.45`, `28.0` → `28`). Item fields and the invoice total are
  **seeded through it**, so the shopkeeper reviews exactly what will be posted
  — no silent rounding at submit time behind their back.
- `_parseMoney` / `_parseQuantity` enforce sign *and* precision, and are used
  by both the field validators and `_approve`, so the two can't drift.
- Field-level errors say `Max 2 dp`; the summary box says which item to round
  and to what precision, instead of the API's opaque "conforming to the
  specified constraints".
- The invoice total gained its own error entry in the summary list — it
  previously failed with only an inline field error.

---

## 2026-08-12 — "Approve invoice & create receivable" did nothing

Reported symptom: on the invoice review screen, tapping **Approve invoice &
create receivable** appeared to do nothing.

Actual behaviour: the request *was* sent. `POST /v1/invoices/approve` returned
**500**, and the app rendered Nest's generic `"Internal server error"` in a red
box mid-`ListView` — easy to scroll past, and useless if you did see it.

Branch: `feat-foundational_architecture_mobile+backend` (base commit `f1edc73`).

### Summary

| # | Bug | Severity | Where |
|---|-----|----------|-------|
| 1 | Firestore rejects `undefined` from omitted optional DTO fields | Blocker | `receivables.service.ts` |
| 2 | Firestore rejects DTO class instances (`InvoiceItemDto` prototype) | Blocker | `receivables.service.ts` |
| 3 | Same `undefined` bug in contact creation | Blocker | `contacts.service.ts` |
| 4 | Same `undefined` bug in catalog product creation | High | `catalog.service.ts` |
| 5 | API cannot start under pnpm — `express` is a phantom dependency | Blocker | `apps/api/package.json` |
| 6 | Validation failure could clear the error box and show nothing | High | `invoice_review_page.dart` |
| 7 | 5xx surfaced as a bare "Internal server error", easy to miss | Medium | `invoice_review_page.dart` |
| 8 | No way to create a customer anywhere in the app | Blocker | mobile (missing feature) |
| 9 | "Search customers" field was decorative | Low | `receivables_page.dart` |
| 10 | `pnpm api:lint` failed on pre-existing errors | Low | `users.service.spec.ts` |

Bugs 1–4 share one root cause; 5 is independent; 6–7 are why the failure was
invisible; 8 blocks the flow even with 1–7 fixed.

---

### Root cause for bugs 1–4

`ValidationPipe({ transform: true })` in `apps/api/src/main.ts` hands each
service a **class instance**, not a plain object. Services then wrote that
instance straight to Firestore with a spread:

```ts
transaction.set(invoiceRef, { ...dto, status: 'approved', ... });
```

Firestore's serializer rejects that for two independent reasons.

**Bug 1 — `undefined` optional fields.** `apps/api/tsconfig.json` targets
`ES2023`, which turns on `useDefineForClassFields` by default. Every declared
field on a DTO becomes a real own property, so `invoiceNumber` and `dueDate`
exist with value `undefined` even when the client never sent them — and
`invoice_api.dart` deliberately omits them when blank. A top-level spread
copies those `undefined` values into the document.

**Bug 2 — custom prototypes.** `@Type(() => InvoiceItemDto)` makes every entry
in `dto.items` an `InvoiceItemDto` instance. `{ ...dto }` flattens only the top
level, so the items stay class instances. **This fires on every approval**, so
fixing bug 1 alone would not have helped.

#### Evidence

Ran the real `@google-cloud/firestore` validator (synchronous, pre-network, so
no credentials needed) against the exact payload the app sends:

```
own keys on dto      : [extractionId, contactId, invoiceNumber, invoiceDate, dueDate, total, items]
dto.dueDate present? : true -> undefined
items[0] constructor : InvoiceItemDto

[A: optional fields omitted (what the app sends)] REJECTED
  Cannot use "undefined" as a Firestore value (found in field "invoiceNumber").
  If you want to ignore undefined values, enable `ignoreUndefinedProperties`.

[B: every optional field filled in]               REJECTED
  Couldn't serialize object of type "InvoiceItemDto" (found in field "items.`0`").
  Firestore doesn't support JavaScript objects with custom prototypes.

[C: same data, plain objects]                     accepted
```

#### Fixes

**`apps/api/src/receivables/receivables.service.ts` — `approveInvoice()`**
Replaced the `{ ...dto }` spread with an explicit field-by-field mapping,
including `dto.items.map(...)` to flatten each item into a plain object.
`invoiceNumber` and `dueDate` are normalised to `null`. This also satisfies the
project rule in `docs/development.md` that financial writes be explicit.

**`apps/api/src/contacts/contacts.service.ts` — `create()` (bug 3)**
Same pattern, same failure: an omitted `email` was written as `undefined`, so
**creating a contact returned 500 too**. Now maps `name`, `phone`,
`email ?? null`, `whatsappOptIn` explicitly, and trims the strings.

**`apps/api/src/catalog/catalog.service.ts` — `create()` (bug 4)**
Same pattern for the optional `urduName` and `sku`.

**`apps/api/src/common/firebase/firebase-admin.service.ts` — safety net**
The `firestore` getter now caches the client and calls
`db.settings({ ignoreUndefinedProperties: true })` exactly once, before any
request. This is defence in depth behind the explicit mappings — it catches a
future `undefined` but does **not** help with custom prototypes, so it is not a
substitute for mapping fields explicitly.

---

### Bug 5 — the API could not start under pnpm

`apps/api/src/main.ts` does `import { json } from 'express'`, but `express` was
never declared in `apps/api/package.json` — only `@nestjs/platform-express`
was. npm's hoisted layout hides this; pnpm's strict layout does not:

```
Error: Cannot find module 'express'
  at Object.<anonymous> (apps/api/dist/main.js:5:19)
```

So the documented setup in `docs/development.md` (`pnpm install` → `pnpm
api:dev`) failed immediately on a clean clone.

**Fix:** `pnpm --dir apps/api add express@^5.2.1` — declares the version
already present transitively (5.2.1, matching the existing `@types/express`
^5.0.0 devDependency). Updates `apps/api/package.json` and `pnpm-lock.yaml`.

**Verified:** the API now boots and maps every route, including
`Mapped {/v1/invoices/approve, POST}`. An unauthenticated POST to that route
returns **401** from the Firebase guard, confirming the route resolves.

---

### Bugs 6–7 — why the failure was invisible

**Bug 6 — silent validation.** In `_approve()`:

```dart
if (!formValid || errors.isNotEmpty) {
  setState(() => _validationErrors = errors);   // errors may be empty!
  return;
}
```

A failing field validator that adds no entry to `errors` (an empty invoice
total, for example) **cleared** the error box and showed nothing new — the
button genuinely looked dead. Now falls back to
`'Fix the highlighted fields before approving.'` whenever the form is invalid
but no specific message was collected.

**Bug 7 — unhelpful server errors.** `_handleApprovalError` preferred
`data['message']`, which for any 5xx is Nest's constant `"Internal server
error"`. Now any status ≥ 500 gets a message that says the invoice was not
saved, that the edits are still on screen, and where to look. Every submission
failure is also mirrored into a red `SnackBar` via the new
`_showApprovalError`, because the summary box sits mid-list with no auto-scroll.

---

### Bug 8 — no way to create a customer

The API exposes `POST /v1/contacts`, but **nothing in the mobile app called
it**. `ContactsApi` only had `listContacts()`, there was no add-customer route
or screen, and the receivables list had no empty state. With zero contacts the
review screen's customer dropdown renders with no items, so an invoice can
never be approved — the core journey (photo → confirm shop → receivable)
dead-ends.

This was a missing feature rather than a broken line of code, but the flow
cannot work without it, so it is included here.

**Added:**

- `ContactsApi.createContact({ name, phone, email, whatsappOptIn })` —
  `POST /contacts`, omits a blank email so the API's `@IsOptional()` applies,
  returns the new id.
- `apps/mobile/lib/features/receivables/presentation/add_customer_page.dart` —
  new screen. Validates the phone against `^\+[1-9]\d{7,14}$`, mirroring the
  API's `CreateContactDto` rule, so a bad number is caught before the round
  trip. Prefills `+92`. Invalidates `receivablesProvider` on success.
- Route `/customers/new` in `app_router.dart`.
- `receivables_page.dart`: "Add customer" action in the header, plus an empty
  state that explains you need a customer before approving an invoice.
- `invoice_review_page.dart`: when the contact list comes back empty, the dead
  dropdown is replaced by an explanation and an **Add customer** button. If OCR
  read a shop name, the button offers to add that name.

---

### Bug 9 — dead search field

The "Search customers" `TextField` on the receivables page was a `const`
widget with no controller and no handler. Now filters the list by name or
phone, with a clear button and a "no match" message. The page became a
`ConsumerStatefulWidget` to hold the query.

The error state on that page also gained a **Retry** button and a readable
heading instead of a bare `error.toString()`.

---

### Bug 10 — lint gate was already red

`pnpm api:lint` failed with 6 `no-unsafe-member-access` errors in
`users.service.spec.ts`, all pre-existing and unrelated to the approval bug —
untyped `jest.fn()` mocks make `set.mock.calls[0][0]` an `any`. Fixed by giving
the mocks explicit signatures (`jest.fn<Promise<void>, [WrittenProfile]>()`)
so the lint gate is green and can catch real problems.

---

### Regression test

`apps/api/src/receivables/receivables.service.spec.ts` gained
**"writes a Firestore-safe invoice document when optional fields are omitted"**.

It builds the DTO with `plainToInstance` exactly as `ValidationPipe` does (so
the class prototypes are real), runs `approveInvoice` against a mocked
transaction, and asserts the captured documents recursively contain no
`undefined` and no object with a custom prototype — the two things the
Firestore serializer rejects. `FieldValue` sentinels and `Date` are allowed.

Confirmed the test is meaningful: with the service change stashed it fails,
with the fix applied it passes.

```
Tests: 1 failed, 2 passed   (service fix stashed)
Tests: 11 passed, 11 total  (fix applied)
```

---

### Verification performed

| Check | Result |
|-------|--------|
| `pnpm api:build` | passes |
| `pnpm api:lint` | clean (was 6 errors) |
| ↳ note | the script runs `eslint --fix`, so it will also reformat several untouched files to Prettier style on its next run; that reformatting was reverted here to keep this diff focused |
| `pnpm api:test` | 4 suites, 11 tests passing (was 10) |
| New regression test against unfixed service | fails as intended |
| API boot + route table | starts, all routes mapped |
| `POST /v1/invoices/approve` without a token | 401 from the Firebase guard |
| `flutter analyze` | No issues found |
| `flutter test` | 7 tests passing |

**Not verified end to end:** a real approval against live Firestore, which
needs real `FIREBASE_*`, `B2_*` and `GEMINI_API_KEY` credentials in
`apps/api/.env`. The payload shape is proven correct against the real Firestore
serializer (case C above) and locked in by the regression test.

---

### Files changed

```
apps/api/package.json                                              (+express)
apps/api/src/receivables/receivables.service.ts                    bugs 1, 2
apps/api/src/contacts/contacts.service.ts                          bug 3
apps/api/src/catalog/catalog.service.ts                            bug 4
apps/api/src/common/firebase/firebase-admin.service.ts             safety net
apps/api/src/receivables/receivables.service.spec.ts               regression test
apps/api/src/users/users.service.spec.ts                           bug 10
pnpm-lock.yaml                                                     (+express)

apps/mobile/lib/features/invoices/presentation/invoice_review_page.dart   bugs 6, 7, 8
apps/mobile/lib/features/receivables/data/contacts_api.dart              bug 8
apps/mobile/lib/features/receivables/presentation/add_customer_page.dart bug 8 (new)
apps/mobile/lib/core/routing/app_router.dart                             bug 8
apps/mobile/lib/features/receivables/presentation/receivables_page.dart  bugs 8, 9
```

---

### Environment setup done alongside (no code impact)

- Installed `pnpm@11.11.0` globally — Node 25 no longer bundles corepack.
- `pnpm install` for the API workspace.
- Copied `.env.example` → `apps/api/.env`. **Still placeholder values** —
  Firebase Admin, Backblaze B2 and Gemini credentials must be filled in.
- Upgraded Flutter 3.41.9 → 3.44.9; the app requires Dart `^3.12.0`, which
  3.41.9 did not provide.
- Generated `apps/mobile/android/app/google-services.json` from the values
  already committed in `lib/firebase_options.dart`. The file is gitignored so
  it is absent on a fresh clone, but `android/app/build.gradle.kts` applies the
  `com.google.gms.google-services` plugin, which fails the Android build
  without it.

### Still outstanding (not code bugs)

- **Windows Developer Mode** must be enabled (`start ms-settings:developers`)
  before `flutter run` — building with plugins needs symlink support.
- A physical device cannot reach `localhost`. Run with
  `flutter run --dart-define=API_BASE_URL=http://<your-lan-ip>:3000/v1` and
  allow inbound port 3000 through Windows Firewall.
- `apps/api/.env` still holds placeholders; invoice OCR needs a real
  `GEMINI_API_KEY`, and uploads need real `B2_*` values.
