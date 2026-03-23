#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const OUTPUT = path.resolve('scripts/ens/output/repair-job-page.json');
const jobId = Number(process.env.JOB_ID || process.argv[2] || '0');
const exactLabel = process.env.EXACT_LABEL || process.argv[3] || '';
const execute = process.env.EXECUTE === '1';

const ABI = [
  'function jobAuthorityInfo(uint256) view returns (bool,string,bytes32,uint32,bytes32,bytes32,uint8,uint32,uint64,bool,bool,bool)',
  'function jobLabelSnapshot(uint256) view returns (bool,string)',
  'function repairAuthoritySnapshot(uint256,string)',
  'function repairResolver(uint256)',
  'function repairTexts(uint256)',
  'function repairAuthorisations(uint256)',
  'function replayAssign(uint256)',
  'function replayCompletion(uint256)',
  'function replayRevoke(uint256)',
  'function replayLock(uint256,bool)',
];

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  const pages = new ethers.Contract(ENS_JOB_PAGES, ABI, provider);
  const authority = await pages.jobAuthorityInfo(jobId).catch(() => null);
  const labelSnapshot = await pages.jobLabelSnapshot(jobId).catch(() => [false, '']);

  const plan = [];
  if (!authority || !authority[0]) plan.push({ action: 'repairAuthoritySnapshot', args: [jobId, exactLabel] });
  plan.push({ action: 'repairResolver', args: [jobId] });
  plan.push({ action: 'repairTexts', args: [jobId] });
  plan.push({ action: 'repairAuthorisations', args: [jobId] });

  const iface = new ethers.Interface(ABI);
  const payload = {
    generatedAt: new Date().toISOString(),
    jobId,
    exactLabel,
    labelSnapshot: { isSet: Boolean(labelSnapshot[0]), label: labelSnapshot[1] || '' },
    authorityEstablished: Boolean(authority && authority[0]),
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
