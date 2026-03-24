const hre = require("hardhat");

const { ethers, run, network } = hre;

const MAINNET_ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const MAINNET_NAME_WRAPPER = "0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401";
const MAINNET_PUBLIC_RESOLVER = "0xF29100983E058B709F3D539b0c765937B804AC15";
const DEFAULT_JOB_MANAGER = "";
const DEFAULT_ROOT_NAME = "alpha.jobs.agi.eth";
const MAINNET_SAFETY_PHRASE = "I_UNDERSTAND_MAINNET_DEPLOYMENT";
const MANAGER_MODE_NONE = "none";
const MANAGER_MODE_LEAN = "lean";
const MANAGER_MODE_RICH = "rich";

function env(k, d = "") {
  const v = process.env[k];
  return v === undefined || v === null || v === "" ? d : v;
}

function isTruthy(v) {
  return ["1", "true", "yes", "y", "on"].includes(String(v || "").trim().toLowerCase());
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function namehash(name) {
  if (!name || name.trim() === "") return "0x" + "00".repeat(32);
  return ethers.namehash(ethers.ensNormalize(name));
}

async function requireCode(addr, label) {
  if (!ethers.isAddress(addr)) {
    throw new Error(`${label} must be a valid address. Received: ${String(addr)}`);
  }
  const code = await ethers.provider.getCode(addr);
  if (!code || code === "0x") {
    throw new Error(`${label} has no deployed bytecode at ${addr}`);
  }
}

function parseIntEnv(key, fallback, min = 0) {
  const raw = env(key, "");
  if (raw === "") return fallback;
  const parsed = Number(raw);
  if (!Number.isInteger(parsed) || parsed < min) {
    throw new Error(`${key} must be an integer >= ${min}. Received: ${raw}`);
  }
  return parsed;
}

async function callUintIfPresent(address, signature) {
  const selector = ethers.id(signature).slice(0, 10);
  try {
    const raw = await ethers.provider.call({ to: address, data: selector });
    if (!raw || raw === "0x" || raw.length < 66) return { ok: false, value: 0n };
    return { ok: true, value: BigInt(raw) };
  } catch {
    return { ok: false, value: 0n };
  }
}

async function surfaceReadable(address, signature, args = []) {
  try {
    const iface = new ethers.Interface([`function ${signature}`]);
    const data = iface.encodeFunctionData(signature.split("(")[0], args);
    const raw = await ethers.provider.call({ to: address, data });
    return !!raw && raw !== "0x";
  } catch {
    return false;
  }
}

async function classifyManagerCompatibility(managerAddress, probeJobId = 1n) {
  const version = await callUintIfPresent(managerAddress, "ensJobManagerViewInterfaceVersion()");
  if (version.ok && version.value === 1n) {
    return {
      managerMode: MANAGER_MODE_RICH,
      managerViewCompatible: true,
      managerPushHookCompatible: true,
      keeperRequired: false,
      reason: "manager declares IAGIJobManagerPrimeViewV1",
    };
  }

  const richReadable = await Promise.all([
    surfaceReadable(
      managerAddress,
      "getJobCore(uint256) view returns (address,address,uint256,uint256,uint256,bool,bool,bool,uint8)",
      [probeJobId],
    ),
    surfaceReadable(managerAddress, "getJobSpecURI(uint256) view returns (string)", [probeJobId]),
    surfaceReadable(managerAddress, "getJobCompletionURI(uint256) view returns (string)", [probeJobId]),
  ]);
  if (richReadable.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_RICH,
      managerViewCompatible: true,
      managerPushHookCompatible: true,
      keeperRequired: false,
      reason: "manager rich view surfaces are readable",
    };
  }

  const leanReadable = await Promise.all([
    surfaceReadable(managerAddress, "jobEmployerOf(uint256) view returns (address)", [probeJobId]),
    surfaceReadable(managerAddress, "jobAssignedAgentOf(uint256) view returns (address)", [probeJobId]),
  ]);
  if (leanReadable.every(Boolean)) {
    return {
      managerMode: MANAGER_MODE_LEAN,
      managerViewCompatible: false,
      managerPushHookCompatible: true,
      keeperRequired: true,
      reason: "manager exposes lean fallback read surfaces only",
    };
  }

  return {
    managerMode: MANAGER_MODE_NONE,
    managerViewCompatible: false,
    managerPushHookCompatible: false,
    keeperRequired: true,
    reason: "manager does not expose rich or lean ENS-compatible read surfaces",
  };
}

async function main() {
  const net = await ethers.provider.getNetwork();
  const chainId = Number(net.chainId);

  const confirmations = parseIntEnv("CONFIRMATIONS", 3, 0);
  const verifyDelayMs = parseIntEnv("VERIFY_DELAY_MS", 3500, 0);

  if (chainId === 1) {
    const confirm = env("DEPLOY_CONFIRM_MAINNET");
    if (confirm !== MAINNET_SAFETY_PHRASE) {
      throw new Error(
        `Refusing chainId 1 deploy without DEPLOY_CONFIRM_MAINNET=${MAINNET_SAFETY_PHRASE}`,
      );
    }
    if (!env("JOB_MANAGER")) {
      throw new Error('Refusing mainnet ENSJobPages deploy without an explicit JOB_MANAGER environment variable.');
    }
  }

  const ensRegistry = env("ENS_REGISTRY", MAINNET_ENS_REGISTRY);
  const nameWrapper = env("NAME_WRAPPER", MAINNET_NAME_WRAPPER);
  const publicResolver = env("PUBLIC_RESOLVER", MAINNET_PUBLIC_RESOLVER);
  const jobsRootNameInput = env("JOBS_ROOT_NAME", DEFAULT_ROOT_NAME);
  const jobsRootName = ethers.ensNormalize(jobsRootNameInput);
  const computedJobsRootNode = namehash(jobsRootName);
  const jobsRootNode = env("JOBS_ROOT_NODE", computedJobsRootNode);
  const jobManager = chainId === 1 ? env("JOB_MANAGER", "") : env("JOB_MANAGER", DEFAULT_JOB_MANAGER);

  const verify = isTruthy(env("VERIFY"));
  const lockConfig = isTruthy(env("LOCK_CONFIG"));
  const dryRun = isTruthy(env("DRY_RUN"));

  const ownerOverride = env("NEW_OWNER") || env("FINAL_OWNER") || "";

  if (ownerOverride && !ethers.isAddress(ownerOverride)) {
    throw new Error(`Resolved owner override is not a valid address: ${ownerOverride}`);
  }

  if (!ethers.isHexString(jobsRootNode, 32)) {
    throw new Error(`JOBS_ROOT_NODE must be bytes32. Received: ${jobsRootNode}`);
  }
  if (jobsRootNode.toLowerCase() !== computedJobsRootNode.toLowerCase()) {
    throw new Error(
      `JOBS_ROOT_NODE mismatch for JOBS_ROOT_NAME (${jobsRootName}). Expected ${computedJobsRootNode}, got ${jobsRootNode}`,
    );
  }

  await requireCode(ensRegistry, "ENS_REGISTRY");
  await requireCode(publicResolver, "PUBLIC_RESOLVER");
  await requireCode(jobManager, "JOB_MANAGER");
  if (nameWrapper.toLowerCase() !== ethers.ZeroAddress.toLowerCase()) {
    await requireCode(nameWrapper, "NAME_WRAPPER");
  }

  const managerCompatibility = await classifyManagerCompatibility(jobManager, 1n);

  const [deployer] = await ethers.getSigners();
  const ens = await ethers.getContractAt(
    ["function owner(bytes32 node) view returns (address)"],
    ensRegistry,
    deployer,
  );
  const currentRootOwner = await ens.owner(jobsRootNode);

  console.log("\n=== ENSJobPages deployment plan ===");
  console.log("network:", network.name);
  console.log("chainId:", chainId);
  console.log("deployer:", deployer.address);
  console.log("ENS_REGISTRY:", ensRegistry);
  console.log("NAME_WRAPPER:", nameWrapper);
  console.log("PUBLIC_RESOLVER:", publicResolver);
  console.log("JOBS_ROOT_NAME:", jobsRootName);
  console.log("JOBS_ROOT_NODE:", jobsRootNode);
  console.log("current root owner:", currentRootOwner);
  console.log("root tokenId decimal:", BigInt(jobsRootNode).toString());
  console.log("JOB_MANAGER:", jobManager);
  console.log("managerMode:", managerCompatibility.managerMode);
  console.log("managerViewCompatible:", managerCompatibility.managerViewCompatible);
  console.log("managerPushHookCompatible:", managerCompatibility.managerPushHookCompatible);
  console.log("keeperRequired:", managerCompatibility.keeperRequired);
  console.log("managerCompatibilityReason:", managerCompatibility.reason);
  console.log("LOCK_CONFIG:", lockConfig);
  console.log("resolved owner override:", ownerOverride || "(none)");
  console.log("VERIFY:", verify);
  console.log("CONFIRMATIONS:", confirmations);
  console.log("VERIFY_DELAY_MS:", verifyDelayMs);
  console.log("DRY_RUN:", dryRun);

  if (dryRun) {
    console.log("\nDRY_RUN enabled. Exiting before broadcasting transactions.");
    return;
  }

  const constructorArgs = [ensRegistry, nameWrapper, publicResolver, jobsRootNode, jobsRootName];
  const factory = await ethers.getContractFactory("ENSJobPages");
  const ensJobPages = await factory.deploy(...constructorArgs);
  await ensJobPages.waitForDeployment();
  const deploymentTx = ensJobPages.deploymentTransaction();
  if (deploymentTx && confirmations > 0) {
    await deploymentTx.wait(confirmations);
  }

  const ensJobPagesAddress = await ensJobPages.getAddress();
  console.log("\nENSJobPages deployed:", ensJobPagesAddress);

  console.log("Setting job manager...");
  const setJobManagerTx = await ensJobPages.setJobManager(jobManager);
  await setJobManagerTx.wait(confirmations);

  const validationMask = await ensJobPages.validateConfiguration();
  console.log("validateConfiguration mask immediately after deploy:", validationMask.toString());
  if (validationMask !== 0n) {
    console.log(
      "Non-zero validation is expected before wrapped-root approval / final cutover when the root is owned by NameWrapper.",
    );
  }

  if (lockConfig) {
    const allowKeeperLock = isTruthy(env("ALLOW_LOCK_WITH_KEEPER", "0"));
    if (!managerCompatibility.managerPushHookCompatible || managerCompatibility.managerMode === MANAGER_MODE_NONE) {
      throw new Error(
        `LOCK_CONFIG refused because manager compatibility is unsafe (${managerCompatibility.managerMode}).`,
      );
    }
    if (managerCompatibility.keeperRequired && !allowKeeperLock) {
      throw new Error(
        "LOCK_CONFIG refused in keeper-required mode. Set ALLOW_LOCK_WITH_KEEPER=1 only after keeper/repair runbooks are operational.",
      );
    }
    if (validationMask !== 0n) {
      throw new Error(
        `LOCK_CONFIG requested before ENSJobPages validateConfiguration() reached zero. Current bitmask: ${validationMask.toString()}`,
      );
    }
    console.log("Locking configuration...");
    const lockTx = await ensJobPages.lockConfiguration();
    await lockTx.wait(confirmations);
  }

  if (ownerOverride) {
    console.log("Transferring ownership to:", ownerOverride);
    const transferTx = await ensJobPages.transferOwnership(ownerOverride);
    await transferTx.wait(confirmations);
  }

  if (verify && network.name !== "hardhat") {
    try {
      console.log(`\nWaiting ${verifyDelayMs}ms before verify...`);
      await sleep(verifyDelayMs);
      await run("verify:verify", {
        address: ensJobPagesAddress,
        constructorArguments: constructorArgs,
      });
      console.log("Verification submitted.");
    } catch (err) {
      console.warn("Verification skipped/failed:", err && err.message ? err.message : err);
    }
  }

  console.log("\nManual next steps (not automated):");
  console.log("1) Wrapped-root owner must keep NameWrapper approvalForAll(newEnsJobPages)=true before cutover.");
  console.log("2) Re-run ENSJobPages.validateConfiguration(); continue only once the bitmask is 0.");
  console.log("3) Confirm manager compatibility mode above; if keeperRequired=true, stage keeper replay/repair before lock+cutover.");
  console.log("4) AGIJobManagerPrime owner calls setEnsJobPages(newEnsJobPages) after validation/preflight is green.");
  console.log("5) Run one canary job end-to-end and inspector verification before broad traffic.");
  console.log("6) If rollback is required, repoint AGIJobManagerPrime.setEnsJobPages(previousTarget) and use explicit ENSJobPages repair/replay calls for affected jobs.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
