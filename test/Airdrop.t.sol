// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// 1. FIX: Correct import path for OpenZeppelin v5
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Gas-efficient Merkle Airdrop
/// @notice Index-based leaves: keccak256(abi.encodePacked(index, account, amount))
contract Airdrop is Ownable, ReentrancyGuard {
    IERC20 public immutable token;
    bytes32 public merkleRoot;
    uint256 public claimDeadline; // timestamp after which claims are closed

    // packed claimed bitmap: index => bit (index / 256 => word index)
    mapping(uint256 => uint256) private claimedBitMap;

    event Claimed(
        address indexed account,
        uint256 indexed index,
        uint256 amount
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
    )
        Ownable(initialOwner) // 2. FIX: Correct Ownable v5 constructor
    {
        token = IERC20(_token);
        merkleRoot = _merkleRoot;
        claimDeadline = block.timestamp + _claimDurationSeconds;
    }

    /// @notice Returns true if the `index` has been claimed.
    function isClaimed(uint256 index) public view returns (bool) {
        uint256 wordIndex = index >> 8; // index / 256
        uint256 bitIndex = index & 255; // index % 256
        uint256 word = claimedBitMap[wordIndex];
        return (word >> bitIndex) & 1 == 1;
    }

    /// @dev mark an index as claimed
    function _setClaimed(uint256 index) internal {
        uint256 wordIndex = index >> 8;
        uint256 bitIndex = index & 255;
        claimedBitMap[wordIndex] = claimedBitMap[wordIndex] | (1 << bitIndex);
    }

    /// @notice Claim a single index. `leaf` is computed as keccak256(abi.encodePacked(index, msg.sender, amount))
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

    /// @notice Batch claim several indexes for the same msg.sender
    /// @param indexes array of indexes
    /// @param amounts array of amounts (must match indexes length)
    /// @param proofs array of INDEPENDENT merkle proofs per index (each is bytes32[])
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
