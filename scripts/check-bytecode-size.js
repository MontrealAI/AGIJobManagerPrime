const fs = require("fs");
const path = require("path");

const MAX_RUNTIME_BYTES = 24575;

function deployedSizeBytes(artifact) {
  const deployedBytecode =
    artifact.deployedBytecode || artifact.evm?.deployedBytecode?.object;
  if (!deployedBytecode) {
    throw new Error(
      `Missing deployedBytecode in artifact for ${artifact.contractName || "unknown"}`
    );
  }
  const hex = deployedBytecode.startsWith("0x")
    ? deployedBytecode.slice(2)
    : deployedBytecode;
  if (!hex) {
    throw new Error(
      `Empty deployedBytecode in artifact for ${artifact.contractName || "unknown"}`
    );
  }
  return hex.length / 2;
}

function loadJson(filePath) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing artifact: ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

const checks = [
  {
    name: "AGIJobManagerPrime",
    artifactPath: path.join(
      __dirname,
      "..",
      "hardhat",
      "artifacts",
      "contracts",
      "AGIJobManagerPrime.sol",
      "AGIJobManagerPrime.json"
    ),
  },
  {
    name: "AGIJobDiscoveryPrime",
    artifactPath: path.join(
      __dirname,
      "..",
      "hardhat",
      "artifacts",
      "contracts",
      "AGIJobDiscoveryPrime.sol",
      "AGIJobDiscoveryPrime.json"
    ),
  },
];

const oversized = [];
for (const check of checks) {
  const artifact = loadJson(check.artifactPath);
  const sizeBytes = deployedSizeBytes(artifact);
  console.log(`${check.name} runtime bytecode size: ${sizeBytes} bytes`);
  if (sizeBytes > MAX_RUNTIME_BYTES) {
    oversized.push({ name: check.name, sizeBytes });
  }
}

if (oversized.length) {
  console.error(`Runtime bytecode exceeds ${MAX_RUNTIME_BYTES} bytes:`);
  for (const { name, sizeBytes } of oversized) {
    console.error(`- ${name}: ${sizeBytes} bytes`);
  }
  process.exit(1);
}
