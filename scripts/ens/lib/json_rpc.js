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
    return { hash, tx };
  }

  async waitForTransaction(hash, confirmations = 1, timeoutMs = 0) {
    const start = Date.now();
    for (;;) {
      const receipt = this.getTransactionReceipt(hash);
      if (receipt) {
        if (confirmations <= 1) return receipt;
        const blockNumber = this.getBlockNumber();
        if (BigInt(blockNumber) - BigInt(receipt.blockNumber) + 1n >= BigInt(confirmations)) return receipt;
      }
      if (timeoutMs > 0 && Date.now() - start > timeoutMs) {
        throw new Error(`Timed out waiting for receipt: ${hash}`);
      }
      await new Promise((resolve) => setTimeout(resolve, 3000));
    }
  }
}

module.exports = { CurlJsonRpcProvider, toQuantity };
