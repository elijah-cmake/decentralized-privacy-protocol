# BitMixer: Decentralized Privacy Protocol for STX

**BitMixer** is a decentralized, non-custodial privacy protocol for the Stacks (STX) blockchain. It enables users to preserve transactional privacy without compromising regulatory compliance, sustainability, or transparency.

## Overview

BitMixer empowers users with self-sovereign financial privacy through a **mixing pool protocol** built with Clarity on Stacks. By leveraging multi-party pools, configurable parameters, daily rate limits, and protocol governance mechanisms, BitMixer strikes a balance between **privacy**, **security**, and **compliance**.

## Key Features

* **Self-Custodial Design**: Users retain control of their funds throughout the process.
* **Pool-Based Mixing**: Join configurable multi-participant mixing pools to anonymize transaction trails.
* **Daily Transaction Limits**: Built-in constraints to meet compliance requirements.
* **Protocol Fees**: A 2% mixing fee supports sustainable development and maintenance.
* **Emergency Pause**: Admin-controlled pause for responding to critical vulnerabilities.
* **Transparent State**: On-chain visibility into pools, user balances, and protocol fees.

## Configuration Constants

| Constant                 | Description                                            | Value            |
| ------------------------ | ------------------------------------------------------ | ---------------- |
| `MAX-DAILY-LIMIT`        | Daily transaction limit per user                       | `u10000000000`   |
| `MAX-POOL-PARTICIPANTS`  | Max participants in a single mixing pool               | `u10`            |
| `MAX-TRANSACTION-AMOUNT` | Max amount per deposit/withdrawal                      | `u1000000000000` |
| `MIN-POOL-AMOUNT`        | Minimum required to join/create a pool                 | `u100000`        |
| `MIXING-FEE-PERCENTAGE`  | Fee taken from total pool (supports protocol treasury) | `u2` (2%)        |

## Contract Architecture

### Public Functions

* `initialize` – Initializes the contract (owner-only).
* `deposit` – Deposit STX into the contract.
* `withdraw` – Withdraw STX with compliance checks.
* `create-mixer-pool` – Create a new pool with an initial deposit.
* `join-mixer-pool` – Join an existing mixing pool.
* `distribute-pool-funds` – Distribute anonymized funds equally among participants.
* `toggle-contract-pause` – Pause/unpause contract (emergency only).
* `withdraw-protocol-fees` – Owner withdrawal of accumulated fees.

### Read-Only Functions

* `get-user-balance` – Check a user’s STX balance in the contract.
* `get-daily-limit-remaining` – See how much a user can still transact today.
* `get-contract-status` – Get contract state (paused, initialized, total fees).
* `get-pool-details` – Fetch detailed data for a specific mixing pool.

### Private Functions

* `distribute-to-participant` – Internal logic for distributing anonymized pool funds.

## Lifecycle of a Mix

1. **Deposit**: User deposits STX under daily/compliance constraints.
2. **Create or Join Pool**: User creates or joins an active pool (min. amount enforced).
3. **Pool Fills**: Pool grows until max participants are reached.
4. **Distribute**: Funds are distributed equally minus mixing fee, anonymizing participants.

## Security and Compliance

* **Regulatory Alignment**: Daily limits and participant tracking support jurisdictional compliance.
* **Emergency Controls**: Owner can pause contract for incident response.
* **Non-Custodial**: At no point does the contract take custody or ownership of user funds.

## Design Philosophy

BitMixer is designed to offer **practical privacy** for everyday users and institutions alike. It doesn't attempt to be absolute or adversarial but instead offers plausible deniability and transaction unlinkability within a compliant, auditable, and user-respecting framework.

## Error Codes

| Code    | Error                            |
| ------- | -------------------------------- |
| `u1000` | Not authorized                   |
| `u1001` | Invalid amount                   |
| `u1002` | Insufficient balance             |
| `u1003` | Contract not initialized         |
| `u1004` | Already initialized              |
| `u1005` | Pool is full                     |
| `u1006` | Daily transaction limit exceeded |
| `u1007` | Invalid pool                     |
| `u1008` | Duplicate pool participant       |
| `u1009` | Insufficient pool funds          |
| `u1010` | Pool not ready for distribution  |

## Deployment & Usage

1. **Deploy** the contract to the Stacks blockchain.
2. **Call `initialize`** to activate it (owner-only).
3. Users begin **depositing**, **joining/creating pools**, and **mixing funds**.
4. Owner can manage protocol fees and pause/resume operations as needed.

## Test Coverage

BitMixer is designed for robust, testable behavior including:

* Edge cases on pool participation
* Daily limit enforcement
* Emergency pause state behavior
* Accurate fund distribution and fee capture

(Include test suite references or usage instructions here if available.)

## Contributing

We welcome community contributions, audits, and feature suggestions. Please submit issues or pull requests if you'd like to collaborate on improving BitMixer.
