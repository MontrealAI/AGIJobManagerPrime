#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const INPUT = process.env.INPUT || process.argv[2] || 'scripts/ens/output/legacy-job-labels.json';
const OUTPUT = path.resolve('scripts/ens/output/migrate-legacy-batch.json');
const execute = process.env.EXECUTE === '1';

const PAGES_ABI = [
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function jobsRootNode() view returns (bytes32)',
  'function nameWrapper() view returns (address)',
  'function publicResolver() view returns (address)',
  'function jobManager() view returns (address)',
  'function repairAuthoritySnapshot(uint256,string)',
  'function repairResolver(uint256)',
  'function repairTextsExplicit(uint256,string,string)',
  'function repairAuthorisationsExplicit(uint256,address,address,bool)',
  'function replayCreateExplicit(uint256,address,string)',
  'function replayAssignExplicit(uint256,address)',
  'function replayCompletionExplicit(uint256,string)',
  'function replayRevokeExplicit(uint256,address,address)',
  'function replayLockExplicit(uint256,address,address,bool)',
];
const PRIME_ABI = [
  'function jobEmployerOf(uint256) view returns (address)',
  'function jobAssignedAgentOf(uint256) view returns (address)',
  'event JobCreated(uint256 indexed jobId,address indexed employer,uint256 payout,uint256 duration,string jobSpecURI,uint8 intakeMode,bytes32 perJobAgentRoot,string details)',
  'event JobCompletionRequested(uint256 indexed jobId,address indexed agent,string jobCompletionURI)',
  'event JobCompleted(uint256 indexed jobId,address indexed agent,uint256 indexed reputationPoints)',
  'event JobEmployerRefunded(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 refund)',
  'event JobExpired(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 payout)'
];
const ENS_ABI = ['function owner(bytes32) view returns (address)'];
const WRAPPER_ABI = ['function ownerOf(uint256) view returns (address)'];

const primeIface = new ethers.Interface(PRIME_ABI);

async function safe(fn, fallback = null) { try { return await fn(); } catch { return fallback; } }
async function mustRead(label, fn) {
  try { return await fn(); } catch (error) { throw new Error(`${label} read failed: ${error?.shortMessage || error?.message || String(error)}`); }
}
async function getLogs(provider, address, topic0) {
  return provider.getLogs({ address, fromBlock: '0x0', toBlock: 'latest', topics: [topic0] });
}

async function buildPlan(provider, item, context) {
  const authority = await mustRead(`pages.jobAuthorityInfo(${item.jobId})`, () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobAuthorityInfo', [item.jobId])));
  const labelSnapshot = await mustRead(`pages.jobLabelSnapshot(${item.jobId})`, () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobLabelSnapshot', [item.jobId])));
  const labelSnapshotSet = Boolean(labelSnapshot[0]);
  const resolvedLabel = authority[0] ? authority[1] : (labelSnapshotSet ? labelSnapshot[1] : item.exactLabel);
  if (!resolvedLabel) throw new Error(`Missing exactLabel for job ${item.jobId}`);

  let specURI = '';
  let completionURI = '';
  for (const log of context.createdLogs) {
    const parsed = primeIface.parseLog(log);
    if (Number(parsed.args.jobId) === item.jobId) specURI = parsed.args.jobSpecURI;
  }
  for (const log of context.completionLogs) {
    const parsed = primeIface.parseLog(log);
    if (Number(parsed.args.jobId) === item.jobId) completionURI = parsed.args.jobCompletionURI;
  }

  const employer = await safe(() => provider.readContract(context.jobManagerAddress, PRIME_ABI, 'jobEmployerOf', [item.jobId])[0], ethers.ZeroAddress);
  const agent = await safe(() => provider.readContract(context.jobManagerAddress, PRIME_ABI, 'jobAssignedAgentOf', [item.jobId])[0], ethers.ZeroAddress);
  const terminalObserved = [...context.completedLogs, ...context.refundedLogs, ...context.expiredLogs]
    .some((log) => Number(ethers.getBigInt(log.topics[1])) === item.jobId);
  const allowAuth = !terminalObserved;

  const resolvedNode = authority[0]
    ? authority[5]
    : ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [context.jobsRootNode, ethers.id(resolvedLabel)]);
  const nodeOwner = resolvedNode !== ethers.ZeroHash
    ? await mustRead(`ens.owner(${item.jobId})`, () => provider.readContract(context.ensRegistry, ENS_ABI, 'owner', [resolvedNode])[0])
    : ethers.ZeroAddress;
  const wrappedTokenOwner = resolvedNode !== ethers.ZeroHash && nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === context.nameWrapperAddress.toLowerCase()
    ? await mustRead(`nameWrapper.ownerOf(${item.jobId})`, () => provider.readContract(context.nameWrapperAddress, WRAPPER_ABI, 'ownerOf', [BigInt(resolvedNode)])[0])
    : ethers.ZeroAddress;

  const steps = [];
  if (!authority[0]) {
    steps.push({ action: 'repairAuthoritySnapshot', args: [item.jobId, resolvedLabel] });
  }
  if (nodeOwner === ethers.ZeroAddress && employer !== ethers.ZeroAddress) {
    steps.push({ action: 'replayCreateExplicit', args: [item.jobId, employer, specURI] });
  } else if (nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase() && nodeOwner.toLowerCase() !== context.nameWrapperAddress.toLowerCase()) {
    steps.push({ action: 'manualOwnershipIntervention', args: [resolvedNode, nodeOwner] });
  }
  if (nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === context.nameWrapperAddress.toLowerCase() && wrappedTokenOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase()) {
    steps.push({ action: 'manualWrapperTakeoverOrApproval', args: [resolvedNode, wrappedTokenOwner] });
  }
  steps.push({ action: 'repairResolver', args: [item.jobId] });
  if (specURI || completionURI) {
    steps.push({ action: 'repairTextsExplicit', args: [item.jobId, specURI, completionURI] });
  }
  if (employer !== ethers.ZeroAddress || agent !== ethers.ZeroAddress) {
    steps.push({ action: 'repairAuthorisationsExplicit', args: [item.jobId, employer, agent, allowAuth] });
  }
  if (agent !== ethers.ZeroAddress && allowAuth) steps.push({ action: 'replayAssignExplicit', args: [item.jobId, agent] });
  if (completionURI) steps.push({ action: 'replayCompletionExplicit', args: [item.jobId, completionURI] });
  if (!allowAuth) {
    steps.push({ action: 'replayRevokeExplicit', args: [item.jobId, employer, agent] });
    steps.push({ action: 'replayLockExplicit', args: [item.jobId, employer, agent, false] });
  }

  return {
    ...item,
    resolvedLabel,
    resolvedNode,
    nodeOwner,
    wrappedTokenOwner,
    manager: { employer, assignedAgent: agent, specURI, completionURI, terminalObserved },
    steps,
  };
}

function loadInput(file) {
  const raw = fs.readFileSync(file, 'utf8').trim();
  if (!raw) return [];
  if (file.endsWith('.json')) return JSON.parse(raw);
  return raw.split(/\r?\n/).filter(Boolean).map((line) => {
    const [jobId, exactLabel] = line.split(',');
    return { jobId: Number(jobId), exactLabel: String(exactLabel || '').trim() };
  });
}

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new CurlJsonRpcProvider(RPC);
  const iface = new ethers.Interface(PAGES_ABI);
  const items = loadInput(INPUT).map((item) => ({ jobId: Number(item.jobId), exactLabel: item.exactLabel }));
  const jobsRootNode = await mustRead('pages.jobsRootNode', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootNode')[0]);
  const nameWrapperAddress = await mustRead('pages.nameWrapper', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'nameWrapper')[0]);
  const publicResolver = await mustRead('pages.publicResolver', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'publicResolver')[0]);
  const jobManagerAddress = await mustRead('pages.jobManager', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobManager')[0]);
  const ensRegistry = (process.env.ENS_REGISTRY || '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e').trim();
  const createdLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCreated').topicHash);
  const completionLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCompletionRequested').topicHash);
  const completedLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCompleted').topicHash);
  const refundedLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobEmployerRefunded').topicHash);
  const expiredLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobExpired').topicHash);

  const context = { jobsRootNode, nameWrapperAddress, publicResolver, jobManagerAddress, ensRegistry, createdLogs, completionLogs, completedLogs, refundedLogs, expiredLogs };
  const plannedItems = [];
  for (const item of items) plannedItems.push(await buildPlan(provider, item, context));

  const payload = {
    generatedAt: new Date().toISOString(),
    execute,
    input: INPUT,
    jobsRootNode,
    publicResolver,
    items: plannedItems.map((item) => ({
      ...item,
      steps: item.steps.map((step) => ({ ...step, calldata: step.action.startsWith('manual') ? null : iface.encodeFunctionData(step.action, step.args) })),
    })),
  };

  if (execute) {
    if (!process.env.OWNER_PRIVATE_KEY) throw new Error('OWNER_PRIVATE_KEY is required when EXECUTE=1');
    const signer = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY);
    payload.sent = [];
    for (const item of payload.items) {
      for (const step of item.steps.filter((entry) => !entry.action.startsWith('manual'))) {
        const { hash, tx, from } = await provider.sendContractTx(signer, ENS_JOB_PAGES, PAGES_ABI, step.action, step.args);
        const sent = { jobId: item.jobId, exactLabel: item.exactLabel, action: step.action, txHash: hash, status: 'broadcast' };
        payload.sent.push(sent);
        const receipt = await provider.waitForTransaction(hash, 1, 0, { from, nonce: tx.nonce, to: tx.to, data: tx.data, value: tx.value });
        sent.status = 'confirmed';
        sent.blockNumber = receipt.blockNumber.toString();
        if (receipt.replaced) sent.replacedBy = receipt.effectiveHash;
      }
    }
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
