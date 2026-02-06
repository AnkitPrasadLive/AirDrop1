

# AirDrop 🎁 – Gas-Efficient ERC20 Merkle Airdrop

📌 **Overview**
AirDrop is a **gas-optimized Merkle airdrop contract** built with Solidity and OpenZeppelin. It allows token owners to distribute ERC20 tokens efficiently to multiple recipients using **Merkle proofs**. Batch claims, bitmap tracking, claim deadlines, and emergency withdrawals are included for production-ready deployments.

This project is created to demonstrate smart contract development, testing, and deployment for large-scale token distributions.

---

⚡ **Features**

* ERC20 token airdrop using Merkle proofs
* Gas-efficient **bitmap tracking** (1 bit per claim)
* Single & **batch claim support**
* Claim deadlines and **emergency withdrawal**
* Owner-controlled **Merkle root updates**
* Fully tested with **Foundry** (unit + fuzz tests)
* ERC20Permit support for gasless workflows

---

🛠️ **Tech Stack**

* Solidity ^0.8.20
* OpenZeppelin Contracts v5
* Foundry (Forge + Cast) for testing
* Node.js + merkletreejs + ethers.js (off-chain Merkle generation)

---

📂 **Project Structure**

```
├── src
│   ├── Airdrop.sol        # Merkle airdrop contract
│   └── ERC20Mock.sol      # ERC20 + Permit mock token
├── script
│   └── generateMerkle.js  # JS Merkle tree generator
├── test
│   └── Airdrop.t.sol      # Unit + fuzz tests
├── foundry.toml           # Foundry config
└── README.md              # Project docs
```

---

✅ **Tests**
Run the test suite:

```bash
forge test
```

Sample tests included:

* Single claim increases balance
* Batch claim transfers multiple tokens in one tx
* Double-claim prevention
* Invalid Merkle proof reverts
* Claim deadline enforcement
* Emergency withdrawal by owner

---

🚀 **Deployment (Testnet)**

Compile contracts:

```bash
forge build
```

Deploy ERC20 mock:

```bash
forge create src/ERC20Mock.sol:ERC20Mock --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY
```

Deploy Airdrop contract:

```bash
forge create src/Airdrop.sol:Airdrop --rpc-url $SEPOLIA_RPC --private-key $PRIVATE_KEY \
--constructor-args <TOKEN_ADDRESS> <MERKLE_ROOT> <CLAIM_DURATION_SECONDS> <OWNER_ADDRESS>
```

---

📌 **Merkle Tree Generation**
Off-chain JS script (`script/generateMerkle.js`) generates:

* Merkle root
* Proofs per claim
* JSON output for testing & deployment

```bash
node script/generateMerkle.js
```

---

📌 **Future Improvements**

* Frontend integration for claim UI
* Multi-token airdrops
* Gasless claim flows using ERC20Permit + meta-transactions
* L2 optimizations for cheaper claims

