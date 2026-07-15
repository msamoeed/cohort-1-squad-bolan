# Risks & Mitigations
**Squad Bolan | Last Updated: Week 1**

---

## Why This Document Exists

Most teams skip risk planning. We didn't.
This document tracks every major risk we identified — technical, product, and business — as hypotheses under validation. Each risk includes evidence, mitigation, success criteria, and current status.

---

## How We Think About Risks

Startups don't just list fears. They validate hypotheses.

Instead of saying *"OCR might fail"* — we say:
> **Hypothesis: OCR can reliably extract the fields required for our MVP from real distributor invoices.**
> Status: 🟡 Under Validation

This document will be updated weekly as we learn more.

---

## Risk Priority Table

| # | Risk | Probability | Impact | Status |
|---|------|-------------|--------|--------|
| 1 | OCR fails on handwritten Urdu invoices | 🔴 High | 🔴 High | Under Validation |
| 2 | Product names too random for OCR | 🔴 High | 🔴 High | ✅ Mitigated — pre-load catalog |
| 3 | We're solving the wrong problem | 🟡 Medium | 🔴 High | Under Validation |
| 4 | Users won't switch from current workflow | 🟡 Medium | 🔴 High | Interviews this week |
| 5 | WhatsApp Business API limitations | 🟡 Medium | 🔴 High | Research needed |
| 6 | Wrong balance shown to user | 🟡 Medium | 🔴 High | Deterministic logic locked |
| 7 | Users won't share financial data | 🟡 Medium | 🟡 Medium | Warm intros planned |
| 8 | Blurry or low quality invoice photos | 🟡 Medium | 🟡 Medium | Image hints in UI |
| 9 | Mixed Urdu+English confuses OCR | 🔴 High | 🟡 Medium | Testing providers |
| 10 | Scope creep kills the MVP | 🟡 Medium | 🟡 Medium | Alignment rule locked |
| 11 | Pilot users too busy to give feedback | 🟡 Medium | 🟡 Medium | WhatsApp weekly ask |

---

## Detailed Risk Breakdown

---

### Risk 1 — OCR May Fail on Handwritten Urdu Invoices

**Hypothesis:** OCR can reliably extract customer, amount, and due date from real distributor invoices.
**Status:** 🟡 Under Validation

**Evidence we observed:**
We collected 2 real invoice samples from local distributors. Both had:
- Mixed Urdu + English text
- Non-standard product name abbreviations
- No fixed column structure
- Handwritten numbers that could be misread

**Mitigation:**
- Collect 20–30 real invoice samples before writing a single line of OCR code
- Test Google Cloud Vision AND Azure Document Intelligence on real samples
- If accuracy below 85% — pivot to structured manual invoice creation
- Human review mandatory before any data is posted

**Backup Plan:**
If Google Vision gives 40% and Azure gives 55% — neither is good enough.
→ No OCR → Invoice template → Manual confirmation → Still solves receivables.
This pivot keeps the product alive even if OCR fails completely.

**Success Criteria:** 85%+ of required fields (customer, date, amount, due date) extracted correctly on 20 real samples.

---

### Risk 2 — Product Names Too Random for OCR to Match

**Hypothesis:** Pre-loading the distributor's product catalog during onboarding will make OCR context-aware and significantly improve extraction accuracy.
**Status:** ✅ Mitigated

**Original Insight:**
> *"If we know the distributor's business type and product catalog upfront during onboarding, OCR accuracy will improve dramatically. Product names won't be completely random — even a partial match will help the system extract the right data. Less guessing, more accuracy."*

**Why this works:**
- OCR matches against known product names instead of guessing from scratch
- Partial matches work — "خلیل مکس کم" matches "خلیل مکس" in catalog
- This turns random OCR into context-aware extraction
- No model change needed — just smarter onboarding

**Success Criteria:** OCR product name match rate improves by 30%+ when catalog is pre-loaded vs not.

---

### Risk 3 — We're Solving the Wrong Problem ⭐

**Hypothesis:** Distributors care most about knowing who owes them money — more than any other financial pain.
**Status:** 🟡 Under Validation

**What can go wrong:**
What if distributors actually care more about payment collection reminders than invoice entry? Or stock management? We could build the wrong thing entirely.

**Mitigation:**
- Continue user interviews — ask distributors to RANK their top 3 pain points
- Don't ask "would you use this?" — ask "what do you do today when a shop doesn't pay on time?"
- If interviews reveal a different core pain — change the MVP now, not in Week 6

**Success Criteria:** 4 out of 5 interviewed distributors rank "tracking who owes me money" as their top pain point.

---

### Risk 4 — Users Won't Switch From Their Current Workflow

**Hypothesis:** Distributors will adopt HisaabAI if it answers "who owes me money?" faster than their current method.
**Status:** 🟡 Under Validation

**What can go wrong:**
Distributors have used notebooks and WhatsApp for years. A new app feels like extra work unless it shows immediate value.

**Mitigation:**
- Interview distributors BEFORE building — understand exact current workflow
- Replace only the most painful step first — not everything at once
- Show value in first onboarding session — outstanding balance visible immediately
- Target: answer "who owes me money?" in 30 seconds vs 5 minutes manually

**Success Criteria:** 3 out of 5 pilot users check the app at least 3 times in their first week without being asked.

---

### Risk 5 — WhatsApp Business API Limitations

**Hypothesis:** We can build a working WhatsApp reminder flow within MVP constraints without official API approval.
**Status:** 🔴 Research Needed

**What can go wrong:**
Automated WhatsApp messaging requires official Business API approval — which takes time and may have template restrictions. Discovering this in Week 7 would be catastrophic.

**Mitigation:**
- Research WhatsApp deep link approach vs API approach immediately — Week 2
- MVP plan: use WhatsApp deep links with pre-filled editable messages — no API needed
- Never attempt automated sending in MVP — user manually taps to send
- Escalate to mentor if API route becomes necessary

**Success Criteria:** WhatsApp reminder deep link opens correctly on 95%+ of tested Android devices by Week 4.

---

### Risk 6 — Wrong Balance Shown to User

**Hypothesis:** Our deterministic ledger logic will always produce correct balances regardless of how many partial payments are recorded.
**Status:** 🟡 Open — Logic Not Yet Built

**What can go wrong:**
One wrong balance = instant loss of trust. Money mistakes are unforgivable.

**Mitigation:**
- All balance calculations are deterministic backend logic — never LLM-generated
- Formula locked: `Open Balance = Invoice Total - Sum of approved payment allocations`
- Audit log for every edit, approval, and deletion
- AI never posts data automatically — human confirms first
- 100% ledger accuracy is non-negotiable Demo Day requirement

**Success Criteria:** 100% correct balances on all audited invoice + payment scenarios before pilot launch.

---

### Risk 7 — Users Won't Share Financial Data With Us

**Hypothesis:** Distributors will share real invoice data if we approach them as a free pilot with white-glove support.
**Status:** 🟡 Under Validation

**Mitigation:**
- Position as "free pilot" — not a product launch
- White-glove onboarding — sit with user, help enter first 10 invoices personally
- Never ask for bank details or sensitive credentials
- Start with 3–5 warm intro contacts only
- Pitch: *"If you sell on credit and struggle to remember which shop owes what — this gives you a clear list on your phone."*

**Success Criteria:** 3 anchor businesses agree to share real invoice data by end of Week 2.

---

### Risk 8 — Blurry or Low Quality Invoice Photos

**Hypothesis:** Most distributors' phones can capture invoice photos clear enough for OCR to process.
**Status:** 🟡 Under Validation

**Mitigation:**
- Show image quality hint before upload
- Add crop and rotate feature
- Allow retry upload
- Test on older Android devices — not just modern phones

**Success Criteria:** 80%+ of invoice photos submitted by pilot users are processable without retry.

---

### Risk 9 — Urdu + English Mixed Documents Confuse OCR

**Evidence we observed:**
Both real invoice samples we collected had mixed Urdu, English, numbers, and abbreviations on the same page.

**Mitigation:**
- Test OCR providers on mixed-script samples specifically
- Store raw OCR output always for debugging
- Azure Document Intelligence has better multilingual support — evaluate first
- Fast correction flow — user can fix any field in under 30 seconds

**Success Criteria:** OCR returns usable output on 75%+ of mixed-script real samples.

---

### Risk 10 — Scope Creep Kills the MVP

**Mitigation:**
One alignment rule: *"Does this feature help a distributor capture a credit sale, understand who owes them money, follow up, or record payment? If not — it is NOT MVP scope."*

**Success Criteria:** Zero features outside receivables core loop are built before Week 6.

---

### Risk 11 — Pilot Users Too Busy to Give Feedback

**Mitigation:**
- Ask only ONE small question per week via WhatsApp
- Weekly ask: *"Bhai ek cheez batao — app mein kya confusion hua is hafte?"*
- White-glove setup keeps us in contact from Day 1

**Success Criteria:** At least 3 pilot users respond to weekly feedback ask each week.

---

## Open Questions

### Technical
| Question | Why It Matters |
|----------|---------------|
| Google Vision or Azure for OCR? | Core technical decision — test on real samples first |
| How to handle completely illegible invoices? | Edge case in OCR flow |
| Background worker needed or sync processing? | Affects mobile UX on slow connections |

### Product
| Question | Why It Matters |
|----------|---------------|
| Will Field Staff confirm invoices or only Owner? | Affects role design and trust model |
| Which invoice fields are truly required vs optional? | Affects extraction review screen design |

### Business
| Question | Why It Matters |
|----------|---------------|
| Which city for first pilot cluster? | Affects user recruitment strategy |
| Warm intros or cold outreach for pilots? | Affects speed of first 5 users |

### User
| Question | Why It Matters |
|----------|---------------|
| Do distributors already take invoice photos? | Validates OCR as natural workflow fit |
| Authentication — phone OTP or email/password? | Affects onboarding friction |

---

## Biggest Unknowns — Ranked

1️⃣ **OCR accuracy on real handwritten invoices** — if this fails, entire tech approach changes
2️⃣ **Are we solving the right problem?** — interviews this week will confirm or kill our wedge
3️⃣ **User adoption** — will distributors actually switch from notebooks?
4️⃣ **WhatsApp integration** — deep links vs API, must research now not Week 7
5️⃣ **Data accuracy** — one wrong balance ends pilot trust immediately

---

*This document will be updated weekly as we learn from real users and real invoice samples.*
