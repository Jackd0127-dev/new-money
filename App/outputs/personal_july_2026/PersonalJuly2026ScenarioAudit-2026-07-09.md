# Personal July 2026 Scenario Audit

- Fixed current date: 2026-07-09 12:00 Europe/London
- Calendar: Gregorian; locale: en_GB; currency: GBP
- Store: isolated InMemoryPlannerRepository; cloud/account sync disabled

## Fixture construction timeline
1. Seed opening pots totalling £982.32.
2. Complete iCloud+, Runna, Apple Care and Aqua opening-balance funding through PlannerStore checklist commands.
3. Resulting pot balances total £1,144.72.
4. On 10 July only, run the existing due recurring-card-payment path after funding is complete.

## Opening pot ledger
| Pot ID | Pot | Opening |
| --- | --- | ---: |
| pot-insurance | Insurance | £0.00 |
| pot-jaja | Jaja | £215.80 |
| pot-capital-one | Capital One | £80.79 |
| pot-zable | Zable | £0.00 |
| pot-barclays | Barclays | £506.85 |
| pot-aqua | Aqua | £178.88 |
| total |  | £982.32 |

## Funding actions ledger
| Allocation ID | Source obligation | Pot | Amount | Link |
| --- | --- | --- | ---: | --- |
| card-opening-balance-funding-allocation-card-aqua-2026-07-20-personal-july-2026 | card-aqua / 2026-07-20 | Aqua | £128.43 | card_opening_balance_funding |
| recurring-bill-funding-allocation-bill-apple-care-2026-07-19-personal-july-2026 | bill-apple-care / 2026-07-19 | Barclays | £8.99 | recurring_bill_funding |
| recurring-bill-funding-allocation-bill-icloud-2026-07-10-personal-july-2026 | bill-icloud / 2026-07-10 | Barclays | £8.99 | recurring_bill_funding |
| recurring-bill-funding-allocation-bill-runna-2026-07-18-personal-july-2026 | bill-runna / 2026-07-18 | Barclays | £15.99 | recurring_bill_funding |

## Final pot ledger
| Pot ID | Pot | Final balance |
| --- | --- | ---: |
| pot-insurance | Insurance | £0.00 |
| pot-jaja | Jaja | £215.80 |
| pot-capital-one | Capital One | £80.79 |
| pot-zable | Zable | £0.00 |
| pot-barclays | Barclays | £540.82 |
| pot-aqua | Aqua | £307.31 |
| total |  | £1144.72 |

## Stable bill occurrence IDs
| Occurrence ID | Status | Transaction ID |
| --- | --- | --- |
| bill-icloud-2026-07-10 | funded/planned | none |
| bill-runna-2026-07-18 | funded/planned | none |
| bill-apple-care-2026-07-19 | funded/planned | none |
| bill-car-insurance-2026-08-01 | funded/planned | none |
| bill-gym-2026-08-01 | funded/planned | none |
| bill-skin-me-2026-08-01 | funded/planned | none |
| bill-chatgpt-2026-08-07 | funded/planned | none |
| bill-icloud-2026-08-10 | funded/planned | none |
| bill-runna-2026-08-18 | funded/planned | none |
| bill-apple-care-2026-08-19 | funded/planned | none |
- Duplicate occurrence IDs: none

## Money Left calculation
Starting income: £3406.63

Included deductions for Home/current Money Left:
| Record ID | Type | Description | Amount | Date | Linked pot/card | Reason |
| --- | --- | --- | ---: | --- | --- | --- |
| pot-allocation-card-opening-balance-funding-allocation-card-aqua-2026-07-20-personal-july-2026 | pot_allocation | Aqua card opening balance funding | £128.43 | 2026-07-01 | Aqua / - | completed/non-projected cost-summary item |
| pot-allocation-recurring-bill-funding-allocation-bill-apple-care-2026-07-19-personal-july-2026 | pot_allocation | Barclays bill funding | £8.99 | 2026-07-01 | Barclays / - | completed/non-projected cost-summary item |
| pot-allocation-recurring-bill-funding-allocation-bill-runna-2026-07-18-personal-july-2026 | pot_allocation | Barclays bill funding | £15.99 | 2026-07-01 | Barclays / - | completed/non-projected cost-summary item |
| pot-allocation-recurring-bill-funding-allocation-bill-icloud-2026-07-10-personal-july-2026 | pot_allocation | Barclays bill funding | £8.99 | 2026-07-01 | Barclays / - | completed/non-projected cost-summary item |
| recurring-bill-icloud-2026-07-10 | recurring | iCloud+ | £8.99 | 2026-07-10 | Barclays / Barclays | completed/non-projected cost-summary item |
| recurring-bill-runna-2026-07-18 | recurring | Runna | £15.99 | 2026-07-18 | Barclays / Barclays | completed/non-projected cost-summary item |
| recurring-bill-apple-care-2026-07-19 | recurring | Apple Care | £8.99 | 2026-07-19 | Barclays / Barclays | completed/non-projected cost-summary item |

Excluded candidates from Home/current Money Left:
| Record ID | Type | Description | Amount | Reason |
| --- | --- | --- | ---: | --- |
| planned-card-payment-funding-card-payment-funding-card-aqua-pot-aqua-2026-08-20 | pot_allocation | Aqua card payment funding | £6.99 | projected/unfunded checklist item; excluded from currentMoneyLeftPence |
| planned-card-payment-funding-card-payment-funding-card-barclays-pot-barclays-2026-08-06 | pot_allocation | Barclays card payment funding | £138.59 | projected/unfunded checklist item; excluded from currentMoneyLeftPence |
| planned-card-payment-funding-card-payment-funding-card-capital-one-pot-capital-one-2026-08-02 | pot_allocation | Capital One card payment funding | £121.58 | projected/unfunded checklist item; excluded from currentMoneyLeftPence |

- Home/current total deductions: £162.40
- Home/current Money Left: £3244.23
- Projected total deductions: £1010.21
- Projected Money Left (audit legacy field moneyLeftPence): £2977.07

## Planned-cost field comparison
- Funding checklist completed allocations: £162.40
- Committed costs (non-projected): £162.40
- Outstanding/projected checklist costs: £267.16
- All projected costs: £1010.21
- Value used by Home Money Left card: currentMoneyLeftPence = £3244.23
- Value previously inspected by the audit: moneyLeftPence = £2977.07

## Card-funding-gap inclusion report
- Capital One gap £121.58: included in projected Money Left only
- Barclays gap £138.59: included in projected Money Left only
- Aqua gap £6.99: included in projected Money Left only

## Safe-to-spend numerator and denominator
- Home/current: numerator £3244.23; denominator 23 inclusive days; result £141.05
- Projected: numerator £2977.07; denominator 23 inclusive days; result £129.43

## Specification checks
- PASS [calculation discrepancy] Card balance: expected £1377.91; actual £1377.91
- PASS [calculation discrepancy] Available credit: expected £2022.09; actual £2022.09
- PASS [calculation provenance] Committed costs: expected £162.40; actual £162.40
- PASS [calculation provenance] Home Money Left: expected £3244.23; actual £3244.23
- PASS [calculation provenance] Home safe to spend: expected £141.05; actual £141.05
- PASS [fixture loading] Final pot total: expected £1144.72; actual £1144.72

## Final classification
Fixture problem resolved: final balances had previously been seeded without completed funding history; projected Money Left remains a distinct metric.

## Out-of-scope policy questions
- Insurance pot target behaviour
- Barclays statement recurrence
- Aqua opening-balance overlap
- Home All Outgoings presentation
- Jaja due-date production repair
- UI screenshot coverage
