#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');

const OUTPUT = path.resolve('scripts/ens/output/inventory-job-pages.json');
const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const PRIME = (process.env.AGI_JOB_MANAGER_PRIME || '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const ENS_REGISTRY = (process.env.ENS_REGISTRY || '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e').trim();
const MAX_JOBS = Number(process.env.MAX_JOBS || '128');

const PRIME_ABI = [
  'function nextJobId() view returns (uint256)',
  'function getJobCore(uint256) view returns (address employer,address assignedAgent,uint256 payout,uint256 duration,uint256 assignedAt,bool completed,bool disputed,bool expired,uint8 agentPayoutPct)',
  'function getJobSpecURI(uint256) view returns (string)',
  'function getJobCompletionURI(uint256) view returns (string)',
  'event JobCreated(uint256 indexed jobId,address indexed employer,uint256 payout,uint256 duration,string jobSpecURI,uint8 intakeMode,bytes32 perJobAgentRoot,string details)',
  'event JobCompletionRequested(uint256 indexed jobId,address indexed agent,string jobCompletionURI)',
];

const PAGES_ABI = [
  'function previewJobEnsLabel(uint256) view returns (string)',
  'function previewJobEnsName(uint256) view returns (string)',
  'function previewJobEnsURI(uint256) view returns (string)',
  'function previewJobEnsNode(uint256) view returns (bytes32)',
  'function effectiveJobEnsLabel(uint256) view returns (string)',
  'function effectiveJobEnsName(uint256) view returns (string)',
  'function effectiveJobEnsURI(uint256) view returns (string)',
  'function effectiveJobEnsNode(uint256) view returns (bytes32)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function configurationStatus() view returns (bool,bool,bool,bool,bool,bool,bool,bool,bool,bool,uint256)',
  'function publicResolver() view returns (address)',
  'function nameWrapper() view returns (address)',
  'function jobsRootNode() view returns (bytes32)',
];

const ENS_ABI = [
  'function owner(bytes32) view returns (address)',
  'function resolver(bytes32) view returns (address)',
];

const WRAPPER_ABI = [
  'function ownerOf(uint256) view returns (address)',
];

const RESOLVER_ABI = [
  'function text(bytes32,string) view returns (string)',
  'function isAuthorised(bytes32,address) view returns (bool)',
];

async function safe(fn, fallback = null) {
  try { return await fn(); } catch { return fallback; }
}

function classify(job) {
  const tags = [];
  if (!job.labelSnapshotted && !job.authoritySnapshotted) tags.push('preview-only');
  if (job.labelSnapshotted && !job.authoritySnapshotted) tags.push('label-snapshotted-only');
  if (job.authoritySnapshotted) tags.push('authority-snapshotted');
  if (job.legacyImported) tags.push('legacy-import-required');
  if (job.nodeExists && !job.nodeManagedByContract) tags.push('node-exists-but-unmanaged');
  if (job.nodeExists && !job.resolverSetToExpected) tags.push('resolver-mismatch');
  if (job.authoritySnapshotted && (!job.specTextPresent || (job.hasCompletionURI && !job.completionTextPresent))) tags.push('metadata-incomplete');
  if (job.repairable) tags.push('repairable');
  if (job.effectiveReady) tags.push('authoritative-ready');
  if (job.finalized) tags.push('finalized');
  if (job.missingCore) tags.push('missing-core');
  return tags;
}

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  const out = {
    generatedAt: new Date().toISOString(),
    rpc: RPC,
    prime: PRIME,
    ensJobPages: ENS_JOB_PAGES,
    proven: {},
    assumed: [],
    jobs: [],
  };
  let truncated = false;

  try {
    out.proven.latestBlock = await provider.getBlockNumber();
  } catch (error) {
    out.assumed.push('RPC unreachable from this environment; no live inventory could be generated.');
    out.error = error?.message || String(error);
    fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }

  const prime = new ethers.Contract(PRIME, PRIME_ABI, provider);
  const pages = new ethers.Contract(ENS_JOB_PAGES, PAGES_ABI, provider);
  const ens = new ethers.Contract(ENS_REGISTRY, ENS_ABI, provider);
  const nameWrapperAddress = await safe(() => pages.nameWrapper(), ethers.ZeroAddress);
  const wrapper = new ethers.Contract(nameWrapperAddress, WRAPPER_ABI, provider);
  const jobsRootNode = await safe(() => pages.jobsRootNode(), ethers.ZeroHash);
  const nextJobIdRead = await safe(() => prime.nextJobId(), null);
  if (nextJobIdRead === null) {
    throw new Error('Failed to read prime.nextJobId(); refusing to emit a misleading empty inventory.');
  }
  const nextJobId = Number(nextJobIdRead);
  const total = Math.min(nextJobId, MAX_JOBS);
  truncated = nextJobId > MAX_JOBS;
  const config = await safe(() => pages.configurationStatus(), null);
  out.proven.configurationStatus = config ? config.map((value) => typeof value === 'bigint' ? value.toString() : value) : null;

  for (let jobId = 0; jobId < total; jobId += 1) {
    const core = await safe(() => prime.getJobCore(jobId), null);
    const specURI = core ? await safe(() => prime.getJobSpecURI(jobId), '') : '';
    const completionURI = core ? await safe(() => prime.getJobCompletionURI(jobId), '') : '';
    const labelSnapshot = await safe(() => pages.jobLabelSnapshot(jobId), [false, '']);
    const authority = await safe(() => pages.jobAuthorityInfo(jobId), [false, '', ethers.ZeroHash, 0, ethers.ZeroHash, ethers.ZeroHash, 0, 0, 0, false, false, false]);
    const preview = {
      label: await safe(() => pages.previewJobEnsLabel(jobId), ''),
      name: await safe(() => pages.previewJobEnsName(jobId), ''),
      uri: await safe(() => pages.previewJobEnsURI(jobId), ''),
      node: await safe(() => pages.previewJobEnsNode(jobId), ethers.ZeroHash),
    };

    const authorityReady = Boolean(authority[0]);
    const snapshottedLabel = labelSnapshot[0] ? labelSnapshot[1] : '';
    const labelProbe = authorityReady ? authority[1] : (snapshottedLabel || preview.label);
    const labelProbeNode = labelProbe && jobsRootNode !== ethers.ZeroHash
      ? ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [jobsRootNode, ethers.id(labelProbe)])
      : ethers.ZeroHash;

    const effective = authorityReady ? {
      label: await safe(() => pages.effectiveJobEnsLabel(jobId), ''),
      name: await safe(() => pages.effectiveJobEnsName(jobId), ''),
      uri: await safe(() => pages.effectiveJobEnsURI(jobId), ''),
      node: await safe(() => pages.effectiveJobEnsNode(jobId), ethers.ZeroHash),
    } : { label: '', name: '', uri: '', node: ethers.ZeroHash };

    const node = authorityReady ? effective.node : (labelProbeNode !== ethers.ZeroHash ? labelProbeNode : preview.node);
    const owner = node && node !== ethers.ZeroHash ? await safe(() => ens.owner(node), ethers.ZeroAddress) : ethers.ZeroAddress;
    const resolver = node && node !== ethers.ZeroHash ? await safe(() => ens.resolver(node), ethers.ZeroAddress) : ethers.ZeroAddress;
    const expectedResolver = await safe(() => pages.publicResolver(), ethers.ZeroAddress);
    const wrappedTokenOwner = owner !== ethers.ZeroAddress && owner.toLowerCase() === nameWrapperAddress.toLowerCase()
      ? await safe(() => wrapper.ownerOf(BigInt(node)), ethers.ZeroAddress)
      : ethers.ZeroAddress;

    let specText = '';
    let completionText = '';
    let employerAuth = false;
    let agentAuth = false;
    if (resolver && resolver !== ethers.ZeroAddress) {
      const liveResolver = new ethers.Contract(resolver, RESOLVER_ABI, provider);
      specText = await safe(() => liveResolver.text(node, 'agijobs.spec.public'), '');
      completionText = await safe(() => liveResolver.text(node, 'agijobs.completion.public'), '');
      employerAuth = !core || core.employer === ethers.ZeroAddress ? false : await safe(() => liveResolver.isAuthorised(node, core.employer), false);
      agentAuth = !core || core.assignedAgent === ethers.ZeroAddress ? false : await safe(() => liveResolver.isAuthorised(node, core.assignedAgent), false);
    }

    const nodeManagedByContract = owner !== ethers.ZeroAddress && (
      owner.toLowerCase() === ENS_JOB_PAGES.toLowerCase() ||
      (owner.toLowerCase() === nameWrapperAddress.toLowerCase() && wrappedTokenOwner.toLowerCase() === ENS_JOB_PAGES.toLowerCase())
    );

    const effectiveReady = authorityReady && owner !== ethers.ZeroAddress && resolver.toLowerCase() === expectedResolver.toLowerCase();
    const finalized = Boolean(authority[10]);
    const repairable = authorityReady || Boolean(labelSnapshot[0]) || Boolean(specURI) || Boolean(completionURI) || owner !== ethers.ZeroAddress;

    const job = {
      jobId,
      preview,
      effective,
      labelProbe,
      labelProbeNode,
      labelSnapshotted: Boolean(labelSnapshot[0]),
      authoritySnapshotted: authorityReady,
      legacyImported: Boolean(authority[9]),
      missingCore: !core,
      finalized,
      fuseBurned: Boolean(authority[11]),
      nodeExists: owner !== ethers.ZeroAddress,
      nodeManagedByContract,
      wrappedTokenOwner,
      resolverSetToExpected: resolver.toLowerCase() === expectedResolver.toLowerCase(),
      specTextPresent: Boolean(specText),
      completionTextPresent: Boolean(completionText),
      authorisationsAsExpected: !core ? false : (core.assignedAgent === ethers.ZeroAddress ? employerAuth : employerAuth && agentAuth),
      effectiveReady,
      finalizable: authorityReady && owner !== ethers.ZeroAddress,
      repairable,
      hasCompletionURI: Boolean(completionURI),
      core: core ? {
        employer: core.employer,
        assignedAgent: core.assignedAgent,
        completed: core.completed,
        disputed: core.disputed,
        expired: core.expired,
      } : null,
      uris: { specURI, completionURI, specText, completionText },
    };
    job.classification = classify(job);
    out.jobs.push(job);
  }

  out.summary = {
    nextJobId,
    scannedJobs: out.jobs.length,
    maxJobs: MAX_JOBS,
    truncated,
    previewOnly: out.jobs.filter((job) => job.classification.includes('preview-only')).map((job) => job.jobId),
    authoritySnapshotted: out.jobs.filter((job) => job.classification.includes('authority-snapshotted')).map((job) => job.jobId),
    repairable: out.jobs.filter((job) => job.classification.includes('repairable')).map((job) => job.jobId),
    finalized: out.jobs.filter((job) => job.classification.includes('finalized')).map((job) => job.jobId),
    missingCore: out.jobs.filter((job) => job.classification.includes('missing-core')).map((job) => job.jobId),
  };

  if (truncated) {
    out.assumed.push(`Inventory truncated at MAX_JOBS=${MAX_JOBS}; re-run with a higher MAX_JOBS to cover full history.`);
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
