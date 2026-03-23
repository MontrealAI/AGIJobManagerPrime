#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const ENS_REGISTRY = (process.env.ENS_REGISTRY || '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e').trim();
const OUTPUT = path.resolve('scripts/ens/output/repair-job-page.json');
const rawJobId = process.env.JOB_ID || process.argv[2];
const exactLabel = (process.env.EXACT_LABEL || process.argv[3] || '').trim();
const execute = process.env.EXECUTE === '1';
const rootVersionId = Number(process.env.ROOT_VERSION_ID || '0');

const PAGES_ABI = [
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function jobsRootNode() view returns (bytes32)',
  'function nameWrapper() view returns (address)',
  'function publicResolver() view returns (address)',
  'function jobManager() view returns (address)',
  'function repairAuthoritySnapshot(uint256,string)',
  'function repairAuthoritySnapshotExplicit(uint256,string,uint256)',
  'function repairResolver(uint256)',
  'function repairSpecTextExplicit(uint256,string)',
  'function repairCompletionTextExplicit(uint256,string)',
  'function repairTextsExplicit(uint256,string,string)',
  'function repairAuthorisationsExplicit(uint256,address,address,bool)',
  'function replayCreateExplicit(uint256,address,string)',
  'function replayAssignExplicit(uint256,address)',
  'function replayCompletionExplicit(uint256,string)',
  'function replayRevokeExplicit(uint256,address,address)',
  'function replayLockExplicit(uint256,address,address,bool)'
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

async function mustRead(label, fn) {
  try { return await fn(); } catch (error) { throw new Error(`${label} read failed: ${error?.shortMessage || error?.message || String(error)}`); }
}
async function safe(fn, fallback = null) { try { return await fn(); } catch { return fallback; } }
async function getLogs(provider, address, topic0) {
  return provider.getLogs({ address, fromBlock: '0x0', toBlock: 'latest', topics: [topic0] });
}

async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  if (typeof rawJobId === 'undefined') throw new Error('JOB_ID is required; refusing to default to job 0.');
  const jobId = Number(rawJobId);
  if (!Number.isInteger(jobId) || jobId < 0) throw new Error(`Invalid JOB_ID: ${rawJobId}`);

  const provider = new CurlJsonRpcProvider(RPC);
  const authority = await mustRead('pages.jobAuthorityInfo', () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobAuthorityInfo', [jobId])));
  const labelSnapshot = await mustRead('pages.jobLabelSnapshot', () => Array.from(provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobLabelSnapshot', [jobId])));
  const jobsRootNode = await mustRead('pages.jobsRootNode', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobsRootNode')[0]);
  const nameWrapperAddress = await mustRead('pages.nameWrapper', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'nameWrapper')[0]);
  const publicResolver = await mustRead('pages.publicResolver', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'publicResolver')[0]);
  const jobManagerAddress = await mustRead('pages.jobManager', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'jobManager')[0]);
  const selectedRootNode = rootVersionId > 0
    ? await mustRead('pages.rootVersionInfo', () => provider.readContract(ENS_JOB_PAGES, PAGES_ABI, 'rootVersionInfo', [rootVersionId])[0])
    : jobsRootNode;

  const createdLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCreated').topicHash);
  const completionLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCompletionRequested').topicHash);
  const completedLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobCompleted').topicHash);
  const refundedLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobEmployerRefunded').topicHash);
  const expiredLogs = await getLogs(provider, jobManagerAddress, primeIface.getEvent('JobExpired').topicHash);

  let specURI = '';
  let completionURI = '';
  for (const log of createdLogs) {
    const parsed = primeIface.parseLog(log);
    if (Number(parsed.args.jobId) === jobId) specURI = parsed.args.jobSpecURI;
  }
  for (const log of completionLogs) {
    const parsed = primeIface.parseLog(log);
    if (Number(parsed.args.jobId) === jobId) completionURI = parsed.args.jobCompletionURI;
  }
  const terminalObserved = [...completedLogs, ...refundedLogs, ...expiredLogs].some((log) => Number(ethers.getBigInt(log.topics[1])) === jobId);

  const employer = await safe(() => provider.readContract(jobManagerAddress, PRIME_ABI, 'jobEmployerOf', [jobId])[0], ethers.ZeroAddress);
  const agent = await safe(() => provider.readContract(jobManagerAddress, PRIME_ABI, 'jobAssignedAgentOf', [jobId])[0], ethers.ZeroAddress);
  const allowAuth = !terminalObserved;

  const labelSnapshotSet = Boolean(labelSnapshot[0]);
  const resolvedLabel = authority[0] ? authority[1] : (labelSnapshotSet ? labelSnapshot[1] : exactLabel);
  const resolvedNode = authority[0]
    ? authority[5]
    : (resolvedLabel && selectedRootNode !== ethers.ZeroHash ? ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [selectedRootNode, ethers.id(resolvedLabel)]) : ethers.ZeroHash);
  const nodeOwner = resolvedNode !== ethers.ZeroHash ? await mustRead('ens.owner(resolvedNode)', () => provider.readContract(ENS_REGISTRY, ENS_ABI, 'owner', [resolvedNode])[0]) : ethers.ZeroAddress;
  const wrappedTokenOwner = resolvedNode !== ethers.ZeroHash && nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase()
    ? await mustRead('nameWrapper.ownerOf(resolvedNode)', () => provider.readContract(nameWrapperAddress, WRAPPER_ABI, 'ownerOf', [BigInt(resolvedNode)])[0])
    : ethers.ZeroAddress;

  const plan = [];
  if (!authority[0]) {
    if (!resolvedLabel) throw new Error('EXACT_LABEL is required when authority is absent and no snapshotted label exists.');
    if (rootVersionId > 0) plan.push({ action: 'repairAuthoritySnapshotExplicit', args: [jobId, resolvedLabel, rootVersionId] });
    else plan.push({ action: 'repairAuthoritySnapshot', args: [jobId, resolvedLabel] });
  }

  const needsNodeCreate = nodeOwner === ethers.ZeroAddress;
  if (needsNodeCreate && employer !== ethers.ZeroAddress) {
    plan.push({ action: 'replayCreateExplicit', args: [jobId, employer, specURI] });
  }
  if (!needsNodeCreate && nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase() && nodeOwner.toLowerCase() !== nameWrapperAddress.toLowerCase()) {
    plan.push({ action: 'manualOwnershipIntervention', args: [resolvedNode, nodeOwner] });
  }
  if (nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase() && wrappedTokenOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase()) {
    plan.push({ action: 'manualWrapperTakeoverOrApproval', args: [resolvedNode, wrappedTokenOwner] });
  }
  plan.push({ action: 'repairResolver', args: [jobId] });
  if (specURI || completionURI) {
    plan.push({ action: 'repairTextsExplicit', args: [jobId, specURI, completionURI] });
  }
  if (employer !== ethers.ZeroAddress || agent !== ethers.ZeroAddress) {
    plan.push({ action: 'repairAuthorisationsExplicit', args: [jobId, employer, agent, allowAuth] });
  }
  if (agent !== ethers.ZeroAddress && allowAuth) plan.push({ action: 'replayAssignExplicit', args: [jobId, agent] });
  if (completionURI) plan.push({ action: 'replayCompletionExplicit', args: [jobId, completionURI] });
  if (!allowAuth) {
    plan.push({ action: 'replayRevokeExplicit', args: [jobId, employer, agent] });
    plan.push({ action: 'replayLockExplicit', args: [jobId, employer, agent, false] });
  }

  const iface = new ethers.Interface(PAGES_ABI);
  const payload = {
    generatedAt: new Date().toISOString(), rpc: RPC, jobId, exactLabel, rootVersionId, execute,
    authorityEstablished: Boolean(authority[0]), labelSnapshot: { isSet: labelSnapshotSet, label: labelSnapshot[1] || '' },
    manager: { employer, assignedAgent: agent, specURI, completionURI, terminalObserved },
    selectedRootNode, resolvedLabel, resolvedNode, nodeOwner, wrappedTokenOwner, publicResolver,
    plan: plan.map((step) => ({ ...step, calldata: step.action.startsWith('manual') ? null : iface.encodeFunctionData(step.action, step.args) })),
  };

  if (execute) {
    if (!process.env.OWNER_PRIVATE_KEY) throw new Error('OWNER_PRIVATE_KEY is required when EXECUTE=1');
    const signer = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY);
    payload.sent = [];
    for (const step of plan.filter((step) => !step.action.startsWith('manual'))) {
      const { hash, tx, from } = await provider.sendContractTx(signer, ENS_JOB_PAGES, PAGES_ABI, step.action, step.args);
      const receipt = await provider.waitForTransaction(hash, 1, 0, { from, nonce: tx.nonce, to: tx.to, data: tx.data, value: tx.value });
      payload.sent.push({ action: step.action, txHash: hash, blockNumber: receipt.blockNumber.toString() });
    }
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
}

main().catch((error) => {
  const payload = { generatedAt: new Date().toISOString(), rpc: RPC, jobId: typeof rawJobId === 'undefined' ? null : rawJobId, exactLabel, rootVersionId, execute, error: error?.message || String(error) };
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.error(error);
  process.exitCode = 1;
});
