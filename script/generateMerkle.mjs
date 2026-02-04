// FIXED FOR ETHERS v6
import { solidityPackedKeccak256 } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';
import fs from 'fs';

// === Edit this list for your airdrop ===
const airdropList = [
    { index: 0, address: '0x70997970C51812dc3A010C7d01b50e0d17dc79C8', amount: 100 },
    { index: 1, address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', amount: 150 },
    { index: 2, address: '0x90F79bf6EB2c4f870365E785982E1f101E93b906', amount: 200 },
    { index: 3, address: '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC', amount: 50 }
];

// Build leaves
const leaves = airdropList.map(item =>
    solidityPackedKeccak256(
        ['uint256', 'address', 'uint256'],
        [item.index, item.address, item.amount]
    )
);

// Build Merkle Tree
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
const root = tree.getHexRoot();

// Build proofs
const claims = airdropList.map(item => {
    const leaf = solidityPackedKeccak256(
        ['uint256', 'address', 'uint256'],
        [item.index, item.address, item.amount]
    );
    const proof = tree.getHexProof(leaf);
    return { ...item, leaf, proof };
});

const output = {
    root,
    claims,
    totalAmount: airdropList.reduce((sum, x) => sum + x.amount, 0)
};

console.log(JSON.stringify(output, null, 2));
fs.mkdirSync('out', { recursive: true });
fs.writeFileSync('out/airdrop.json', JSON.stringify(output, null, 2));
console.log('Saved output to out/airdrop.json');
