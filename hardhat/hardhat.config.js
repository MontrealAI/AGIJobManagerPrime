require('dotenv').config();
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-verify');

const path = require('path');

const { MAINNET_RPC_URL, SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, AGI_PRIME_OPTIMIZER_RUNS, AGI_PRIME_VIA_IR } = process.env;

function parseOptimizerRuns(raw, fallback = 1) {
  if (raw === undefined) return fallback;
  const normalized = String(raw).trim();
  if (!normalized) return fallback;
  const parsed = Number(normalized);
  if (!Number.isFinite(parsed) || parsed < 0 || !Number.isInteger(parsed)) {
    throw new Error(`Invalid AGI_PRIME_OPTIMIZER_RUNS="${raw}". Expected a non-negative integer.`);
  }
  return parsed;
}

function parseViaIR(raw, fallback = true) {
  if (raw === undefined) return fallback;
  const normalized = String(raw).trim();
  if (!normalized) return fallback;
  if (normalized === '1' || normalized.toLowerCase() === 'true') return true;
  if (normalized === '0' || normalized.toLowerCase() === 'false') return false;
  throw new Error(`Invalid AGI_PRIME_VIA_IR="${raw}". Expected one of: 1, 0, true, false.`);
}

const optimizerRuns = parseOptimizerRuns(AGI_PRIME_OPTIMIZER_RUNS);
const viaIR = parseViaIR(AGI_PRIME_VIA_IR);

function networkConfig(rpcUrl) {
  if (!rpcUrl || !PRIVATE_KEY) return undefined;
  return { url: rpcUrl, accounts: [PRIVATE_KEY] };
}

const networks = {};
const mainnet = networkConfig(MAINNET_RPC_URL);
const sepolia = networkConfig(SEPOLIA_RPC_URL);
if (mainnet) networks.mainnet = mainnet;
if (sepolia) networks.sepolia = sepolia;

module.exports = {
  solidity: {
    version: '0.8.23',
    settings: {
      optimizer: { enabled: true, runs: optimizerRuns },
      evmVersion: 'shanghai',
      viaIR,
      metadata: { bytecodeHash: 'none' },
      debug: { revertStrings: 'strip' },
    },
  },
  paths: {
    root: path.resolve(__dirname, '..'),
    sources: 'contracts',
    artifacts: 'hardhat/artifacts',
    cache: 'hardhat/cache',
  },
  networks,
  etherscan: {
    apiKey: ETHERSCAN_API_KEY || '',
  },
};
