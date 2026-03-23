#!/usr/bin/env node
const { execFileSync } = require('node:child_process');
const { createRequire } = require('node:module');
const requireFromHere = createRequire(__filename);
const { ethers } = requireFromHere('../../../hardhat/node_modules/ethers');

function toQuantity(value) {
  return ethers.toBeHex(value);
}

class CurlJsonRpcProvider {
  constructor(url) {
    this.url = url;
    this.id = 0;
  }

  request(method, params = []) {
    const payload = JSON.stringify({ jsonrpc: '2.0', id: ++this.id, method, params });
    const raw = execFileSync('curl', [
      '-sS', '--fail-with-body', '-m', '30',
      '-H', 'content-type: application/json',
      '--data', payload,
      this.url,
    ], { encoding: 'utf8' });
    const parsed = JSON.parse(raw);
    if (parsed.error) {
      throw new Error(`${method} failed: ${parsed.error.message || JSON.stringify(parsed.error)}`);
    }
    return parsed.result;
  }

  getBlock(tag = 'latest', hydrated = false) {
    return this.request('eth_getBlockByNumber', [tag === 'latest' ? 'latest' : toQuantity(tag), hydrated]);
  }

  getBlockNumber() {
    return BigInt(this.request('eth_blockNumber'));
  }

  getChainId() {
    return BigInt(this.request('eth_chainId'));
  }

  getGasPrice() {
    return BigInt(this.request('eth_gasPrice'));
  }

  getMaxPriorityFeePerGas() {
    return BigInt(this.request('eth_maxPriorityFeePerGas'));
  }

  getTransactionCount(address, tag = 'pending') {
    return BigInt(this.request('eth_getTransactionCount', [address, tag]));
  }

  estimateGas(tx) {
    return BigInt(this.request('eth_estimateGas', [tx]));
  }

  sendRawTransaction(rawTx) {
    return this.request('eth_sendRawTransaction', [rawTx]);
  }

  getTransactionReceipt(hash) {
    return this.request('eth_getTransactionReceipt', [hash]);
  }

  getBlockWithTransactions(tag = 'latest') {
    if (typeof tag === 'string' && tag.startsWith('0x') && tag.length === 66) {
      return this.request('eth_getBlockByHash', [tag, true]);
    }
    return this.request('eth_getBlockByNumber', [tag === 'latest' ? 'latest' : toQuantity(tag), true]);
  }

  call(tx, tag = 'latest') {
    return this.request('eth_call', [tx, tag]);
  }

  readContract(address, abi, method, args = []) {
    const iface = Array.isArray(abi) ? new ethers.Interface(abi) : abi;
    const data = iface.encodeFunctionData(method, args);
    const raw = this.call({ to: address, data });
    return iface.decodeFunctionResult(method, raw);
  }

  async sendContractTx(wallet, address, abi, method, args = [], overrides = {}) {
    const iface = Array.isArray(abi) ? new ethers.Interface(abi) : abi;
    const chainId = Number(this.getChainId());
    const from = wallet.address;
    const nonce = this.getTransactionCount(from, 'pending');
    const data = iface.encodeFunctionData(method, args);

    let gasLimit = overrides.gasLimit;
    if (!gasLimit) {
      gasLimit = this.estimateGas({ from, to: address, data, value: overrides.value ? toQuantity(overrides.value) : '0x0' });
      gasLimit = (BigInt(gasLimit) * 12n) / 10n;
    }

    let maxPriorityFeePerGas;
    let maxFeePerGas;
    const latest = this.getBlock('latest', false);
    if (latest && latest.baseFeePerGas !== undefined) {
      maxPriorityFeePerGas = overrides.maxPriorityFeePerGas ?? this.getMaxPriorityFeePerGas();
      maxFeePerGas = overrides.maxFeePerGas ?? (BigInt(latest.baseFeePerGas) * 2n + BigInt(maxPriorityFeePerGas));
    }

    const tx = {
      chainId,
      nonce,
      to: address,
      data,
      value: overrides.value ?? 0n,
      gasLimit,
    };
    if (maxFeePerGas !== undefined && maxPriorityFeePerGas !== undefined) {
      tx.maxFeePerGas = maxFeePerGas;
      tx.maxPriorityFeePerGas = maxPriorityFeePerGas;
      tx.type = 2;
    } else {
      tx.gasPrice = overrides.gasPrice ?? this.getGasPrice();
      tx.type = 0;
    }

    const signed = await wallet.signTransaction(tx);
    const hash = this.sendRawTransaction(signed);
    return { hash, tx, from };
  }

  async waitForTransaction(hash, confirmations = 1, timeoutMs = 0, replacementContext = null) {
    const start = Date.now();
    for (;;) {
      let receipt = this.getTransactionReceipt(hash);
      let effectiveHash = hash;

      if (!receipt && replacementContext && replacementContext.from !== undefined && replacementContext.nonce !== undefined) {
        const replacement = this.findReplacementReceipt(replacementContext.from, replacementContext.nonce);
        if (replacement) {
          if (!this.isSameTransactionIntent(replacement.tx, replacementContext)) {
            throw new Error(
              `Transaction nonce was replaced by a different transaction: ${replacement.hash} replaced ${hash}`
            );
          }
          receipt = replacement.receipt;
          effectiveHash = replacement.hash;
        }
      }

      if (receipt) {
        if (receipt.status === '0x0') {
          throw new Error(
            effectiveHash === hash
              ? `Transaction reverted on-chain: ${effectiveHash}`
              : `Replacement transaction reverted on-chain: ${effectiveHash} (replaced ${hash})`
          );
        }
        if (confirmations <= 1) return { ...receipt, effectiveHash, replaced: effectiveHash !== hash };
        const blockNumber = this.getBlockNumber();
        if (BigInt(blockNumber) - BigInt(receipt.blockNumber) + 1n >= BigInt(confirmations)) {
          return { ...receipt, effectiveHash, replaced: effectiveHash !== hash };
        }
      }
      if (timeoutMs > 0 && Date.now() - start > timeoutMs) {
        throw new Error(`Timed out waiting for receipt: ${hash}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }

  findReplacementReceipt(from, nonce, scanDepth = 32) {
    const latestNonce = this.getTransactionCount(from, 'latest');
    if (latestNonce <= BigInt(nonce)) return null;

    let blockTag = 'latest';
    for (let i = 0; i < scanDepth; i += 1) {
      const block = this.getBlockWithTransactions(blockTag);
      if (!block) break;
      for (const tx of block.transactions || []) {
        if (!tx || !tx.from) continue;
        if (tx.from.toLowerCase() !== from.toLowerCase()) continue;
        if (BigInt(tx.nonce) !== BigInt(nonce)) continue;
        const receipt = this.getTransactionReceipt(tx.hash);
        if (receipt) return { hash: tx.hash, tx, receipt };
      }
      if (!block.parentHash || block.parentHash === '0x0000000000000000000000000000000000000000000000000000000000000000') break;
      blockTag = block.parentHash;
    }
    return null;
  }

  isSameTransactionIntent(replacementTx, originalTx) {
    if (!replacementTx || !originalTx) return false;
    const replacementTo = (replacementTx.to || '').toLowerCase();
    const originalTo = (originalTx.to || '').toLowerCase();
    if (replacementTo !== originalTo) return false;
    if ((replacementTx.input || replacementTx.data || '0x') !== (originalTx.data || originalTx.input || '0x')) return false;
    const replacementValue = BigInt(replacementTx.value || '0x0');
    const originalValue = BigInt(originalTx.value || 0);
    return replacementValue === originalValue;
  }
}

module.exports = { CurlJsonRpcProvider, toQuantity };
