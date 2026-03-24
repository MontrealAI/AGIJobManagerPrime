const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const MAX_RUNTIME_BYTES = 24576;
const MAX_INITCODE_BYTES = 49152;
const PRIME_BASELINE_PATH = path.join(
  __dirname,
  "..",
  "hardhat",
  "bytecode-baseline.json"
);

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

function initcodeSizeBytes(artifact) {
  const bytecode = artifact.bytecode || artifact.evm?.bytecode?.object;
  if (!bytecode) {
    throw new Error(
      `Missing bytecode in artifact for ${artifact.contractName || "unknown"}`
    );
  }
  const hex = bytecode.startsWith("0x") ? bytecode.slice(2) : bytecode;
  if (!hex) {
    throw new Error(`Empty bytecode in artifact for ${artifact.contractName || "unknown"}`);
  }
  return hex.length / 2;
}

function hexValue(value) {
  if (!value) return "";
  return value.startsWith("0x") ? value.slice(2) : value;
}

function sha256Hex(hex) {
  return require("crypto").createHash("sha256").update(Buffer.from(hex, "hex")).digest("hex");
}

function artifactPathFor(contractFile, contractName) {
  return path.join(
    __dirname,
    "..",
    "hardhat",
    "artifacts",
    "contracts",
    contractFile,
    `${contractName}.json`
  );
}

function ensurePrimeArtifacts(checks) {
  const missing = checks.filter((check) => !fs.existsSync(check.artifactPath));
  if (!missing.length) {
    return;
  }

  console.log("Hardhat Prime artifacts missing; running compile...");
  execSync("npm run compile", {
    cwd: path.join(__dirname, "..", "hardhat"),
    stdio: "inherit",
  });
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
    artifactPath: artifactPathFor("AGIJobManagerPrime.sol", "AGIJobManagerPrime"),
    enforce: true,
  },
  {
    name: "AGIJobDiscoveryPrime",
    artifactPath: artifactPathFor("AGIJobDiscoveryPrime.sol", "AGIJobDiscoveryPrime"),
    enforce: true,
  },
  {
    name: "AGIJobCompletionNFT",
    artifactPath: artifactPathFor("periphery/AGIJobCompletionNFT.sol", "AGIJobCompletionNFT"),
    enforce: true,
  },
  {
    name: "ENSJobPages",
    artifactPath: artifactPathFor("ens/ENSJobPages.sol", "ENSJobPages"),
    enforce: true,
  },
  {
    name: "ENSJobPagesInspector",
    artifactPath: artifactPathFor("ens/ENSJobPagesInspector.sol", "ENSJobPagesInspector"),
    enforce: true,
  },
];

ensurePrimeArtifacts(checks);

const oversizedRuntime = [];
const oversizedInitcode = [];
const baselineMismatches = [];
const primeBaseline = fs.existsSync(PRIME_BASELINE_PATH)
  ? JSON.parse(fs.readFileSync(PRIME_BASELINE_PATH, "utf8"))
  : null;
for (const check of checks) {
  const artifact = loadJson(check.artifactPath);
  const runtimeSizeBytes = deployedSizeBytes(artifact);
  const initcodeSizeBytesValue = initcodeSizeBytes(artifact);
  const runtimeHex = hexValue(artifact.deployedBytecode || artifact.evm?.deployedBytecode?.object);
  const initcodeHex = hexValue(artifact.bytecode || artifact.evm?.bytecode?.object);

  console.log(`${check.name} runtime bytecode size: ${runtimeSizeBytes} bytes`);
  console.log(`${check.name} initcode size: ${initcodeSizeBytesValue} bytes`);

  if (check.name === "AGIJobManagerPrime" && primeBaseline?.AGIJobManagerPrime) {
    const baseline = primeBaseline.AGIJobManagerPrime;
    const runtimeHash = sha256Hex(runtimeHex);
    const initcodeHash = sha256Hex(initcodeHex);
    if (
      runtimeSizeBytes !== baseline.runtimeBytes ||
      initcodeSizeBytesValue !== baseline.initcodeBytes ||
      runtimeHash !== baseline.runtimeSha256 ||
      initcodeHash !== baseline.initcodeSha256
    ) {
      baselineMismatches.push({
        name: check.name,
        runtimeSizeBytes,
        initcodeSizeBytesValue,
        runtimeHash,
        initcodeHash,
        baseline,
      });
    }
    continue;
  }

  if (runtimeSizeBytes > MAX_RUNTIME_BYTES && check.enforce) {
    oversizedRuntime.push({ name: check.name, sizeBytes: runtimeSizeBytes });
  }
  if (initcodeSizeBytesValue > MAX_INITCODE_BYTES && check.enforce) {
    oversizedInitcode.push({ name: check.name, sizeBytes: initcodeSizeBytesValue });
  }
}

if (oversizedRuntime.length || oversizedInitcode.length || baselineMismatches.length) {
  if (oversizedRuntime.length) {
    console.error(`Runtime bytecode exceeds ${MAX_RUNTIME_BYTES} bytes:`);
    for (const { name, sizeBytes } of oversizedRuntime) {
      console.error(`- ${name}: ${sizeBytes} bytes`);
    }
  }

  if (oversizedInitcode.length) {
    console.error(`Initcode exceeds ${MAX_INITCODE_BYTES} bytes:`);
    for (const { name, sizeBytes } of oversizedInitcode) {
      console.error(`- ${name}: ${sizeBytes} bytes`);
    }
  }

  if (baselineMismatches.length) {
    console.error("Prime bytecode no longer matches the restored baseline:");
    for (const mismatch of baselineMismatches) {
      console.error(`- ${mismatch.name}:`);
      console.error(
        `  runtime ${mismatch.runtimeSizeBytes} bytes / sha256 ${mismatch.runtimeHash} (expected ${mismatch.baseline.runtimeBytes} / ${mismatch.baseline.runtimeSha256})`
      );
      console.error(
        `  initcode ${mismatch.initcodeSizeBytesValue} bytes / sha256 ${mismatch.initcodeHash} (expected ${mismatch.baseline.initcodeBytes} / ${mismatch.baseline.initcodeSha256})`
      );
    }
  }

  process.exit(1);
}

for (const check of checks) {
  const artifact = loadJson(check.artifactPath);
  const runtimeSizeBytes = deployedSizeBytes(artifact);
  const initcodeSizeBytesValue = initcodeSizeBytes(artifact);
  console.log(`${check.name} runtime headroom: ${MAX_RUNTIME_BYTES - runtimeSizeBytes} bytes`);
  console.log(`${check.name} initcode headroom: ${MAX_INITCODE_BYTES - initcodeSizeBytesValue} bytes`);
}
