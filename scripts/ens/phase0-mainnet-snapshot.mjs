import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { ethers } = require("../../hardhat/node_modules/ethers");

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..", "..");

const MAINNET_RPC_URL = (process.env.MAINNET_RPC_URL || "https://ethereum-rpc.publicnode.com").trim();
const DEFAULT_MANAGER = "0xB3AAeb69b630f0299791679c063d68d6687481d1";
const DEFAULT_ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const DEFAULT_NAME_WRAPPER = "0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401";
const DEFAULT_ROOT_NAME = "alpha.jobs.agi.eth";
const MAX_DEFAULT_JOBS = 64;

const MANAGER_ABI = [
  "function ensJobPages() view returns (address)",
  "function nextJobId() view returns (uint256)",
  "function getJobCore(uint256) view returns (address employer,address assignedAgent,uint256 payout,uint256 duration,uint256 assignedAt,bool completed,bool disputed,bool expired,uint8 agentPayoutPct)",
  "function getJobSpecURI(uint256) view returns (string)",
  "function getJobCompletionURI(uint256) view returns (string)",
];

const ENS_JOB_PAGES_ABI = [
  "function owner() view returns (address)",
  "function jobManager() view returns (address)",
  "function ens() view returns (address)",
  "function nameWrapper() view returns (address)",
  "function publicResolver() view returns (address)",
  "function jobsRootNode() view returns (bytes32)",
  "function jobsRootName() view returns (string)",
  "function jobLabelPrefix() view returns (string)",
  "function configLocked() view returns (bool)",
  "function validateConfiguration() view returns (uint256)",
  "function jobLabelSnapshot(uint256) view returns (bool,string)",
  "function jobEnsLabel(uint256) view returns (string)",
  "function jobEnsName(uint256) view returns (string)",
  "function jobEnsStatus(uint256) view returns (string,string,string,bytes32,bool,bool,address,address,uint256)",
  "function jobEnsIssued(uint256) view returns (bool)",
  "function jobEnsReady(uint256) view returns (bool)",
];

const ENS_REGISTRY_ABI = [
  "function owner(bytes32) view returns (address)",
  "function resolver(bytes32) view returns (address)",
];

const NAME_WRAPPER_ABI = [
  "function ownerOf(uint256) view returns (address)",
  "function getApproved(uint256) view returns (address)",
  "function isApprovedForAll(address,address) view returns (bool)",
];

const PUBLIC_RESOLVER_ABI = [
  "function text(bytes32,string) view returns (string)",
  "function isAuthorised(bytes32,address) view returns (bool)",
];

function arg(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((value) => value.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function nowIso() {
  return new Date().toISOString();
}

function short(addr) {
  return typeof addr === "string" ? addr.toLowerCase() : String(addr);
}

function asNumber(value) {
  return Number(typeof value === "bigint" ? value : BigInt(value));
}

async function safeCall(label, fn, fallback = null) {
  try {
    return await fn();
  } catch (error) {
    return {
      __error: true,
      label,
      message: error?.shortMessage || error?.message || String(error),
      fallback,
    };
  }
}

function unwrap(value, fallback = null) {
  return value && value.__error ? (value.fallback ?? fallback) : value;
}

function statusMaskIncludes(mask, bit) {
  return (BigInt(mask) & BigInt(bit)) !== 0n;
}

async function main() {
  const provider = new ethers.JsonRpcProvider(MAINNET_RPC_URL, 1, { staticNetwork: true });
  const managerAddress = arg("manager", DEFAULT_MANAGER);
  const ensRegistryAddress = arg("ens", DEFAULT_ENS_REGISTRY);
  const nameWrapperAddress = arg("wrapper", DEFAULT_NAME_WRAPPER);
  const rootName = ethers.ensNormalize(arg("root-name", DEFAULT_ROOT_NAME));
  const maxJobs = Number(arg("max-jobs", String(MAX_DEFAULT_JOBS)));
  const outJsonRel = arg(
    "out-json",
    "docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-2026-03-22.json",
  );
  const outMdRel = arg(
    "out-md",
    "docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-2026-03-22.md",
  );

  const ensRegistry = new ethers.Contract(ensRegistryAddress, ENS_REGISTRY_ABI, provider);
  const nameWrapper = new ethers.Contract(nameWrapperAddress, NAME_WRAPPER_ABI, provider);
  const manager = new ethers.Contract(managerAddress, MANAGER_ABI, provider);

  const network = await provider.getNetwork();
  const latestBlock = await provider.getBlock("latest");
  const rootNode = ethers.namehash(rootName);
  const ensJobPagesAddress = unwrap(await safeCall("manager.ensJobPages", () => manager.ensJobPages()), ethers.ZeroAddress);
  const nextJobIdRaw = unwrap(await safeCall("manager.nextJobId", () => manager.nextJobId()), 0n);
  const nextJobId = asNumber(nextJobIdRaw);
  const rootOwner = unwrap(await safeCall("ens.owner(root)", () => ensRegistry.owner(rootNode)), ethers.ZeroAddress);
  const rootResolver = unwrap(await safeCall("ens.resolver(root)", () => ensRegistry.resolver(rootNode)), ethers.ZeroAddress);

  let helper = null;
  let helperConfig = null;
  if (ensJobPagesAddress !== ethers.ZeroAddress) {
    helper = new ethers.Contract(ensJobPagesAddress, ENS_JOB_PAGES_ABI, provider);
    helperConfig = {
      owner: unwrap(await safeCall("helper.owner", () => helper.owner()), ethers.ZeroAddress),
      jobManager: unwrap(await safeCall("helper.jobManager", () => helper.jobManager()), ethers.ZeroAddress),
      ens: unwrap(await safeCall("helper.ens", () => helper.ens()), ethers.ZeroAddress),
      nameWrapper: unwrap(await safeCall("helper.nameWrapper", () => helper.nameWrapper()), ethers.ZeroAddress),
      publicResolver: unwrap(await safeCall("helper.publicResolver", () => helper.publicResolver()), ethers.ZeroAddress),
      jobsRootNode: unwrap(await safeCall("helper.jobsRootNode", () => helper.jobsRootNode()), rootNode),
      jobsRootName: unwrap(await safeCall("helper.jobsRootName", () => helper.jobsRootName()), rootName),
      jobLabelPrefix: unwrap(await safeCall("helper.jobLabelPrefix", () => helper.jobLabelPrefix()), "agijob-"),
      configLocked: unwrap(await safeCall("helper.configLocked", () => helper.configLocked()), false),
      validateConfiguration: String(
        unwrap(await safeCall("helper.validateConfiguration", () => helper.validateConfiguration()), 0n),
      ),
    };
  }

  const wrapperOwner = unwrap(
    await safeCall("nameWrapper.ownerOf(root)", () => nameWrapper.ownerOf(BigInt(rootNode))),
    ethers.ZeroAddress,
  );
  const wrapperApprovalForHelper =
    ensJobPagesAddress === ethers.ZeroAddress
      ? false
      : unwrap(
          await safeCall("nameWrapper.isApprovedForAll", () =>
            nameWrapper.isApprovedForAll(wrapperOwner, ensJobPagesAddress),
          ),
          false,
        );
  const wrapperApprovedAddress =
    ensJobPagesAddress === ethers.ZeroAddress
      ? ethers.ZeroAddress
      : unwrap(
          await safeCall("nameWrapper.getApproved", () => nameWrapper.getApproved(BigInt(rootNode))),
          ethers.ZeroAddress,
        );

  const scanCount = Math.min(nextJobId, maxJobs);
  const jobs = [];

  for (let jobId = 0; jobId < scanCount; jobId += 1) {
    const core = unwrap(await safeCall(`manager.getJobCore(${jobId})`, () => manager.getJobCore(jobId)), null);
    if (!core) continue;

    const specURI = unwrap(await safeCall(`manager.getJobSpecURI(${jobId})`, () => manager.getJobSpecURI(jobId)), "");
    const completionURI = unwrap(
      await safeCall(`manager.getJobCompletionURI(${jobId})`, () => manager.getJobCompletionURI(jobId)),
      "",
    );

    const labelSnapshot = helper
      ? unwrap(await safeCall(`helper.jobLabelSnapshot(${jobId})`, () => helper.jobLabelSnapshot(jobId)), [false, ""])
      : [false, ""];
    const jobEnsStatus = helper
      ? unwrap(await safeCall(`helper.jobEnsStatus(${jobId})`, () => helper.jobEnsStatus(jobId)), null)
      : null;
    const issued = helper
      ? unwrap(await safeCall(`helper.jobEnsIssued(${jobId})`, () => helper.jobEnsIssued(jobId)), false)
      : false;
    const ready = helper
      ? unwrap(await safeCall(`helper.jobEnsReady(${jobId})`, () => helper.jobEnsReady(jobId)), false)
      : false;

    const label = jobEnsStatus?.[0] || labelSnapshot?.[1] || "";
    const name = jobEnsStatus?.[1] || (label ? `${label}.${rootName}` : "");
    const node =
      jobEnsStatus?.[3] ||
      (label ? ethers.solidityPackedKeccak256(["bytes32", "bytes32"], [rootNode, ethers.id(label)]) : ethers.ZeroHash);
    const nodeOwner =
      node && node !== ethers.ZeroHash
        ? unwrap(await safeCall(`ens.owner(job:${jobId})`, () => ensRegistry.owner(node)), ethers.ZeroAddress)
        : ethers.ZeroAddress;
    const nodeResolver =
      node && node !== ethers.ZeroHash
        ? unwrap(await safeCall(`ens.resolver(job:${jobId})`, () => ensRegistry.resolver(node)), ethers.ZeroAddress)
        : ethers.ZeroAddress;

    let resolverCompletion = "";
    let resolverSpec = "";
    if (nodeResolver !== ethers.ZeroAddress) {
      const resolver = new ethers.Contract(nodeResolver, PUBLIC_RESOLVER_ABI, provider);
      resolverSpec = unwrap(
        await safeCall(`resolver.text(spec:${jobId})`, () => resolver.text(node, "agijobs.spec.public")),
        "",
      );
      resolverCompletion = unwrap(
        await safeCall(`resolver.text(completion:${jobId})`, () =>
          resolver.text(node, "agijobs.completion.public"),
        ),
        "",
      );
    }

    const needsLabelSnapshot = labelSnapshot && !labelSnapshot[0];
    const needsResolver = label && nodeOwner !== ethers.ZeroAddress && nodeResolver === ethers.ZeroAddress;
    const needsSpecRepair = specURI && resolverSpec !== specURI;
    const needsCompletionRepair =
      Boolean(completionURI) && (!ready || resolverCompletion !== completionURI);
    const lifecycle = {
      employer: core.employer,
      assignedAgent: core.assignedAgent,
      completed: core.completed,
      disputed: core.disputed,
      expired: core.expired,
    };

    jobs.push({
      jobId,
      labelSnapshot: {
        isSet: Boolean(labelSnapshot?.[0]),
        label: labelSnapshot?.[1] || "",
      },
      ens: {
        label,
        name,
        uri: jobEnsStatus?.[2] || (name ? `ens://${name}` : ""),
        node,
        nodeOwner,
        nodeResolver,
        issued,
        ready,
      },
      lifecycle,
      uris: {
        specURI,
        completionURI,
        resolverSpec,
        resolverCompletion,
      },
      repairFlags: {
        needsLabelSnapshot,
        needsResolver,
        needsSpecRepair,
        needsCompletionRepair,
      },
    });
  }

  const repairSummary = {
    totalScannedJobs: scanCount,
    needsLabelSnapshot: jobs.filter((job) => job.repairFlags.needsLabelSnapshot).map((job) => job.jobId),
    needsResolver: jobs.filter((job) => job.repairFlags.needsResolver).map((job) => job.jobId),
    needsSpecRepair: jobs.filter((job) => job.repairFlags.needsSpecRepair).map((job) => job.jobId),
    needsCompletionRepair: jobs.filter((job) => job.repairFlags.needsCompletionRepair).map((job) => job.jobId),
  };

  const payload = {
    schema: "agijobmanager.ens.phase0.v1",
    generatedAtUtc: nowIso(),
    rpcSource: MAINNET_RPC_URL,
    chain: {
      chainId: Number(network.chainId),
      blockNumber: latestBlock.number,
      blockHash: latestBlock.hash,
      blockTimestamp: latestBlock.timestamp,
    },
    manager: {
      address: managerAddress,
      ensJobPages: ensJobPagesAddress,
      nextJobId,
    },
    root: {
      rootName,
      rootNode,
      ensRegistry: ensRegistryAddress,
      nameWrapper: nameWrapperAddress,
      rootOwner,
      rootResolver,
      wrapped: short(rootOwner) === short(nameWrapperAddress),
      wrapperOwner,
      wrapperApprovedAddress,
      wrapperApprovalForHelper,
    },
    helperConfig,
    repairSummary,
    jobs,
    notes: [
      "Phase 0 is read-only: authority snapshot + inventory + repair candidate classification from live mainnet state.",
      "needsLabelSnapshot indicates the active ENSJobPages surface did not report a snapshotted exact label for the job.",
      "needsResolver/spec/completion flags indicate likely candidates for migrateLegacyWrappedJobPage() or syncEnsForJob() after cutover.",
    ],
  };

  const outJson = path.join(repoRoot, outJsonRel);
  const outMd = path.join(repoRoot, outMdRel);
  fs.mkdirSync(path.dirname(outJson), { recursive: true });
  fs.mkdirSync(path.dirname(outMd), { recursive: true });
  fs.writeFileSync(outJson, `${JSON.stringify(payload, null, 2)}\n`);

  const lines = [
    "# ENS Phase 0 mainnet snapshot",
    "",
    `- Generated at (UTC): \`${payload.generatedAtUtc}\``,
    `- RPC source: \`${payload.rpcSource}\``,
    `- Chain / block: mainnet (\`${payload.chain.chainId}\`) at block \`${payload.chain.blockNumber}\``,
    `- Manager: \`${payload.manager.address}\``,
    `- ENSJobPages target: \`${payload.manager.ensJobPages}\``,
    `- Root: \`${payload.root.rootName}\` / \`${payload.root.rootNode}\``,
    "",
    "## Authority snapshot",
    "",
    `- ENS root owner: \`${payload.root.rootOwner}\``,
    `- NameWrapper ownerOf(root): \`${payload.root.wrapperOwner}\``,
    `- NameWrapper getApproved(root): \`${payload.root.wrapperApprovedAddress}\``,
    `- NameWrapper isApprovedForAll(rootOwner, ensJobPages): \`${payload.root.wrapperApprovalForHelper}\``,
    "",
    "## Active ENSJobPages config",
    "",
    ...Object.entries(payload.helperConfig || {}).map(([key, value]) => `- ${key}: \`${String(value)}\``),
    "",
    "## Repair summary",
    "",
    `- Scanned jobs: \`${payload.repairSummary.totalScannedJobs}\` of nextJobId \`${payload.manager.nextJobId}\``,
    `- needsLabelSnapshot: \`${payload.repairSummary.needsLabelSnapshot.join(", ") || "none"}\``,
    `- needsResolver: \`${payload.repairSummary.needsResolver.join(", ") || "none"}\``,
    `- needsSpecRepair: \`${payload.repairSummary.needsSpecRepair.join(", ") || "none"}\``,
    `- needsCompletionRepair: \`${payload.repairSummary.needsCompletionRepair.join(", ") || "none"}\``,
    "",
    "## Job inventory",
    "",
    "| jobId | label | node owner | node resolver | issued | ready | repair flags |",
    "| --- | --- | --- | --- | --- | --- | --- |",
    ...payload.jobs.map((job) => {
      const flags = Object.entries(job.repairFlags)
        .filter(([, enabled]) => enabled)
        .map(([key]) => key)
        .join(", ") || "none";
      return `| ${job.jobId} | \`${job.ens.label || "(none)"}\` | \`${job.ens.nodeOwner}\` | \`${job.ens.nodeResolver}\` | ${job.ens.issued} | ${job.ens.ready} | ${flags} |`;
    }),
    "",
  ];

  fs.writeFileSync(outMd, `${lines.join("\n")}\n`);
  console.log(`Wrote ${path.relative(repoRoot, outJson)}`);
  console.log(`Wrote ${path.relative(repoRoot, outMd)}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
