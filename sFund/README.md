## Overview

**Verdant Pulse** is a Clarity smart contract built to empower communities, conservationists, and philanthropists to **securely fund**, **track**, and **govern** watershed restoration projects.  
It ensures **transparency**, **fairness**, and **resilience** in the stewardship of environmental restoration efforts.

Key Features:
- Accepts donations to a **Community Conservation Fund**.
- Manages registration and evaluation of **eligible conservation sites**.
- **Allocates funds** to verified projects based on the coordinator's decisions.
- Tracks **site conditions** and **steward contributions** over time.
- Implements **emergency protocols** to pause activity during unforeseen events.
- Enables **transparent governance**, including coordinator changes.

---

## Core Concepts

### 🌿 Conservation Fund
- Donations in STX are pooled into the fund.
- Only registered conservation sites can receive allocations.
- The fund is protected by minimum donation rules and sanity checks.

### 🌍 Conservation Sites
- Sites are **registered** by the Watershed Coordinator.
- Each site maintains metadata like:
  - Active status
  - Total resources allocated
  - Last allocation block height
  - Current restoration condition (`restored`, `in-progress`, `degraded`, `stabilized`)

### 🤝 Stewards
- Donors are registered as Stewards upon their first donation.
- Their total contribution history is tracked.

### 🛡️ Program Governance
- The Watershed Coordinator holds the authority to:
  - Register new conservation sites.
  - Allocate conservation funds.
  - Set minimum donation thresholds.
  - Update site condition statuses.
  - Toggle normal and emergency modes.
  - Change the coordinator (with restrictions).

---

## Contract Functions

### Read-only Functions
- `get-watershed-coordinator`
- `get-conservation-fund`
- `get-site-info`
- `get-steward-info`
- `check-program-status`

### Public Functions
- `contribute-to-watershed` — Donate to the Conservation Fund.
- `register-conservation-site` — Register a new restoration site.
- `allocate-resources` — Allocate funding to registered sites.
- `set-donation-minimum` — Update minimum donation amount.
- `toggle-program-status` — Pause or resume normal operations.
- `set-emergency-mode-on` / `set-emergency-mode-off` — Manage emergency modes.
- `update-site-condition` — Update the reported site condition.
- `change-coordinator` — Transfer coordinator privileges to a new principal.

---

## Data Structures

### Conservation Sites (Map)
```clarity
{
  site-active: bool,
  resources-allocated: uint,
  last-allocation-block: uint,
  current-condition: (string-ascii 20)
}
```

### Steward Registry (Map)
```clarity
{
  total-contributions: uint,
  latest-contribution-block: uint
}
---

## Deployment Notes

- When deployed, `tx-sender` becomes the first Watershed Coordinator.
- Best practice: deploy with a multisig wallet for safer coordination transitions.
- Donation minimum defaults to **1 STX** but can be adjusted.

---

## Example Workflow

1. **Deployment:** Contract deployed by initial coordinator.
2. **Activation:** Program starts active; donors contribute to the fund.
3. **Registration:** Coordinator registers eligible conservation sites.
4. **Funding:** Coordinator allocates funds to active sites.
5. **Condition Updates:** Coordinator updates site conditions over time.
6. **Governance:** Coordinator role can be transferred if needed.
7. **Emergency Response:** Emergency mode can be activated during threats.

---

## Future Enhancements (Ideas)

- Multi-coordinator voting system for decentralized governance.
- Public proposal submission and voting for fund allocation.
- Site performance scoring and incentive mechanisms.
- Integration with IoT sensor data for automated site monitoring.
