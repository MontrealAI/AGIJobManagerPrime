#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

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
  if (job.legacyImportCandidate) tags.push('legacy-import-required');
  if (job.nodeExists && !job.nodeManagedByContract) tags.push('node-exists-but-unmanaged');
  if (job.nodeExists && !job.resolverSetToExpected) tags.push('resolver-mismatch');
  if (job.authoritySnapshotted && (!job.specTextMatchesManager || (job.hasCompletionURI && !job.completionTextMatchesManager))) tags.push('metadata-incomplete');
  if (job.nodeExists && !job.authorisationsAsExpected) tags.push('permissions-drift');
  if (job.repairable) tags.push('repairable');
  if (job.effectiveReady) tags.push('authoritative-ready');
  if (job.finalized) tags.push('finalized');
  if (job.missingCore) tags.push('missing-core');
  return tags;
}

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new CurlJsonRpcProvider(RPC);
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
    out.proven.latestBlock = provider.getBlockNumber().toString();
  } catch (error) {
    out.assumed.push('RPC unreachable from this environment; no live inventory could be generated.');
    out.error = error?.message || String(error);
    fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }

  const nameWrapperAddress = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'nameWrapper')[0], ethers.ZeroAddress);
  const jobsRootNode = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootNode')[0], ethers.ZeroHash);
  const nextJobIdRead = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'nextJobId')[0], null);
  if (nextJobIdRead === null) {
    throw new Error('Failed to read prime.nextJobId(); refusing to emit a misleading empty inventory.');
  }
  const nextJobId = Number(nextJobIdRead);
  const total = Math.min(nextJobId, MAX_JOBS);
  truncated = nextJobId > MAX_JOBS;
  const config = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'configurationStatus')), null);
  out.proven.configurationStatus = config ? config.map((value) => typeof value === 'bigint' ? value.toString() : value) : null;

  for (let jobId = 0; jobId < total; jobId += 1) {
    const coreRaw = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'getJobCore', [jobId]), null);
    const core = coreRaw ? {
      employer: coreRaw[0],
      assignedAgent: coreRaw[1],
      payout: coreRaw[2],
      duration: coreRaw[3],
      assignedAt: coreRaw[4],
      completed: coreRaw[5],
      disputed: coreRaw[6],
      expired: coreRaw[7],
      agentPayoutPct: coreRaw[8],
    } : null;
    const specURI = core ? await safe(() => provider.readContract(PRIME, PRIME_ABI, 'getJobSpecURI', [jobId])[0], '') : '';
    const completionURI = core ? await safe(() => provider.readContract(PRIME, PRIME_ABI, 'getJobCompletionURI', [jobId])[0], '') : '';
    const labelSnapshot = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobLabelSnapshot', [jobId])), [false, '']);
    const authority = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobAuthorityInfo', [jobId])), [false, '', ethers.ZeroHash, 0, ethers.ZeroHash, ethers.ZeroHash, 0, 0, 0, false, false, false]);
    const preview = {
      label: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsLabel', [jobId])[0], ''),
      name: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsName', [jobId])[0], ''),
      uri: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsURI', [jobId])[0], ''),
      node: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsNode', [jobId])[0], ethers.ZeroHash),
    };

    const authorityReady = Boolean(authority[0]);
    const snapshottedLabel = labelSnapshot[0] ? labelSnapshot[1] : '';
    const labelProbe = authorityReady ? authority[1] : (snapshottedLabel || preview.label);
    const labelProbeNode = labelProbe && jobsRootNode !== ethers.ZeroHash
      ? ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [jobsRootNode, ethers.id(labelProbe)])
      : ethers.ZeroHash;

    const effective = authorityReady ? {
      label: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsLabel', [jobId])[0], ''),
      name: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsName', [jobId])[0], ''),
      uri: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsURI', [jobId])[0], ''),
      node: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsNode', [jobId])[0], ethers.ZeroHash),
    } : { label: '', name: '', uri: '', node: ethers.ZeroHash };

    const node = authorityReady ? effective.node : (labelProbeNode !== ethers.ZeroHash ? labelProbeNode : preview.node);
    const owner = node && node !== ethers.ZeroHash ? await safe(() => provider.readContract(ENS_REGISTRY, ENS_ABI, 'owner', [node])[0], ethers.ZeroAddress) : ethers.ZeroAddress;
    const resolver = node && node !== ethers.ZeroHash ? await safe(() => provider.readContract(ENS_REGISTRY, ENS_ABI, 'resolver', [node])[0], ethers.ZeroAddress) : ethers.ZeroAddress;
    const expectedResolver = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'publicResolver')[0], ethers.ZeroAddress);
    const wrappedTokenOwner = owner !== ethers.ZeroAddress && owner.toLowerCase() === nameWrapperAddress.toLowerCase()
      ? await safe(() => provider.readContract(nameWrapperAddress, WRAPPER_ABI, 'ownerOf', [BigInt(node)])[0], ethers.ZeroAddress)
      : ethers.ZeroAddress;
    const wrappedUnmanaged = owner !== ethers.ZeroAddress
      && owner.toLowerCase() === nameWrapperAddress.toLowerCase()
      && wrappedTokenOwner !== ethers.ZeroAddress
      && wrappedTokenOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase();

    let specText = '';
    let completionText = '';
    let employerAuth = false;
    let agentAuth = false;
    if (resolver && resolver !== ethers.ZeroAddress) {
      specText = await safe(() => provider.readContract(resolver, RESOLVER_ABI, 'text', [node, 'agijobs.spec.public'])[0], '');
      completionText = await safe(() => provider.readContract(resolver, RESOLVER_ABI, 'text', [node, 'agijobs.completion.public'])[0], '');
      employerAuth = !core || core.employer === ethers.ZeroAddress ? false : await safe(() => provider.readContract(resolver, RESOLVER_ABI, 'isAuthorised', [node, core.employer])[0], false);
      agentAuth = !core || core.assignedAgent === ethers.ZeroAddress ? false : await safe(() => provider.readContract(resolver, RESOLVER_ABI, 'isAuthorised', [node, core.assignedAgent])[0], false);
    }

    const nodeManagedByContract = owner !== ethers.ZeroAddress && (
      owner.toLowerCase() === ENS_JOB_PAGES.toLowerCase() ||
      (owner.toLowerCase() === nameWrapperAddress.toLowerCase() && wrappedTokenOwner.toLowerCase() === ENS_JOB_PAGES.toLowerCase())
    );

    const specTextMatchesManager = !specURI || specText === specURI;
    const completionTextMatchesManager = !completionURI || completionText === completionURI;
    const effectiveReady = authorityReady
      && owner !== ethers.ZeroAddress
      && resolver.toLowerCase() === expectedResolver.toLowerCase()
      && specTextMatchesManager
      && completionTextMatchesManager
      && (!core || (core.assignedAgent === ethers.ZeroAddress ? employerAuth : employerAuth && agentAuth));
    const finalized = Boolean(authority[10]);
    const legacyImportCandidate = !Boolean(authority[9]) && (
      (Boolean(labelSnapshot[0]) && labelSnapshot[1] !== preview.label) || wrappedUnmanaged
    );
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
      legacyImportCandidate,
      missingCore: !core,
      finalized,
      fuseBurned: Boolean(authority[11]),
      nodeExists: owner !== ethers.ZeroAddress,
      nodeManagedByContract,
      wrappedTokenOwner,
      resolverSetToExpected: resolver.toLowerCase() === expectedResolver.toLowerCase(),
      specTextPresent: Boolean(specText),
      completionTextPresent: Boolean(completionText),
      specTextMatchesManager,
      completionTextMatchesManager,
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
