# Backend MVP API

All routes except `GET /v1/health` require a Firebase ID token. The token UID is
the tenant/business boundary; no client-supplied business ID is trusted.

## Identity and tenancy

For the MVP, the Firebase UID has three related roles:

- It is the authenticated **user ID** supplied by Firebase Authentication.
- It is also the **tenant/business ID** used for the
  `businesses/{uid}/...` Firestore boundary.
- It is the **actor ID** recorded on financial writes and audit events.

This means one Firebase user currently represents one isolated business tenant.
Shared businesses, employees, roles, and membership records are not implemented.
When those are added, the tenant/business ID must come from verified membership
data rather than being assumed to equal the user's UID.

## Workflow

1. `POST /v1/contacts` creates a customer with an E.164 phone number.
2. `POST /v1/uploads` stores a base64 JPEG, PNG, or PDF in private Firebase
   Storage and returns its SHA-256-deduplicated upload ID.
3. `POST /v1/invoice-extractions` runs Gemini's schema-constrained extraction.
   It creates a draft in `needs_review`; the model can never post a balance.
4. `POST /v1/invoices/approve` posts an approved invoice and an immutable
   positive ledger entry in one Firestore transaction.
5. `POST /v1/contacts/:id/payments` appends a negative ledger entry for any
   partial/full payment.
6. `POST /v1/contacts/:id/reminders/draft` returns a reviewed WhatsApp deep
   link. It does not send a message programmatically.

## Required environment

Set Firebase Admin credentials and `FIREBASE_STORAGE_BUCKET`. For extraction,
set `GEMINI_API_KEY`; optional `GEMINI_MODEL` defaults to `gemini-2.5-flash`.

## Core endpoints

- `GET|POST /v1/contacts`
- `GET|POST /v1/catalog-products`
- `POST /v1/uploads`
- `POST /v1/invoice-extractions`, `GET /v1/invoice-extractions/:id`
- `POST /v1/invoices/approve`
- `POST /v1/contacts/:id/payments`, `GET /v1/contacts/:id/ledger`
- `GET /v1/dashboard`
- `POST /v1/contacts/:id/reminders/draft`

## Response contracts

Responses remain unwrapped to preserve existing consumers. Dates are returned as
ISO-8601 strings or `null`, and money values are JSON numbers rounded to two
decimal places.

- `GET /v1/contacts` returns each existing contact field plus
  `currentBalance`, `invoiceCount`, `earliestDueDate`, and `overdue`.
  `invoiceCount` is the total number of approved invoice ledger entries,
  including fully paid invoices.
- `GET /v1/dashboard` returns `outstandingTotal`, `overdueTotal`, and
  `customerCount`. `customerCount` counts contacts with a positive outstanding
  balance.
- `GET /v1/contacts/:id/ledger` returns normalized invoice/payment entries with
  nullable fields represented explicitly as `null`.
- `POST /v1/uploads` returns `id`, `sha256`, and `status: "uploaded"`.
- Invoice extraction create/get responses use the same extraction shape,
  including status, draft, failure, approval, and timestamp fields.
- Invoice approval returns `id` and `status: "approved"`.
- Payment creation returns `id` and `type: "payment"`.
- Reminder draft creation returns `id`, `message`, and `whatsappUrl`.

Payments are applied to invoices in oldest-due-first order when calculating
summaries. `currentBalance` is the unpaid invoice total after payments.
`earliestDueDate` is the earliest due date among invoices with a remaining
balance. An account is overdue only when at least one invoice still has a
remaining balance after payment allocation and its due date is in the past.
Overpayments are clamped to a zero summary balance; credit-balance support is not
part of the MVP contract.

Keep raw image files private. Audit events record invoice approvals and payment
entries. For a future WhatsApp Cloud API integration, add explicit opt-in,
approved-template metadata, webhook verification, and delivery-status storage.
