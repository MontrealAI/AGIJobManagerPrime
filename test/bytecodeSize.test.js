const assert = require("assert");
const fs = require("fs");
const path = require("path");

const MAX_DEPLOYED_BYTES = 24576;

function deployedSizeBytes(artifact) {
  const deployedBytecode =
    artifact.deployedBytecode || artifact.evm?.deployedBytecode?.object || "";
  const hex = deployedBytecode.startsWith("0x")
    ? deployedBytecode.slice(2)
    : deployedBytecode;
  return hex.length / 2;
}

function loadLegacyArtifact(name) {
  const artifactPath = path.join(
    __dirname,
    "..",
    "build",
    "contracts",
    `${name}.json`
  );
  if (!fs.existsSync(artifactPath)) {
    return null;
  }
  return require(artifactPath);
}

function loadHardhatPrimeArtifact(contractFile, contractName) {
  const artifactPath = path.join(
    __dirname,
    "..",
    "hardhat",
    "artifacts",
    "contracts",
    contractFile,
    `${contractName}.json`
  );
  if (!fs.existsSync(artifactPath)) {
    return null;
  }
  return JSON.parse(fs.readFileSync(artifactPath, "utf8"));
}

contract("Bytecode size guard", () => {
  it("keeps deployed bytecode within the EIP-170 runtime size limit", () => {
    const checks = [
      ["AGIJobManager (legacy reference)", loadLegacyArtifact("AGIJobManager")],
      [
        "AGIJobManagerPrime",
        loadHardhatPrimeArtifact("AGIJobManagerPrime.sol", "AGIJobManagerPrime"),
      ],
      [
        "AGIJobDiscoveryPrime",
        loadHardhatPrimeArtifact("AGIJobDiscoveryPrime.sol", "AGIJobDiscoveryPrime"),
      ],
    ];

    checks.forEach(([name, artifact]) => {
      if (!artifact) return;
      const sizeBytes = deployedSizeBytes(artifact);
      assert(
        sizeBytes <= MAX_DEPLOYED_BYTES,
        `${name} deployedBytecode size ${sizeBytes} bytes exceeds ${MAX_DEPLOYED_BYTES} bytes`
      );
    });
  });
});
