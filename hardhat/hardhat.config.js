require('dotenv').config();
require('@nomicfoundation/hardhat-ethers');
require('@nomicfoundation/hardhat-verify');

const path = require('path');

const { MAINNET_RPC_URL, SEPOLIA_RPC_URL, PRIVATE_KEY, ETHERSCAN_API_KEY, AGI_PRIME_OPTIMIZER_RUNS, AGI_PRIME_VIA_IR } = process.env;

const optimizerRuns = Number.isFinite(Number(AGI_PRIME_OPTIMIZER_RUNS))
  ? Number(AGI_PRIME_OPTIMIZER_RUNS)
  : 1;
const viaIR = AGI_PRIME_VIA_IR === undefined ? true : AGI_PRIME_VIA_IR === '1';

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
