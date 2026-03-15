const fs = require('fs');
const path = require('path');

const MAX_RUNTIME_BYTES = 24576;
const TARGETS = ['AGIJobManagerPrime', 'AGIJobDiscoveryPrime'];

function sizeFromArtifact(contractName) {
  const artifactPath = path.resolve(
    __dirname,
    '..',
    'artifacts',
    'contracts',
    `${contractName}.sol`,
    `${contractName}.json`
  );

  if (!fs.existsSync(artifactPath)) {
    throw new Error(`Missing Hardhat artifact for ${contractName}: ${artifactPath}`);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const hex = (artifact.deployedBytecode || '').replace(/^0x/, '');
  if (!hex.length) {
    throw new Error(`Empty deployedBytecode for ${contractName}`);
  }
  return hex.length / 2;
}

const oversized = [];
for (const contractName of TARGETS) {
  const bytes = sizeFromArtifact(contractName);
  console.log(`${contractName} runtime bytecode size: ${bytes} bytes`);
  if (bytes >= MAX_RUNTIME_BYTES) {
    oversized.push({ contractName, bytes });
  }
}

if (oversized.length) {
  console.error(`Runtime bytecode must remain below EIP-170 limit (${MAX_RUNTIME_BYTES} bytes):`);
  for (const item of oversized) {
    console.error(`- ${item.contractName}: ${item.bytes}`);
  }
  process.exit(1);
}
