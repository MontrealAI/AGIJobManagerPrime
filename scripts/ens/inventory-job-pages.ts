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
  'function jobEmployerOf(uint256) view returns (address)',
  'function jobAssignedAgentOf(uint256) view returns (address)',
  'event JobCreated(uint256 indexed jobId,address indexed employer,uint256 payout,uint256 duration,string jobSpecURI,uint8 intakeMode,bytes32 perJobAgentRoot,string details)',
  'event JobCompletionRequested(uint256 indexed jobId,address indexed agent,string jobCompletionURI)',
  'event JobCompleted(uint256 indexed jobId,address indexed agent,uint256 indexed reputationPoints)',
  'event JobEmployerRefunded(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 refund)',
  'event JobExpired(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 payout)'
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
  'function jobEnsIssued(uint256) view returns (bool)',
  'function jobEnsReady(uint256) view returns (bool)'
];
const ENS_ABI = ['function owner(bytes32) view returns (address)', 'function resolver(bytes32) view returns (address)'];
const WRAPPER_ABI = ['function ownerOf(uint256) view returns (address)'];
const RESOLVER_TEXT_ABI = ['function text(bytes32,string) view returns (string)'];

const primeIface = new ethers.Interface(PRIME_ABI);

async function safe(fn, fallback = null) { try { return await fn(); } catch { return fallback; } }

function serialize(value) {
  if (typeof value === 'bigint') return value.toString();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, serialize(v)]));
  return value;
}

function classify(job) {
  const tags = [];
  if (!job.labelSnapshotted && !job.authoritySnapshotted) tags.push('preview-only');
  if (job.labelSnapshotted && !job.authoritySnapshotted) tags.push('label-snapshotted-only');
  if (job.authoritySnapshotted) tags.push('authority-established');
  if (job.nodeExists && !job.nodeManagedByContract) tags.push('node-exists-but-unmanaged');
  if (job.nodeExists && !job.resolverSetToExpected) tags.push('resolver-mismatch');
  if (!job.specTextPresent) tags.push('metadata-incomplete');
  if (job.hasCompletionURI && !job.completionTextPresent) tags.push('completion-repairable');
  if (job.authReadSupported && !job.authorisationsAsExpected) tags.push('permissions-drift');
  if (!job.authReadSupported) tags.push('authorisation-observation-unavailable');
  if (job.finalizedFlag) tags.push('finalization-flag-set');
  if (job.fuseBurnedFlag) tags.push('fuse-burn-flag-set');
  if (job.repairable) tags.push('repairable');
  return tags;
}

async function getLogs(provider, address, topic0) {
  return provider.request('eth_getLogs', [{ address, fromBlock: '0x0', toBlock: 'latest', topics: [topic0] }]);
}

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new CurlJsonRpcProvider(RPC);
  const out = { generatedAt: new Date().toISOString(), rpc: RPC, prime: PRIME, ensJobPages: ENS_JOB_PAGES, proven: {}, assumed: [], jobs: [] };
  try {
    out.proven.latestBlock = provider.getBlockNumber().toString();
  } catch (error) {
    out.assumed.push('RPC unreachable from this environment; no live inventory could be generated.');
    out.error = error?.message || String(error);
    fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }

  const nextJobId = Number(await safe(() => provider.readContract(PRIME, PRIME_ABI, 'nextJobId')[0], 0n));
  const total = Math.min(nextJobId, MAX_JOBS);
  if (nextJobId > MAX_JOBS) out.assumed.push(`Inventory truncated at MAX_JOBS=${MAX_JOBS}; re-run with a higher MAX_JOBS to cover full history.`);

  const nameWrapperAddress = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'nameWrapper')[0], ethers.ZeroAddress);
  const jobsRootNode = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootNode')[0], ethers.ZeroHash);
  const expectedResolver = await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'publicResolver')[0], ethers.ZeroAddress);
  const config = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'configurationStatus')), null);
  out.proven.configurationStatus = serialize(config);

  const createdLogs = await getLogs(provider, PRIME, primeIface.getEvent('JobCreated').topicHash);
  const completionLogs = await getLogs(provider, PRIME, primeIface.getEvent('JobCompletionRequested').topicHash);
  const completedLogs = await getLogs(provider, PRIME, primeIface.getEvent('JobCompleted').topicHash);
  const refundedLogs = await getLogs(provider, PRIME, primeIface.getEvent('JobEmployerRefunded').topicHash);
  const expiredLogs = await getLogs(provider, PRIME, primeIface.getEvent('JobExpired').topicHash);

  const createdById = new Map();
  for (const log of createdLogs) {
    const parsed = primeIface.parseLog(log);
    createdById.set(Number(parsed.args.jobId), { employer: parsed.args.employer, specURI: parsed.args.jobSpecURI, blockNumber: Number(log.blockNumber) });
  }
  const completionById = new Map();
  for (const log of completionLogs) {
    const parsed = primeIface.parseLog(log);
    completionById.set(Number(parsed.args.jobId), { agent: parsed.args.agent, completionURI: parsed.args.jobCompletionURI, blockNumber: Number(log.blockNumber) });
  }
  const terminalSet = new Set();
  for (const log of [...completedLogs, ...refundedLogs, ...expiredLogs]) terminalSet.add(Number(ethers.getBigInt(log.topics[1])));

  for (let jobId = 0; jobId < total; jobId += 1) {
    const labelSnapshot = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobLabelSnapshot', [jobId])), [false, '']);
    const authority = await safe(() => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobAuthorityInfo', [jobId])), [false, '', ethers.ZeroHash, 0, ethers.ZeroHash, ethers.ZeroHash, 0, 0, 0, false, false, false]);
    const preview = {
      label: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsLabel', [jobId])[0], ''),
      name: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsName', [jobId])[0], ''),
      uri: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsURI', [jobId])[0], ''),
      node: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'previewJobEnsNode', [jobId])[0], ethers.ZeroHash),
    };
    const effective = authority[0] ? {
      label: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsLabel', [jobId])[0], ''),
      name: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsName', [jobId])[0], ''),
      uri: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsURI', [jobId])[0], ''),
      node: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'effectiveJobEnsNode', [jobId])[0], ethers.ZeroHash),
    } : { label: '', name: '', uri: '', node: ethers.ZeroHash };

    const node = authority[0] ? effective.node : preview.node;
    const owner = node && node !== ethers.ZeroHash ? await safe(() => provider.readContract(ENS_REGISTRY, ENS_ABI, 'owner', [node])[0], ethers.ZeroAddress) : ethers.ZeroAddress;
    const resolver = node && node !== ethers.ZeroHash ? await safe(() => provider.readContract(ENS_REGISTRY, ENS_ABI, 'resolver', [node])[0], ethers.ZeroAddress) : ethers.ZeroAddress;
    const wrappedTokenOwner = owner !== ethers.ZeroAddress && nameWrapperAddress !== ethers.ZeroAddress && owner.toLowerCase() === nameWrapperAddress.toLowerCase()
      ? await safe(() => provider.readContract(nameWrapperAddress, WRAPPER_ABI, 'ownerOf', [BigInt(node)])[0], ethers.ZeroAddress)
      : ethers.ZeroAddress;
    const nodeManagedByContract = owner !== ethers.ZeroAddress && (
      owner.toLowerCase() === ENS_JOB_PAGES.toLowerCase() ||
      (nameWrapperAddress !== ethers.ZeroAddress && owner.toLowerCase() === nameWrapperAddress.toLowerCase() && wrappedTokenOwner.toLowerCase() === ENS_JOB_PAGES.toLowerCase())
    );

    const created = createdById.get(jobId) || { employer: ethers.ZeroAddress, specURI: '' };
    const completion = completionById.get(jobId) || { agent: ethers.ZeroAddress, completionURI: '' };
    const employer = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'jobEmployerOf', [jobId])[0], created.employer);
    const agent = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'jobAssignedAgentOf', [jobId])[0], completion.agent);

    let schemaText = '';
    let specText = '';
    let completionText = '';
    let authReadSupported = false;
    let employerAuth = null;
    let agentAuth = null;
    if (resolver && resolver !== ethers.ZeroAddress) {
      schemaText = await safe(() => provider.readContract(resolver, RESOLVER_TEXT_ABI, 'text', [node, 'schema'])[0], '');
      specText = await safe(() => provider.readContract(resolver, RESOLVER_TEXT_ABI, 'text', [node, 'agijobs.spec.public'])[0], '');
      completionText = await safe(() => provider.readContract(resolver, RESOLVER_TEXT_ABI, 'text', [node, 'agijobs.completion.public'])[0], '');
      const authAbi = ['function isAuthorised(bytes32,address) view returns (bool)'];
      const employerAuthRead = await safe(() => provider.readContract(resolver, authAbi, 'isAuthorised', [node, employer])[0], null);
      const agentAuthRead = await safe(() => provider.readContract(resolver, authAbi, 'isAuthorised', [node, agent])[0], null);
      authReadSupported = employerAuthRead !== null || agentAuthRead !== null;
      employerAuth = employerAuthRead;
      agentAuth = agentAuthRead;
    }

    const job = {
      jobId,
      preview,
      effective,
      labelSnapshotted: Boolean(labelSnapshot[0]),
      authoritySnapshotted: Boolean(authority[0]),
      authorityRootVersion: Number(authority[3] || 0),
      legacyImported: Boolean(authority[9]),
      finalizedFlag: Boolean(authority[10]),
      fuseBurnedFlag: Boolean(authority[11]),
      nodeExists: owner !== ethers.ZeroAddress,
      nodeManagedByContract,
      resolverSetToExpected: resolver !== ethers.ZeroAddress && resolver.toLowerCase() === expectedResolver.toLowerCase(),
      schemaTextPresent: Boolean(schemaText),
      specTextPresent: Boolean(specText),
      completionTextPresent: Boolean(completionText),
      authReadSupported,
      employerAuthorisedObserved: employerAuth,
      agentAuthorisedObserved: agentAuth,
      authorisationsAsExpected: authReadSupported ? ((employer === ethers.ZeroAddress || employerAuth === true) && (agent === ethers.ZeroAddress || agentAuth === true || terminalSet.has(jobId))) : false,
      compatibilityIssued: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobEnsIssued', [jobId])[0], false),
      compatibilityReady: await safe(() => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobEnsReady', [jobId])[0], false),
      repairable: Boolean(labelSnapshot[0]) || Boolean(authority[0]) || owner !== ethers.ZeroAddress || Boolean(created.specURI) || Boolean(completion.completionURI),
      hasCompletionURI: Boolean(completion.completionURI),
      manager: { employer, assignedAgent: agent, specURI: created.specURI, completionURI: completion.completionURI, terminalObserved: terminalSet.has(jobId) },
      nodeOwner: owner,
      resolver,
      wrappedTokenOwner,
      texts: { schema: schemaText, spec: specText, completion: completionText },
    };
    job.classification = classify(job);
    out.jobs.push(job);
  }

  out.summary = {
    nextJobId,
    scannedJobs: out.jobs.length,
    previewOnly: out.jobs.filter((job) => job.classification.includes('preview-only')).map((job) => job.jobId),
    authorityEstablished: out.jobs.filter((job) => job.classification.includes('authority-established')).map((job) => job.jobId),
    repairable: out.jobs.filter((job) => job.classification.includes('repairable')).map((job) => job.jobId),
  };

  fs.writeFileSync(OUTPUT, `${JSON.stringify(serialize(out), null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
