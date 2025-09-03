Here’s a **well-formatted `README.md`** for your Quest System smart contract project, suitable for GitHub submission:


# Quest System Smart Contract

**Version:** 1.0.0
**Language:** Clarity
**Test Framework:** Clarinet
**Author:** Your Name / GitHub Handle

## Overview

The **Quest System** is a Clarity smart contract designed for the Stacks blockchain. It enables the creation of quests with **fungible token (FT)** or **non-fungible token (NFT)** rewards. Players can enroll, submit proofs of completion, and claim rewards securely on-chain. Admins can manage quests, verify completions, and prevent double-claiming.

This contract is **Clarinet-ready**, fully testable in a local development environment.

## Features

* **Admin / Contract Owner**

  * Create quests with titles, descriptions, reward type (FT/NFT), and optional participant limits.
  * Pause or unpause quests.
  * Verify player completions and optionally auto-claim rewards.

* **Player Interactions**

  * Enroll in quests.
  * Submit proof of completion.
  * Claim rewards (FT or NFT).

* **Reward System**

  * **QFT** – Fungible token reward.
  * **QNFT** – Non-fungible token reward (badges / collectibles).
  * Prevents double-claiming and multiple submissions.

* **Read-only Views**

  * Query quests, enrollment status, completion status, reward claims, and next quest ID.

## Error Codes

| Code | Description            |
| ---- | ---------------------- |
| 100  | Unauthorized action    |
| 101  | Quest not found        |
| 102  | Already enrolled       |
| 103  | Not enrolled           |
| 104  | Already completed      |
| 105  | Nothing to claim       |
| 106  | Zero reward amount     |
| 107  | Reward already claimed |
| 108  | NFT minting failed     |
| 109  | FT minting failed      |
| 110  | Invalid input          |

## Contract Structure

* `CONTRACT-OWNER`: Contract deployer with admin privileges.
* `QFT`: Fungible token used for rewards.
* `QNFT`: NFT used for quest badges.
* `quests` map: Stores quest metadata.
* `participants` map: Tracks enrolled players.
* `completions` map: Stores proof of completion and timestamp.
* `claimed` map: Tracks claimed rewards.

## Usage

### Admin Functions

* `create-quest(title, description, reward-kind, reward-value, max-participants)`
* `set-quest-active(quest-id, flag)`
* `admin-complete(quest-id, player, auto-claim, proof)`

### Player Functions

* `enroll(quest-id)`
* `submit-proof(quest-id, proof)`
* `claim-reward(quest-id)`

### Read-only Views

* `get-quest(quest-id)`
* `has-enrolled(quest-id, player)`
* `has-completed(quest-id, player)`
* `has-claimed(quest-id, player)`
* `get-next-quest-id()`

---

## Testing

* **Framework:** Clarinet
* Test cases cover:

  * Quest creation and updates
  * Player enrollment, proof submission, and reward claiming
  * Admin completion and auto-claim functionality
  * Double-claim and error handling scenarios

**Run tests:**

```bash
clarinet test
```


## Future Improvements

* Integrate off-chain proof verification for quests.
* Add tiered rewards or time-limited quests.
* Event logging for frontend integration.
* Support multiple concurrent quests per player.
