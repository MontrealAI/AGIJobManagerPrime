const assert = require('assert');
const fs = require('fs');
const path = require('path');

const MAX_DEPLOYED_BYTES = 24576;

function deployedSizeBytes(artifact) {
  const deployedBytecode =
    artifact.deployedBytecode || artifact.evm?.deployedBytecode?.object || '';
  const hex = deployedBytecode.startsWith('0x')
    ? deployedBytecode.slice(2)
    : deployedBytecode;
  return hex.length / 2;
}

function loadHardhatArtifact(contractFile, contractName) {
  const artifactPath = path.join(
    __dirname,
    '..',
    'hardhat',
    'artifacts',
    'contracts',
    contractFile,
    `${contractName}.json`
  );
  if (!fs.existsSync(artifactPath)) {
    throw new Error(
      `Missing Hardhat artifact: ${artifactPath}. Run \`cd hardhat && npm run compile\` first.`
    );
  }
  return JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
}

contract('Prime bytecode size guard', () => {
  it('keeps Prime runtime bytecode within the EIP-170 runtime size limit', () => {
    const checks = [
      ['AGIJobManagerPrime.sol', 'AGIJobManagerPrime'],
      ['AGIJobDiscoveryPrime.sol', 'AGIJobDiscoveryPrime'],
    ];

    checks.forEach(([contractFile, contractName]) => {
      const artifact = loadHardhatArtifact(contractFile, contractName);
      const sizeBytes = deployedSizeBytes(artifact);
      assert(
        sizeBytes <= MAX_DEPLOYED_BYTES,
        `${contractName} deployedBytecode size ${sizeBytes} bytes exceeds ${MAX_DEPLOYED_BYTES} bytes`
      );
    });
  });
});
