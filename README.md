# Critical Vulnerability in LSDChainlinkOracle: Price Manipulation via User-Supplied Oracles

This repository contains a minimal, verifiable Proof of Concept (PoC) demonstrating a critical-severity vulnerability in the `LSDChainlinkOracle.sol` contract.

The vulnerability allows any user to supply their own malicious oracle addresses, giving them complete control over the price returned by the contract. This flaw can be exploited to cause a **total loss of funds** in any protocol that relies on this oracle for financial calculations, such as a lending market or a decentralized exchange.

---

## The Vulnerability Explained: A Plain-English Analogy

The `LSDChainlinkOracle` contract is supposed to act like a trusted bank teller who can tell you the price of an asset.

-   **The Secure Way:** A bank teller verifies your identity by checking your ID against the bank's own, trusted, internal computer system.
-   **The Vulnerable Way (How this contract works):** This contract acts like a bank teller who asks you, "To verify your identity, which computer system would you like me to use?"

An attacker can simply point the contract to their own fake data source, and the contract is forced to believe it.

## Technical Details

The `getPrice` function does not use hardcoded, trusted oracle addresses. Instead, it decodes the oracle addresses from a user-supplied `bytes memory data` parameter on every call.

**File:** `src/LSDChainlinkOracle.sol`
**Vulnerable Code Pattern:**
```solidity
function getPrice(..., bytes memory data) external view returns (uint256) {
    (
        address ethChainlinkOracle,   // <-- Attacker-controlled
        uint256 ethTimeout,
        address xEthChainlinkOracle,  // <-- Attacker-controlled
        uint256 xEthTimeout
    ) = abi.decode(data, (address, uint256, address, uint256));

    // The contract then makes calls to these attacker-controlled addresses.
    uint256 xEthEthPrice = LibChainlinkOracle.getTokenPrice(xEthChainlinkOracle, ...);
    uint256 ethUsdPrice = LibChainlinkOracle.getTokenPrice(ethChainlinkOracle, ...);
    // ...
}
