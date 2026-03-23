import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..', '..');
const MAINNET_RPC_URL = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const DEFAULT_MANAGER = '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e';
const DEFAULT_ENS_JOB_PAGES = '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d';
const DEFAULT_ENS_REGISTRY = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';
const DEFAULT_NAME_WRAPPER = '0xD4416b13d2b3a9aBae7AcD5D6C2BbDBE25686401';
const DEFAULT_ROOT_NAME = 'alpha.jobs.agi.eth';
const MAX_DEFAULT_JOBS = 64;

const MANAGER_ABI = [
  'function ensJobPages() view returns (address)',
  'function nextJobId() view returns (uint256)',
  'function owner() view returns (address)',
  'function discoveryModule() view returns (address)',
  'function jobEmployerOf(uint256) view returns (address)',
  'function jobAssignedAgentOf(uint256) view returns (address)',
  'event JobCreated(uint256 indexed jobId,address indexed employer,uint256 payout,uint256 duration,string jobSpecURI,uint8 intakeMode,bytes32 perJobAgentRoot,string details)',
  'event JobCompletionRequested(uint256 indexed jobId,address indexed agent,string jobCompletionURI)',
  'event JobCompleted(uint256 indexed jobId,address indexed agent,uint256 indexed reputationPoints)',
  'event JobEmployerRefunded(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 refund)',
  'event JobExpired(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 payout)'
];
const ENS_JOB_PAGES_ABI = [
  'function owner() view returns (address)',
  'function jobManager() view returns (address)',
  'function ens() view returns (address)',
  'function nameWrapper() view returns (address)',
  'function publicResolver() view returns (address)',
  'function jobsRootNode() view returns (bytes32)',
  'function jobsRootName() view returns (string)',
  'function jobLabelPrefix() view returns (string)',
  'function configLocked() view returns (bool)',
  'function useEnsJobTokenURI() view returns (bool)',
  'function validateConfiguration() view returns (uint256)',
  'function configurationStatus() view returns (bool,bool,bool,bool,bool,bool,bool,bool,bool,bool,uint256)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function previewJobEnsName(uint256) view returns (string)',
  'function effectiveJobEnsName(uint256) view returns (string)',
  'function jobEnsIssued(uint256) view returns (bool)',
  'function jobEnsReady(uint256) view returns (bool)'
];
const ENS_REGISTRY_ABI = ['function owner(bytes32) view returns (address)', 'function resolver(bytes32) view returns (address)'];
const NAME_WRAPPER_ABI = ['function ownerOf(uint256) view returns (address)', 'function getApproved(uint256) view returns (address)', 'function isApprovedForAll(address,address) view returns (bool)'];
const TEXT_ABI = ['function text(bytes32,string) view returns (string)'];
const LEGACY_AUTH_ABI = ['function authorisations(bytes32,address,address) view returns (bool)'];
const MODERN_AUTH_ABI = ['function isApprovedFor(address,bytes32,address) view returns (bool)'];
const OPERATOR_AUTH_ABI = ['function isApprovedForAll(address,address) view returns (bool)'];
const managerIface = new ethers.Interface(MANAGER_ABI);

function arg(name, fallback = '') {
  const prefix = `--${name}=`;
  const hit = process.argv.find((value) => value.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}
const safe = async (label, fn, fallback = null) => { try { return await fn(); } catch (error) { return { __error: true, label, message: error?.message || String(error), fallback }; } };
const unwrap = (value, fallback = null) => value && value.__error ? (value.fallback ?? fallback) : value;
const serialize = (value) => typeof value === 'bigint' ? value.toString() : Array.isArray(value) ? value.map(serialize) : value && typeof value === 'object' ? Object.fromEntries(Object.entries(value).map(([k, v]) => [k, serialize(v)])) : value;

const MAX_LOG_BLOCK_RANGE = Number(process.env.MAX_LOG_BLOCK_RANGE || '45000');

async function getLogs(provider, address, topic0) {
  const latestBlock = Number(provider.getBlockNumber ? await provider.getBlockNumber() : provider.getBlock('latest').number);
  const logs = [];
  for (let fromBlock = 0; fromBlock <= latestBlock; fromBlock += MAX_LOG_BLOCK_RANGE + 1) {
    const toBlock = Math.min(latestBlock, fromBlock + MAX_LOG_BLOCK_RANGE);
    const chunk = await provider.request('eth_getLogs', [{ address, fromBlock: ethers.toQuantity(fromBlock), toBlock: ethers.toQuantity(toBlock), topics: [topic0] }]);
    logs.push(...chunk);
  }
  return logs;
}

async function main() {
  const provider = new CurlJsonRpcProvider(MAINNET_RPC_URL);
  const managerAddress = arg('manager', DEFAULT_MANAGER);
  const configuredPagesAddress = arg('ens-job-pages', DEFAULT_ENS_JOB_PAGES);
  const ensRegistryAddress = arg('ens', DEFAULT_ENS_REGISTRY);
  const nameWrapperAddress = arg('wrapper', DEFAULT_NAME_WRAPPER);
  const rootName = ethers.ensNormalize(arg('root-name', DEFAULT_ROOT_NAME));
  const maxJobs = Number(arg('max-jobs', String(MAX_DEFAULT_JOBS)));
  const outJsonRel = arg('out-json', 'docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-current.json');
  const outMdRel = arg('out-md', 'docs/DEPLOYMENT/artifacts/ens-phase0-mainnet-current.md');

  const latestBlock = provider.getBlock('latest');
  const nextJobId = Number(unwrap(await safe('manager.nextJobId', () => provider.readContract(managerAddress, MANAGER_ABI, 'nextJobId')[0]), 0n));
  const livePages = unwrap(await safe('manager.ensJobPages', () => provider.readContract(managerAddress, MANAGER_ABI, 'ensJobPages')[0]), configuredPagesAddress);
  const rootNode = ethers.namehash(rootName);
  const rootOwner = unwrap(await safe('ens.owner(root)', () => provider.readContract(ensRegistryAddress, ENS_REGISTRY_ABI, 'owner', [rootNode])[0]), ethers.ZeroAddress);
  const rootResolver = unwrap(await safe('ens.resolver(root)', () => provider.readContract(ensRegistryAddress, ENS_REGISTRY_ABI, 'resolver', [rootNode])[0]), ethers.ZeroAddress);
  const wrapperOwner = unwrap(await safe('wrapper.ownerOf(root)', () => provider.readContract(nameWrapperAddress, NAME_WRAPPER_ABI, 'ownerOf', [BigInt(rootNode)])[0]), ethers.ZeroAddress);
  const wrapperApproved = unwrap(await safe('wrapper.getApproved(root)', () => provider.readContract(nameWrapperAddress, NAME_WRAPPER_ABI, 'getApproved', [BigInt(rootNode)])[0]), ethers.ZeroAddress);
  const wrapperApprovalForHelper = livePages === ethers.ZeroAddress ? false : unwrap(await safe('wrapper.isApprovedForAll(rootOwner,pages)', () => provider.readContract(nameWrapperAddress, NAME_WRAPPER_ABI, 'isApprovedForAll', [wrapperOwner, livePages])[0]), false);

  const helperConfig = livePages === ethers.ZeroAddress ? null : {
    owner: unwrap(await safe('pages.owner', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'owner')[0]), ethers.ZeroAddress),
    jobManager: unwrap(await safe('pages.jobManager', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobManager')[0]), ethers.ZeroAddress),
    ens: unwrap(await safe('pages.ens', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'ens')[0]), ethers.ZeroAddress),
    nameWrapper: unwrap(await safe('pages.nameWrapper', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'nameWrapper')[0]), ethers.ZeroAddress),
    publicResolver: unwrap(await safe('pages.publicResolver', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'publicResolver')[0]), ethers.ZeroAddress),
    jobsRootNode: unwrap(await safe('pages.jobsRootNode', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobsRootNode')[0]), ethers.ZeroHash),
    jobsRootName: unwrap(await safe('pages.jobsRootName', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobsRootName')[0]), ''),
    jobLabelPrefix: unwrap(await safe('pages.jobLabelPrefix', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobLabelPrefix')[0]), ''),
    configLocked: unwrap(await safe('pages.configLocked', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'configLocked')[0]), false),
    useEnsJobTokenURI: unwrap(await safe('pages.useEnsJobTokenURI', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'useEnsJobTokenURI')[0]), false),
    validateConfiguration: String(unwrap(await safe('pages.validateConfiguration', () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'validateConfiguration')[0]), 0n)),
    configurationStatus: serialize(unwrap(await safe('pages.configurationStatus', () => Array.from(provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'configurationStatus'))), null)),
  };

  const createdLogs = await getLogs(provider, managerAddress, managerIface.getEvent('JobCreated').topicHash);
  const completionLogs = await getLogs(provider, managerAddress, managerIface.getEvent('JobCompletionRequested').topicHash);
  const completedLogs = await getLogs(provider, managerAddress, managerIface.getEvent('JobCompleted').topicHash);
  const refundedLogs = await getLogs(provider, managerAddress, managerIface.getEvent('JobEmployerRefunded').topicHash);
  const expiredLogs = await getLogs(provider, managerAddress, managerIface.getEvent('JobExpired').topicHash);
  const createdById = new Map();
  const completionById = new Map();
  const terminalSet = new Set();
  for (const log of createdLogs) { const parsed = managerIface.parseLog(log); createdById.set(Number(parsed.args.jobId), { employer: parsed.args.employer, specURI: parsed.args.jobSpecURI }); }
  for (const log of completionLogs) { const parsed = managerIface.parseLog(log); completionById.set(Number(parsed.args.jobId), { agent: parsed.args.agent, completionURI: parsed.args.jobCompletionURI }); }
  for (const log of [...completedLogs, ...refundedLogs, ...expiredLogs]) terminalSet.add(Number(ethers.getBigInt(log.topics[1])));

  const jobs = [];
  for (let jobId = 0; jobId < Math.min(nextJobId, maxJobs); jobId += 1) {
    const created = createdById.get(jobId) || { employer: ethers.ZeroAddress, specURI: '' };
    const completion = completionById.get(jobId) || { agent: ethers.ZeroAddress, completionURI: '' };
    const employer = unwrap(await safe(`manager.jobEmployerOf(${jobId})`, () => provider.readContract(managerAddress, MANAGER_ABI, 'jobEmployerOf', [jobId])[0]), created.employer);
    const agent = unwrap(await safe(`manager.jobAssignedAgentOf(${jobId})`, () => provider.readContract(managerAddress, MANAGER_ABI, 'jobAssignedAgentOf', [jobId])[0]), completion.agent);
    const labelSnapshot = livePages === ethers.ZeroAddress ? [false, ''] : unwrap(await safe(`pages.jobLabelSnapshot(${jobId})`, () => Array.from(provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobLabelSnapshot', [jobId]))), [false, '']);
    const authority = livePages === ethers.ZeroAddress ? [false, '', ethers.ZeroHash, 0, ethers.ZeroHash, ethers.ZeroHash, 0, 0, 0, false, false, false] : unwrap(await safe(`pages.jobAuthorityInfo(${jobId})`, () => Array.from(provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobAuthorityInfo', [jobId]))), [false, '', ethers.ZeroHash, 0, ethers.ZeroHash, ethers.ZeroHash, 0, 0, 0, false, false, false]);
    const previewName = livePages === ethers.ZeroAddress ? '' : unwrap(await safe(`pages.previewJobEnsName(${jobId})`, () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'previewJobEnsName', [jobId])[0]), '');
    const effectiveName = authority[0] ? unwrap(await safe(`pages.effectiveJobEnsName(${jobId})`, () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'effectiveJobEnsName', [jobId])[0]), '') : '';
    const node = authority[0] ? authority[5] : ethers.ZeroHash;
    const nodeOwner = node !== ethers.ZeroHash ? unwrap(await safe(`ens.owner(node:${jobId})`, () => provider.readContract(ensRegistryAddress, ENS_REGISTRY_ABI, 'owner', [node])[0]), ethers.ZeroAddress) : ethers.ZeroAddress;
    const nodeResolver = node !== ethers.ZeroHash ? unwrap(await safe(`ens.resolver(node:${jobId})`, () => provider.readContract(ensRegistryAddress, ENS_REGISTRY_ABI, 'resolver', [node])[0]), ethers.ZeroAddress) : ethers.ZeroAddress;
    const schemaText = nodeResolver !== ethers.ZeroAddress ? unwrap(await safe(`resolver.schema(${jobId})`, () => provider.readContract(nodeResolver, TEXT_ABI, 'text', [node, 'schema'])[0]), '') : '';
    const specText = nodeResolver !== ethers.ZeroAddress ? unwrap(await safe(`resolver.spec(${jobId})`, () => provider.readContract(nodeResolver, TEXT_ABI, 'text', [node, 'agijobs.spec.public'])[0]), '') : '';
    const completionText = nodeResolver !== ethers.ZeroAddress ? unwrap(await safe(`resolver.completion(${jobId})`, () => provider.readContract(nodeResolver, TEXT_ABI, 'text', [node, 'agijobs.completion.public'])[0]), '') : '';
    const readAuth = async (target) => {
      if (nodeResolver === ethers.ZeroAddress || target === ethers.ZeroAddress) return null;
      let value = unwrap(await safe(`resolver.authorisations(${jobId})`, () => provider.readContract(nodeResolver, LEGACY_AUTH_ABI, 'authorisations', [node, nodeOwner, target])[0]), null);
      if (value !== null) return value;
      value = unwrap(await safe(`resolver.isApprovedFor(${jobId})`, () => provider.readContract(nodeResolver, MODERN_AUTH_ABI, 'isApprovedFor', [nodeOwner, node, target])[0]), null);
      if (value !== null) return value;
      return unwrap(await safe(`resolver.isApprovedForAll(${jobId})`, () => provider.readContract(nodeResolver, OPERATOR_AUTH_ABI, 'isApprovedForAll', [nodeOwner, target])[0]), null);
    };
    const employerAuth = await readAuth(employer);
    const agentAuth = await readAuth(agent);
    jobs.push({
      jobId,
      previewName,
      effectiveName,
      labelSnapshot: { isSet: Boolean(labelSnapshot[0]), label: labelSnapshot[1] || '' },
      authorityEstablished: Boolean(authority[0]),
      authorityRootVersion: Number(authority[3] || 0),
      finalizedFlag: Boolean(authority[10]),
      fuseBurnedFlag: Boolean(authority[11]),
      issuedCompat: livePages === ethers.ZeroAddress ? false : unwrap(await safe(`pages.jobEnsIssued(${jobId})`, () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobEnsIssued', [jobId])[0]), false),
      readyCompat: livePages === ethers.ZeroAddress ? false : unwrap(await safe(`pages.jobEnsReady(${jobId})`, () => provider.readContract(livePages, ENS_JOB_PAGES_ABI, 'jobEnsReady', [jobId])[0]), false),
      employer,
      assignedAgent: agent,
      specURI: created.specURI,
      completionURI: completion.completionURI,
      terminalObserved: terminalSet.has(jobId),
      node,
      nodeOwner,
      nodeResolver,
      schemaTextPresent: Boolean(schemaText),
      specTextPresent: Boolean(specText),
      completionTextPresent: Boolean(completionText),
      authReadSupported: employerAuth !== null || agentAuth !== null,
      employerAuthObserved: employerAuth,
      agentAuthObserved: agentAuth,
    });
  }

  const payload = {
    schema: 'agijobmanager.ens.phase0.v2',
    generatedAtUtc: new Date().toISOString(),
    rpcSource: MAINNET_RPC_URL,
    chain: { chainId: Number(provider.getChainId()), blockNumber: Number(latestBlock.number), blockHash: latestBlock.hash, blockTimestamp: Number(latestBlock.timestamp) },
    manager: { address: managerAddress, owner: unwrap(await safe('manager.owner', () => provider.readContract(managerAddress, MANAGER_ABI, 'owner')[0]), ethers.ZeroAddress), discoveryModule: unwrap(await safe('manager.discoveryModule', () => provider.readContract(managerAddress, MANAGER_ABI, 'discoveryModule')[0]), ethers.ZeroAddress), ensJobPages: livePages, nextJobId },
    root: { rootName, rootNode, ensRegistry: ensRegistryAddress, nameWrapper: nameWrapperAddress, rootOwner, rootResolver, wrapped: rootOwner.toLowerCase() === nameWrapperAddress.toLowerCase(), wrapperOwner, wrapperApprovedAddress: wrapperApproved, wrapperApprovalForHelper },
    helperConfig,
    repairSummary: {
      scannedJobs: jobs.length,
      needsAuthorityRepair: jobs.filter((job) => !job.authorityEstablished && job.labelSnapshot.isSet).map((job) => job.jobId),
      needsTextRepair: jobs.filter((job) => job.authorityEstablished && (!job.specTextPresent || (job.completionURI && !job.completionTextPresent))).map((job) => job.jobId),
      needsAuthRepair: jobs.filter((job) => job.authorityEstablished && job.authReadSupported && ((!job.terminalObserved && (job.employerAuthObserved !== true || (job.assignedAgent !== ethers.ZeroAddress && job.agentAuthObserved !== true))) || (job.terminalObserved && (job.employerAuthObserved || job.agentAuthObserved)))).map((job) => job.jobId),
    },
    jobs,
    notes: [
      'Phase 0 now avoids unavailable Prime V1 getters by reconstructing URIs from manager logs and using Prime public employer/agent getters only where available.',
      'Compatibility jobEnsIssued/jobEnsReady values are reported separately from richer observed state so operator dashboards do not overclaim.',
      'If authReadSupported is false, resolver write compatibility may still be present, but auth truth requires manual/operator confirmation.',
    ],
  };

  const outJson = path.join(repoRoot, outJsonRel);
  const outMd = path.join(repoRoot, outMdRel);
  fs.mkdirSync(path.dirname(outJson), { recursive: true });
  fs.mkdirSync(path.dirname(outMd), { recursive: true });
  fs.writeFileSync(outJson, `${JSON.stringify(serialize(payload), null, 2)}\n`);
  const lines = [
    '# ENS Phase 0 mainnet snapshot', '',
    `- Generated at (UTC): \`${payload.generatedAtUtc}\``,
    `- RPC source: \`${payload.rpcSource}\``,
    `- Manager: \`${payload.manager.address}\``,
    `- ENSJobPages target: \`${payload.manager.ensJobPages}\``,
    `- Root: \`${payload.root.rootName}\` / \`${payload.root.rootNode}\``, '',
    '## Root authority', '',
    `- ENS root owner: \`${payload.root.rootOwner}\``,
    `- NameWrapper ownerOf(root): \`${payload.root.wrapperOwner}\``,
    `- NameWrapper getApproved(root): \`${payload.root.wrapperApprovedAddress}\``,
    `- NameWrapper isApprovedForAll(rootOwner, ensJobPages): \`${payload.root.wrapperApprovalForHelper}\``, '',
    '## Active ENSJobPages config', '',
    ...Object.entries(payload.helperConfig || {}).map(([key, value]) => `- ${key}: \`${String(value)}\``), '',
    '## Repair summary', '',
    `- needsAuthorityRepair: \`${payload.repairSummary.needsAuthorityRepair.join(', ') || 'none'}\``,
    `- needsTextRepair: \`${payload.repairSummary.needsTextRepair.join(', ') || 'none'}\``,
    `- needsAuthRepair: \`${payload.repairSummary.needsAuthRepair.join(', ') || 'none'}\``, '',
    '## Job inventory', '',
    '| jobId | preview | effective | issuedCompat | readyCompat | spec text | completion text | auth read |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',
    ...jobs.map((job) => `| ${job.jobId} | \`${job.previewName || '(none)'}\` | \`${job.effectiveName || '(none)'}\` | ${job.issuedCompat} | ${job.readyCompat} | ${job.specTextPresent} | ${job.completionTextPresent} | ${job.authReadSupported} |`),
    ''
  ];
  fs.writeFileSync(outMd, `${lines.join('\n')}\n`);
  console.log(`Wrote ${path.relative(repoRoot, outJson)}`);
  console.log(`Wrote ${path.relative(repoRoot, outMd)}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
