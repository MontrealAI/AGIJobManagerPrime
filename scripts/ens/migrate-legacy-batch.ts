#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { createRequire } = require('node:module');

const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../hardhat/node_modules/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const INPUT = process.env.INPUT || process.argv[2] || 'scripts/ens/output/legacy-job-labels.json';
const OUTPUT = path.resolve('scripts/ens/output/migrate-legacy-batch.json');
const execute = process.env.EXECUTE === '1';

const ABI = ['function migrateLegacyWrappedJobPage(uint256,string)'];

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
  const iface = new ethers.Interface(ABI);
  const items = loadInput(INPUT).map((item) => ({ jobId: Number(item.jobId), exactLabel: item.exactLabel }));

  const payload = {
    generatedAt: new Date().toISOString(),
    execute,
    input: INPUT,
    items: items.map((item) => ({
      ...item,
      calldata: iface.encodeFunctionData('migrateLegacyWrappedJobPage', [item.jobId, item.exactLabel]),
    })),
  };

  if (execute) {
    if (!process.env.OWNER_PRIVATE_KEY) throw new Error('OWNER_PRIVATE_KEY is required when EXECUTE=1');
    const signer = new ethers.Wallet(process.env.OWNER_PRIVATE_KEY);
    payload.sent = [];
    for (const item of items) {
      const { hash, tx, from } = await provider.sendContractTx(signer, ENS_JOB_PAGES, ABI, 'migrateLegacyWrappedJobPage', [item.jobId, item.exactLabel]);
      const sent = { jobId: item.jobId, exactLabel: item.exactLabel, txHash: hash, status: 'broadcast' };
      payload.sent.push(sent);
      const receipt = await provider.waitForTransaction(hash, 1, 0, { from, nonce: tx.nonce });
      sent.status = 'confirmed';
      sent.blockNumber = receipt.blockNumber.toString();
      if (receipt.replaced) {
        sent.replacedBy = receipt.effectiveHash;
      }
    }
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
