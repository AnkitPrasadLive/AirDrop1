// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Airdrop is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    bytes32 public merkleRoot;
    uint256 public claimDeadline;

    mapping(uint256 => uint) private claimedBitMap;
    event Claimed(
        address indexed account,
        uint256 indexed index,
        uint256 indexed amount
    );
    event BatchClaimed(
        address indexed account,
        uint256 totalAmount,
        uint256[] indexes
    );
    event MerkleRootUpdated(bytes32 newRoot);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    error AlreadyClaimed(uint256 index);
    error InvalidProof();
    error ClaimPeriodOver();
    error NothingToWithdraw();

    constructor(
        address _token,
        bytes32 _merkleRoot,
        uint256 _claimDurationSeconds,
        address initialOwner
    ) Ownable(initialOwner) {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        claimDeadline = block.timestamp + _claimDurationSeconds;
    }

    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8; // index / 256
        uint256 bitIndex = index & 255; // index % 256
        uint256 word = claimedBitMap[wordIndex];
        return (word >> bitIndex) & 1 == 1;
    }

    function _setClaimed(uint256 index) internal {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        claimedBitMap[wordIndex] = claimedBitMap[wordIndex] | (1 << bitIndex);
    }

    function claim(
        uint256 index,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external nonReentrant {
        if (block.timestamp > claimDeadline) revert ClaimPeriodOver();
        if (isClaimed(index)) revert AlreadyClaimed(index);

        bytes32 leaf = keccak256(abi.encodePacked(index, msg.sender, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, leaf))
            revert InvalidProof();

        _setClaimed(index);
        token.transfer(msg.sender, amount);

        emit Claimed(msg.sender, index, amount);
    }

    function batchClaim(
        uint256[] calldata indexes,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external nonReentrant {
        if (block.timestamp > claimDeadline) revert ClaimPeriodOver();
        require(
            indexes.length == amounts.length && indexes.length == proofs.length,
            "Array length mismatch"
        );

        uint256 total = 0;
        uint256 len = indexes.length;

        for (uint256 i = 0; i < len; i++) {
            uint256 idx = indexes[i];

            if (isClaimed(idx)) continue; // skip already claimed indices

            bytes32 leaf = keccak256(
                abi.encodePacked(idx, msg.sender, amounts[i])
            );
            if (!MerkleProof.verify(proofs[i], merkleRoot, leaf))
                revert InvalidProof();

            _setClaimed(idx);
            total += amounts[i];
        }

        require(total > 0, "Nothing to claim");
        token.transfer(msg.sender, total);

        emit BatchClaimed(msg.sender, total, indexes);
    }

    /// @notice Owner can update Merkle root (useful for staged waves)
    function updateMerkleRoot(bytes32 newRoot) external onlyOwner {
        merkleRoot = newRoot;
        emit MerkleRootUpdated(newRoot);
    }

    /// @notice After the claim deadline, owner can withdraw leftover tokens
    function emergencyWithdraw(address to) external onlyOwner {
        if (block.timestamp <= claimDeadline) revert ClaimPeriodOver();
        uint256 bal = token.balanceOf(address(this));
        if (bal == 0) revert NothingToWithdraw();
        token.transfer(to, bal);
        emit EmergencyWithdraw(to, bal);
    }
}
