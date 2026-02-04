// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Airdrop} from "../src/Airdrop.sol";
import {ERC20Mock} from "../src/ERC20Mock.sol";

contract DeployAirdrop is Script {
    function run() external {
        // Copy the root you generated via the JS script here
        bytes32 merkleRoot = 0x3472cb0a280e3ab3fc954e3ae959e8d00c09351aef95cf4fd3eb4f55b60ab7f9;

        // set claim duration (e.g., 30 days)
        uint256 claimDuration = 30 days;

        vm.startBroadcast();

        // Create token (owner is tx sender)
        ERC20Mock token = new ERC20Mock(msg.sender);

        // Deploy airdrop contract
        Airdrop airdrop = new Airdrop(
            address(token),
            merkleRoot,
            claimDuration,
            msg.sender
        );

        // Mint tokens into the airdrop contract -- update to the sum printed by the generator
        uint256 totalAirdropAmount = 500; // replace with generator totalAmount
        token.mint(address(airdrop), totalAirdropAmount);

        vm.stopBroadcast();
    }
}
