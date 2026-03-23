#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const ENS_REGISTRY = (process.env.ENS_REGISTRY || '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e').trim();
const OUTPUT = path.resolve('scripts/ens/output/repair-job-page.json');
const rawJobId = process.env.JOB_ID || process.argv[2];
const exactLabel = (process.env.EXACT_LABEL || process.argv[3] || '').trim();
const execute = process.env.EXECUTE === '1';

const ABI = [
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function jobsRootNode() view returns (bytes32)',
  'function repairAuthoritySnapshot(uint256,string)',
  'function replayCreate(uint256)',
  'function migrateLegacyWrappedJobPage(uint256,string)',
  'function repairResolver(uint256)',
  'function repairTexts(uint256)',
  'function repairAuthorisations(uint256)',
  'function replayAssign(uint256)',
  'function replayCompletion(uint256)',
  'function replayRevoke(uint256)',
  'function replayLock(uint256,bool)',
];

const ENS_ABI = ['function owner(bytes32) view returns (address)'];
const WRAPPER_ABI = ['function ownerOf(uint256) view returns (address)'];
const PRIME_VIEW_ABI = [
  'function getJobCore(uint256) view returns (address employer,address assignedAgent,uint256 payout,uint256 duration,uint256 assignedAt,bool completed,bool disputed,bool expired,uint8 agentPayoutPct)',
  'function getJobSpecURI(uint256) view returns (string)',
  'function getJobCompletionURI(uint256) view returns (string)',
  'function jobManager() view returns (address)',
];

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  if (typeof rawJobId === 'undefined') {
    throw new Error('JOB_ID is required; refusing to default to job 0.');
  }
  const jobId = Number(rawJobId);
  if (!Number.isInteger(jobId) || jobId < 0) {
    throw new Error(`Invalid JOB_ID: ${rawJobId}`);
  }

  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  const pages = new ethers.Contract(ENS_JOB_PAGES, ABI, provider);
  const ens = new ethers.Contract(ENS_REGISTRY, ENS_ABI, provider);
  const authority = await pages.jobAuthorityInfo(jobId).catch(() => null);
  const labelSnapshot = await pages.jobLabelSnapshot(jobId).catch(() => [false, '']);
  const jobsRootNode = await pages.jobsRootNode().catch(() => ethers.ZeroHash);
  const pagesRead = new ethers.Contract(ENS_JOB_PAGES, [...ABI, 'function nameWrapper() view returns (address)'], provider);
  const jobManagerAddress = await new ethers.Contract(ENS_JOB_PAGES, PRIME_VIEW_ABI, provider).jobManager().catch(() => ethers.ZeroAddress);
  const manager = jobManagerAddress !== ethers.ZeroAddress ? new ethers.Contract(jobManagerAddress, PRIME_VIEW_ABI, provider) : null;
  const nameWrapperAddress = await pagesRead.nameWrapper().catch(() => ethers.ZeroAddress);
  const wrapper = new ethers.Contract(nameWrapperAddress, WRAPPER_ABI, provider);

  const plan = [];
  const labelSnapshotSet = Boolean(labelSnapshot[0]);
  const requiresAuthorityRepair = !authority || !authority[0];
  const exactLabelRequired = requiresAuthorityRepair && !labelSnapshotSet;
  if (exactLabelRequired && !exactLabel) {
    throw new Error(
      'EXACT_LABEL is required when planning authority repair for an unsnapshotted job; refusing to default to preview label.'
    );
  }
  if (requiresAuthorityRepair) {
    plan.push({ action: 'repairAuthoritySnapshot', args: [jobId, exactLabel] });
  }

  const resolvedLabel = authority && authority[0] ? authority[1] : (labelSnapshotSet ? labelSnapshot[1] : exactLabel);
  const resolvedNode = authority && authority[0]
    ? authority[5]
    : (resolvedLabel && jobsRootNode !== ethers.ZeroHash
      ? ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [jobsRootNode, ethers.id(resolvedLabel)])
      : ethers.ZeroHash);
  const nodeOwner = resolvedNode !== ethers.ZeroHash ? await ens.owner(resolvedNode).catch(() => ethers.ZeroAddress) : ethers.ZeroAddress;
  const wrappedTokenOwner = resolvedNode !== ethers.ZeroHash && nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase()
    ? await wrapper.ownerOf(BigInt(resolvedNode)).catch(() => ethers.ZeroAddress)
    : ethers.ZeroAddress;
  const requiresLegacyMigration = nodeOwner !== ethers.ZeroAddress
    && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase()
    && wrappedTokenOwner !== ethers.ZeroAddress
    && wrappedTokenOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase();
  const needsCreateReplay = nodeOwner === ethers.ZeroAddress;
  const hasReadableCore = manager ? Boolean(await manager.getJobCore(jobId).catch(() => null)) : false;

  if (requiresLegacyMigration) {
    if (!resolvedLabel) {
      throw new Error('Exact legacy label is required to route unmanaged wrapped pages to migrateLegacyWrappedJobPage.');
    }
    plan.push({ action: 'migrateLegacyWrappedJobPage', args: [jobId, resolvedLabel] });
  } else {
    if (needsCreateReplay) {
      plan.push({ action: 'replayCreate', args: [jobId] });
    }
    plan.push({ action: 'repairResolver', args: [jobId] });
    if (hasReadableCore) {
      plan.push({ action: 'repairTexts', args: [jobId] });
      plan.push({ action: 'repairAuthorisations', args: [jobId] });
    }
  }

  const iface = new ethers.Interface(ABI);
  const payload = {
    generatedAt: new Date().toISOString(),
    jobId,
    exactLabel,
    labelSnapshot: { isSet: labelSnapshotSet, label: labelSnapshot[1] || '' },
    authorityEstablished: Boolean(authority && authority[0]),
    exactLabelRequired,
    resolvedLabel,
    resolvedNode,
    nodeOwner,
    wrappedTokenOwner,
    hasReadableCore,
    needsCreateReplay,
    requiresLegacyMigration,
    execute,
    plan: plan.map((step) => ({ ...step, calldata: iface.encodeFunctionData(step.action, step.args) })),
  };

  if (execute) {
    if (!process.env.OWNER_PRIVATE_KEY) throw new Error('OWNER_PRIVATE_KEY is required when EXECUTE=1');
    const signer = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY, provider);
    const writePages = pages.connect(signer);
    payload.sent = [];
    for (const step of plan) {
      const tx = await writePages[step.action](...step.args);
      const receipt = await tx.wait();
      payload.sent.push({ action: step.action, txHash: receipt.hash, blockNumber: receipt.blockNumber });
    }
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
