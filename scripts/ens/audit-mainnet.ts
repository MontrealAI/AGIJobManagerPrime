import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const { ethers } = require('../../hardhat/node_modules/ethers');

const RPC = process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com';
const ENS_JOB_PAGES = process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d';
const MANAGER = process.env.AGI_JOB_MANAGER_PRIME || '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e';
const DISCOVERY = process.env.AGI_JOB_DISCOVERY_PRIME || '0xd5ef1dde7ac60488f697ff2a7967a52172a78f29';
const ROOT = ethers.ensNormalize(process.env.JOBS_ROOT_NAME || 'alpha.jobs.agi.eth');
const OUT = path.resolve('scripts/ens/output/audit-mainnet.json');

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC, 1, { staticNetwork: true });
  const payload = {
    generatedAt: new Date().toISOString(),
    rpc: RPC,
    inputs: { ENS_JOB_PAGES, MANAGER, DISCOVERY, ROOT },
    proven: {},
    assumptions: [] as string[],
  } as any;

  try {
    await provider.getBlockNumber();
  } catch (error: any) {
    payload.rpcReachable = false;
    payload.error = error?.message || String(error);
    payload.assumptions.push('Mainnet RPC was unreachable from the current execution environment.');
    fs.writeFileSync(OUT, JSON.stringify(payload, null, 2));
    return;
  }

  payload.rpcReachable = true;
  payload.proven.rootNode = ethers.namehash(ROOT);
  fs.writeFileSync(OUT, JSON.stringify(payload, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
