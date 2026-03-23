#!/usr/bin/env node
const fs = require('node:fs');
const path = require('node:path');
const { ethers } = require('./lib/ethers');
const { CurlJsonRpcProvider } = require('./lib/json_rpc');

const RPC = (process.env.MAINNET_RPC_URL || 'https://ethereum-rpc.publicnode.com').trim();
const PRIME = (process.env.AGI_JOB_MANAGER_PRIME || '0xF8fc6572098DDcAc4560E17cA4A683DF30ea993e').trim();
const ENS_JOB_PAGES = (process.env.ENS_JOB_PAGES || '0x97E03F7BFAC116E558A25C8f09aEf09108a2779d').trim();
const OUTPUT = path.resolve('scripts/ens/output/repair-from-logs.json');
const JOB_ID = process.env.JOB_ID ? Number(process.env.JOB_ID) : null;

const PRIME_ABI = [
  'event JobCreated(uint256 indexed jobId,address indexed employer,uint256 payout,uint256 duration,string jobSpecURI,uint8 intakeMode,bytes32 perJobAgentRoot,string details)',
  'event JobCompletionRequested(uint256 indexed jobId,address indexed agent,string jobCompletionURI)',
  'event JobCompleted(uint256 indexed jobId,address indexed agent,uint256 indexed reputationPoints)',
  'event JobEmployerRefunded(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 refund)',
  'event JobExpired(uint256 indexed jobId,address indexed employer,address indexed agent,uint256 payout)',
  'function jobEmployerOf(uint256) view returns (address)',
  'function jobAssignedAgentOf(uint256) view returns (address)'
];
const iface = new ethers.Interface(PRIME_ABI);

async function getLogs(provider, address, topic0) {
  return provider.request('eth_getLogs', [{ address, fromBlock: '0x0', toBlock: 'latest', topics: [topic0] }]);
}
async function safe(fn, fallback = null) { try { return await fn(); } catch { return fallback; } }

(async function main() {
  fs.mkdirSync(path.dirname(OUTPUT), { recursive: true });
  const provider = new CurlJsonRpcProvider(RPC);
  const createdLogs = await getLogs(provider, PRIME, iface.getEvent('JobCreated').topicHash);
  const completionLogs = await getLogs(provider, PRIME, iface.getEvent('JobCompletionRequested').topicHash);
  const completedLogs = await getLogs(provider, PRIME, iface.getEvent('JobCompleted').topicHash);
  const refundedLogs = await getLogs(provider, PRIME, iface.getEvent('JobEmployerRefunded').topicHash);
  const expiredLogs = await getLogs(provider, PRIME, iface.getEvent('JobExpired').topicHash);

  const jobs = new Map();
  for (const log of createdLogs) {
    const parsed = iface.parseLog(log);
    const jobId = Number(parsed.args.jobId);
    if (JOB_ID !== null && jobId !== JOB_ID) continue;
    jobs.set(jobId, { jobId, employer: parsed.args.employer, specURI: parsed.args.jobSpecURI, completionURI: '', terminalObserved: false });
  }
  for (const log of completionLogs) {
    const parsed = iface.parseLog(log);
    const jobId = Number(parsed.args.jobId);
    if (JOB_ID !== null && jobId !== JOB_ID) continue;
    const job = jobs.get(jobId) || { jobId, employer: ethers.ZeroAddress, specURI: '', completionURI: '', terminalObserved: false };
    job.completionURI = parsed.args.jobCompletionURI;
    jobs.set(jobId, job);
  }
  for (const log of [...completedLogs, ...refundedLogs, ...expiredLogs]) {
    const jobId = Number(ethers.getBigInt(log.topics[1]));
    if (JOB_ID !== null && jobId !== JOB_ID) continue;
    const job = jobs.get(jobId) || { jobId, employer: ethers.ZeroAddress, specURI: '', completionURI: '', terminalObserved: false };
    job.terminalObserved = true;
    jobs.set(jobId, job);
  }

  const out = { generatedAt: new Date().toISOString(), rpc: RPC, prime: PRIME, ensJobPages: ENS_JOB_PAGES, jobs: [] };
  for (const job of Array.from(jobs.values()).sort((a, b) => a.jobId - b.jobId)) {
    job.employer = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'jobEmployerOf', [job.jobId])[0], job.employer);
    job.assignedAgent = await safe(() => provider.readContract(PRIME, PRIME_ABI, 'jobAssignedAgentOf', [job.jobId])[0], ethers.ZeroAddress);
    const allowAuth = !job.terminalObserved;
    job.repairCalls = [
      { fn: 'replayCreateExplicit', args: [job.jobId, job.employer, job.specURI] },
      { fn: 'repairTextsExplicit', args: [job.jobId, job.specURI, job.completionURI] },
      { fn: 'repairAuthorisationsExplicit', args: [job.jobId, job.employer, job.assignedAgent, allowAuth] },
      ...(job.assignedAgent !== ethers.ZeroAddress && allowAuth ? [{ fn: 'replayAssignExplicit', args: [job.jobId, job.assignedAgent] }] : []),
      ...(job.completionURI ? [{ fn: 'replayCompletionExplicit', args: [job.jobId, job.completionURI] }] : []),
      ...(!allowAuth ? [{ fn: 'replayRevokeExplicit', args: [job.jobId, job.employer, job.assignedAgent] }, { fn: 'replayLockExplicit', args: [job.jobId, job.employer, job.assignedAgent, false] }] : []),
    ];
    out.jobs.push(job);
  }

  fs.writeFileSync(OUTPUT, `${JSON.stringify(out, null, 2)}\n`);
  console.log(`Wrote ${OUTPUT}`);
})();
