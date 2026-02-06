// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Airdrop is Ownable, ReentrancyGuard {
    IERC20 public token;
    bytes32 public merkleRoot;
    uint256 public claimDeadline;

    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(address indexed account, uint256 indexed index, uint256 indexed amount);
    event BatchClaimed(address indexed account, uint256 totalAmount, uint256[] indexes);
    event MerkleRootUpdated(bytes32 newRoot);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    error AlreadyClaimed(uint256 index);
    error InvalidProof();
    error ClaimPeriodOver();
    error NothingToWithdraw();

    constructor(address _token, bytes32 _merkleRoot, uint256 _claimDurationSeconds, address initialOwner)
        Ownable(initialOwner)
    {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        claimDeadline = block.timestamp + _claimDurationSeconds;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        uint256 word = claimedBitMap[wordIndex];
        uint256 mask = (1 << bitIndex);
        return (word & mask) == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        claimedBitMap[wordIndex] = claimedBitMap[wordIndex] | (1 << bitIndex);
    }

    function claim(uint256 index, uint256 amount, bytes32[] calldata merkleProof) external nonReentrant {
        if (block.timestamp > claimDeadline) revert ClaimPeriodOver();
        if (isClaimed(index)) revert AlreadyClaimed(index);

        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        _setClaimed(index);
        token.transfer(msg.sender, amount);

        emit Claimed(msg.sender, index, amount);
    }

    function batchClaim(uint256[] calldata indexes, uint256[] calldata amounts, bytes32[][] calldata proofs)
        external
        nonReentrant
    {
        if (block.timestamp > claimDeadline) revert ClaimPeriodOver();
        require(indexes.length == amounts.length && indexes.length == proofs.length, "Array length mismatch");

        uint256 total = 0;
        uint256 len = indexes.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 idx = indexes[i];

            if (isClaimed(idx)) continue;

            bytes32 leaf = keccak256(abi.encodePacked(idx, msg.sender, amounts[i]));
            if (!MerkleProof.verify(proofs[i], merkleRoot, leaf)) {
                revert InvalidProof();
            }

            _setClaimed(idx);
            total += amounts[i];
        }

        if (total > 0) {
            token.transfer(msg.sender, total);
            emit BatchClaimed(msg.sender, total, indexes);
        }
    }

    function updateMerkleRoot(bytes32 _newRoot) external onlyOwner {
        merkleRoot = _newRoot;
        emit MerkleRootUpdated(_newRoot);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        if (balance == 0) revert NothingToWithdraw();
        token.transfer(owner(), balance);
        emit EmergencyWithdraw(owner(), balance);
    }
}
