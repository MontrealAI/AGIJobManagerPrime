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
const v5Hash = isV6 ? null : (() => {
  try { return requireFromHere('@ethersproject/hash'); } catch { return null; }
})();

function v5EnsNormalize(value) {
  if (v5Hash && typeof v5Hash.ensNormalize === 'function') return v5Hash.ensNormalize(value);
  if (raw.utils && typeof raw.utils.nameprep === 'function') return raw.utils.nameprep(value);
  throw new Error('No ENS normalization helper available in ethers v5 environment');
}

function normalize(value) {
  if (value == null) return value;
  if (!isV6 && raw.BigNumber && raw.BigNumber.isBigNumber && raw.BigNumber.isBigNumber(value)) {
    return BigInt(value.toString());
  }
  if (Array.isArray(value)) {
    const out = value.map((item) => normalize(item));
    for (const key of Object.keys(value)) {
      if (!/^\d+$/.test(key)) out[key] = normalize(value[key]);
    }
    return out;
  }
  if (typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) out[key] = normalize(item);
    return out;
  }
  return value;
}

function wrapContract(contract) {
  return new Proxy(contract, {
    get(target, prop, receiver) {
      const value = Reflect.get(target, prop, receiver);
      if (typeof value !== 'function') return value;
      return (...args) => {
        const result = value.apply(target, args);
        if (!result || typeof result.then !== 'function') return result;
        return result.then((resolved) => normalize(resolved));
      };
    },
  });
}

function compat() {
  if (isV6) return raw;
  const utils = raw.utils;

  class CompatInterface extends utils.Interface {
    decodeFunctionResult(fragment, data) {
      return normalize(super.decodeFunctionResult(fragment, data));
    }
  }

  function CompatContract(...args) {
    return wrapContract(new raw.Contract(...args));
  }

  return {
    ...raw,
    ZeroAddress: raw.constants.AddressZero,
    ZeroHash: raw.constants.HashZero,
    Contract: CompatContract,
    JsonRpcProvider: raw.providers.JsonRpcProvider,
    Interface: CompatInterface,
    Wallet: raw.Wallet,
    toBeHex: (value) => utils.hexValue(value),
    id: utils.id,
    namehash: utils.namehash,
    ensNormalize: (value) => v5EnsNormalize(value),
    solidityPackedKeccak256: (types, values) => utils.solidityKeccak256(types, values),
  };
}

module.exports = { ethers: compat(), normalizeEthersValue: normalize };
