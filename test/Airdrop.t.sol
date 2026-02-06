// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Airdrop.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Simple Mock Token for testing
contract TokenMock is ERC20 {
    constructor() ERC20("Mock Token", "MKT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract AirdropTest is Test {
    TokenMock token;
    Airdrop airdrop;

    address user = address(0x1);
    address owner = address(this);

    // Merkle Tree Storage
    bytes32[] leaves;
    bytes32 root;

    // Test Data
    uint256 amount1 = 100;
    uint256 amount2 = 50;

    function setUp() public {
        token = new TokenMock();
        token.mint(address(this), 1000);

        // ----------------------------------------------------
        // 1. GENERATE MERKLE DATA (Manual for 2 leaves)
        // ----------------------------------------------------
        // We will create 2 claims for the SAME user (user)
        // to test both single claim and batch claim.

        leaves = new bytes32[](2);

        // Leaf 0: Index 0, User, Amount 100
        // MUST match Airdrop.sol: keccak256(abi.encodePacked(idx, msg.sender, amount))
        leaves[0] = keccak256(abi.encodePacked(uint256(0), user, amount1));

        // Leaf 1: Index 1, User, Amount 50
        leaves[1] = keccak256(abi.encodePacked(uint256(1), user, amount2));

        // Generate Root: Sort the leaves and hash them together
        // (OpenZeppelin's MerkleProof sorts pairs before hashing)
        if (uint256(leaves[0]) < uint256(leaves[1])) {
            root = keccak256(abi.encodePacked(leaves[0], leaves[1]));
        } else {
            root = keccak256(abi.encodePacked(leaves[1], leaves[0]));
        }

        // ----------------------------------------------------
        // 2. DEPLOY AIRDROP
        // ----------------------------------------------------
        airdrop = new Airdrop(address(token), root, 1 days, owner);

        // Fund the Airdrop contract
        token.transfer(address(airdrop), 500);
    }

    function testClaim() public {
        // Prepare Proof for Leaf 0
        // Since we only have 2 leaves, the proof for Leaf 0 is just Leaf 1
        bytes32[] memory proof = new bytes32[](1);
        proof[0] = leaves[1];

        vm.startPrank(user);

        // Claim Index 0
        airdrop.claim(0, amount1, proof);

        assertEq(token.balanceOf(user), 100);
        assertTrue(airdrop.isClaimed(0));
        vm.stopPrank();
    }

    function testBatchClaim() public {
        // Prepare Arrays
        uint256[] memory indexes = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        bytes32[][] memory proofs = new bytes32[][](2);

        // Data for Index 0
        indexes[0] = 0;
        amounts[0] = amount1;
        proofs[0] = new bytes32[](1);
        proofs[0][0] = leaves[1]; // Proof for Leaf 0 is Leaf 1

        // Data for Index 1
        indexes[1] = 1;
        amounts[1] = amount2;
        proofs[1] = new bytes32[](1);
        proofs[1][0] = leaves[0]; // Proof for Leaf 1 is Leaf 0

        vm.startPrank(user);

        airdrop.batchClaim(indexes, amounts, proofs);

        // User should have 100 + 50 = 150 tokens
        assertEq(token.balanceOf(user), 150);
        assertTrue(airdrop.isClaimed(0));
        assertTrue(airdrop.isClaimed(1));
        vm.stopPrank();
    }
}
