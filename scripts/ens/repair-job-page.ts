#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

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
  'function nameWrapper() view returns (address)',
  'function jobManager() view returns (address)',
];

const ENS_ABI = ['function owner(bytes32) view returns (address)'];
const WRAPPER_ABI = ['function ownerOf(uint256) view returns (address)'];
const PRIME_VIEW_ABI = [
  'function getJobCore(uint256) view returns (address employer,address assignedAgent,uint256 payout,uint256 duration,uint256 assignedAt,bool completed,bool disputed,bool expired,uint8 agentPayoutPct)',
  'function getJobSpecURI(uint256) view returns (string)',
  'function getJobCompletionURI(uint256) view returns (string)',
];

async function mustRead(label, fn) {
  try {
    return await fn();
  } catch (error) {
    throw new Error(`${label} read failed: ${error?.shortMessage || error?.message || String(error)}`);
  }
}

async function isConfirmedCompatibilityBlocker(provider, jobId) {
  try {
    provider.readContract(ENS_JOB_PAGES, ABI, 'nameWrapper');
    provider.readContract(ENS_JOB_PAGES, ABI, 'jobManager');
  } catch {
    return false;
  }

  try {
    provider.readContract(
      ENS_JOB_PAGES,
      ['function configurationStatus() view returns (bool,bool,bool,bool,bool,bool,bool,bool,bool,bool,uint256)'],
      'configurationStatus'
    );
    return false;
  } catch {
    // Treat the combination of stable config getters working while both new authority/status getters revert
    // as a confirmed pre-authoritative deployment mismatch instead of a transient transport failure.
  }

  try {
    provider.readContract(
      ENS_JOB_PAGES,
      ['function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)'],
      'jobAuthorityInfo',
      [jobId]
    );
    return false;
  } catch {
    return true;
  }
}

async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  if (typeof rawJobId === 'undefined') {
    throw new Error('JOB_ID is required; refusing to default to job 0.');
  }
  const jobId = Number(rawJobId);
  if (!Number.isInteger(jobId) || jobId < 0) {
    throw new Error(`Invalid JOB_ID: ${rawJobId}`);
  }

  const provider = new CurlJsonRpcProvider(RPC);
  let authority;
  try {
    authority = await mustRead('pages.jobAuthorityInfo', () => Array.from(provider.readContract(ENS_JOB_PAGES, ABI, 'jobAuthorityInfo', [jobId])));
  } catch (error) {
    if (!(await isConfirmedCompatibilityBlocker(provider, jobId))) {
      throw error;
    }
    const payload = {
      generatedAt: new Date().toISOString(),
      rpc: RPC,
      jobId,
      exactLabel,
      execute,
      compatibilityBlocker: true,
      error: error.message,
      recommendation: 'Live ENSJobPages does not expose jobAuthorityInfo(uint256); deploy the authoritative ENSJobPages replacement before using repair tooling.',
    };
    fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
    console.log(`Wrote ${OUTPUT}`);
    return;
  }
  const labelSnapshot = await mustRead('pages.jobLabelSnapshot', () => Array.from(provider.readContract(ENS_JOB_PAGES, ABI, 'jobLabelSnapshot', [jobId])));
  const jobsRootNode = await mustRead('pages.jobsRootNode', () => provider.readContract(ENS_JOB_PAGES, ABI, 'jobsRootNode')[0]);
  const nameWrapperAddress = await mustRead('pages.nameWrapper', () => provider.readContract(ENS_JOB_PAGES, ABI, 'nameWrapper')[0]);
  const jobManagerAddress = await mustRead('pages.jobManager', () => provider.readContract(ENS_JOB_PAGES, ABI, 'jobManager')[0]);

  const plan = [];
  const labelSnapshotSet = Boolean(labelSnapshot[0]);
  const requiresAuthorityRepair = !authority[0];
  const exactLabelRequired = requiresAuthorityRepair && !labelSnapshotSet;
  if (exactLabelRequired && !exactLabel) {
    throw new Error(
      'EXACT_LABEL is required when planning authority repair for an unsnapshotted job; refusing to default to preview label.'
    );
  }
  if (requiresAuthorityRepair) {
    plan.push({ action: 'repairAuthoritySnapshot', args: [jobId, exactLabel] });
  }

  const resolvedLabel = authority[0] ? authority[1] : (labelSnapshotSet ? labelSnapshot[1] : exactLabel);
  const resolvedNode = authority[0]
    ? authority[5]
    : (resolvedLabel && jobsRootNode !== ethers.ZeroHash
      ? ethers.solidityPackedKeccak256(['bytes32', 'bytes32'], [jobsRootNode, ethers.id(resolvedLabel)])
      : ethers.ZeroHash);
  const nodeOwner = resolvedNode !== ethers.ZeroHash ? await mustRead('ens.owner(resolvedNode)', () => provider.readContract(ENS_REGISTRY, ENS_ABI, 'owner', [resolvedNode])[0]) : ethers.ZeroAddress;
  const wrappedTokenOwner = resolvedNode !== ethers.ZeroHash && nodeOwner !== ethers.ZeroAddress && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase()
    ? await mustRead('nameWrapper.ownerOf(resolvedNode)', () => provider.readContract(nameWrapperAddress, WRAPPER_ABI, 'ownerOf', [BigInt(resolvedNode)])[0])
    : ethers.ZeroAddress;
  const requiresLegacyMigration = nodeOwner !== ethers.ZeroAddress
    && nodeOwner.toLowerCase() === nameWrapperAddress.toLowerCase()
    && wrappedTokenOwner !== ethers.ZeroAddress
    && wrappedTokenOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase();
  const requiresManualNodeTakeover = nodeOwner !== ethers.ZeroAddress
    && nodeOwner.toLowerCase() !== ENS_JOB_PAGES.toLowerCase()
    && nodeOwner.toLowerCase() !== nameWrapperAddress.toLowerCase();
  const needsCreateReplay = nodeOwner === ethers.ZeroAddress;
  const hasReadableCore = Boolean(await mustRead('manager.getJobCore', () => provider.readContract(jobManagerAddress, PRIME_VIEW_ABI, 'getJobCore', [jobId])).catch(() => null));

  if (requiresLegacyMigration) {
    if (!resolvedLabel) {
      throw new Error('Exact legacy label is required to route unmanaged wrapped pages to migrateLegacyWrappedJobPage.');
    }
    plan.push({ action: 'migrateLegacyWrappedJobPage', args: [jobId, resolvedLabel] });
  } else if (requiresManualNodeTakeover) {
    // Unwrapped externally-owned nodes need manual ownership takeover before ENSJobPages repair writes can succeed.
  } else if (!needsCreateReplay) {
    plan.push({ action: 'repairResolver', args: [jobId] });
    if (hasReadableCore) {
      plan.push({ action: 'repairTexts', args: [jobId] });
      plan.push({ action: 'repairAuthorisations', args: [jobId] });
    }
  } else if (hasReadableCore) {
    plan.push({ action: 'replayCreate', args: [jobId] });
    plan.push({ action: 'repairResolver', args: [jobId] });
    plan.push({ action: 'repairTexts', args: [jobId] });
    plan.push({ action: 'repairAuthorisations', args: [jobId] });
  }

  const iface = new ethers.Interface(ABI);
  const payload = {
    generatedAt: new Date().toISOString(),
    rpc: RPC,
    jobId,
    exactLabel,
    labelSnapshot: { isSet: labelSnapshotSet, label: labelSnapshot[1] || '' },
    authorityEstablished: Boolean(authority[0]),
    exactLabelRequired,
    resolvedLabel,
    resolvedNode,
    nodeOwner,
    wrappedTokenOwner,
    hasReadableCore,
    needsCreateReplay,
    requiresLegacyMigration,
    requiresManualNodeTakeover,
    execute,
    plan: plan.map((step) => ({ ...step, calldata: iface.encodeFunctionData(step.action, step.args) })),
  };

  if (execute) {
    if (!process.env.OWNER_PRIVATE_KEY) throw new Error('OWNER_PRIVATE_KEY is required when EXECUTE=1');
    const signer = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY);
    payload.sent = [];
    for (const step of plan) {
      const { hash } = await provider.sendContractTx(signer, ENS_JOB_PAGES, ABI, step.action, step.args);
      const sent = { action: step.action, txHash: hash, status: 'broadcast' };
      payload.sent.push(sent);
      const receipt = await provider.waitForTransaction(hash);
      sent.status = 'confirmed';
      sent.blockNumber = receipt.blockNumber.toString();
    }
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
}

main().catch((error) => {
  const payload = {
    generatedAt: new Date().toISOString(),
    rpc: RPC,
    jobId: typeof rawJobId === 'undefined' ? null : rawJobId,
    exactLabel,
    execute,
    error: error?.message || String(error),
  };
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.error(error);
  process.exitCode = 1;
});
