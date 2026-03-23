const { createRequire } = require('node:module');
const path = require('node:path');

const requireFromHere = createRequire(__filename);

function loadEthers() {
  const candidates = [
    path.resolve(__dirname, '../../../hardhat/node_modules/ethers'),
    'ethers',
  ];

  for (const candidate of candidates) {
    try {
      const mod = requireFromHere(candidate);
      return mod.ethers || mod;
    } catch (error) {
      if (candidate === candidates[candidates.length - 1]) throw error;
    }
  }
}

const raw = loadEthers();
const isV6 = typeof raw.ZeroAddress === 'string';

function compat() {
  if (isV6) return raw;
  const utils = raw.utils;
  return {
    ...raw,
    ZeroAddress: raw.constants.AddressZero,
    ZeroHash: raw.constants.HashZero,
    Contract: raw.Contract,
    JsonRpcProvider: raw.providers.JsonRpcProvider,
    Interface: utils.Interface,
    Wallet: raw.Wallet,
    toBeHex: (value) => utils.hexValue(value),
    id: utils.id,
    namehash: utils.namehash,
    ensNormalize: (value) => value.trim().toLowerCase(),
    solidityPackedKeccak256: (types, values) => utils.solidityKeccak256(types, values),
  };
}

module.exports = { ethers: compat() };
