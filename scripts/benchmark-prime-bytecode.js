const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const MAX_RUNTIME_BYTES = 24576;

const ROOT = path.resolve(__dirname, '..');
const HARDHAT_DIR = path.join(ROOT, 'hardhat');
const CONFIG_PATH = path.join(HARDHAT_DIR, 'hardhat.config.js');

const TARGETS = [
  ['AGIJobManagerPrime', 'contracts/AGIJobManagerPrime.sol', 'AGIJobManagerPrime'],
  ['AGIJobDiscoveryPrime', 'contracts/AGIJobDiscoveryPrime.sol', 'AGIJobDiscoveryPrime'],
];

const matrix = [
  { viaIR: true, runs: 1 },
  { viaIR: true, runs: 20 },
  { viaIR: true, runs: 200 },
  { viaIR: false, runs: 1 },
  { viaIR: false, runs: 200 },
];

function sizeOf(artifactPath) {
  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
  const bytecode = artifact.deployedBytecode || artifact.evm?.deployedBytecode?.object || '';
  const hex = bytecode.startsWith('0x') ? bytecode.slice(2) : bytecode;
  if (!hex) throw new Error(`Missing runtime bytecode in ${artifactPath}`);
  return hex.length / 2;
}

function compileProfile({ viaIR, runs }) {
  const env = {
    ...process.env,
    AGI_PRIME_VIA_IR: viaIR ? '1' : '0',
    AGI_PRIME_OPTIMIZER_RUNS: String(runs),
  };

  try {
    execSync('npm run clean', { cwd: HARDHAT_DIR, env, stdio: 'pipe' });
    execSync('npm run compile', { cwd: HARDHAT_DIR, env, stdio: 'pipe' });

    const sizes = {};
    for (const [name, contractFile, contractName] of TARGETS) {
      const artifactPath = path.join(HARDHAT_DIR, 'artifacts', contractFile, `${contractName}.json`);
      sizes[name] = sizeOf(artifactPath);
    }
    return { ok: true, ...sizes };
  } catch (err) {
    const stderr = String(err?.stderr || err?.message || err).trim();
    const reason = stderr.split('\n').slice(-6).join(' | ');
    return { ok: false, reason };
  }
}

function main() {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(`Missing hardhat config at ${CONFIG_PATH}`);
  }

  const rows = [];
  for (const profile of matrix) {
    const sizes = compileProfile(profile);
    rows.push({ ...profile, ...sizes });
  }

  const successful = rows.filter((r) => r.ok);
  const eip170Safe = successful.filter((r) =>
    r.AGIJobManagerPrime <= MAX_RUNTIME_BYTES && r.AGIJobDiscoveryPrime <= MAX_RUNTIME_BYTES
  );
  successful.sort((a, b) => a.AGIJobManagerPrime - b.AGIJobManagerPrime);
  eip170Safe.sort((a, b) => a.AGIJobManagerPrime - b.AGIJobManagerPrime);

  console.log('Prime bytecode benchmark (runtime bytes):');
  console.table(rows.map((r) => ({
    viaIR: r.viaIR,
    optimizerRuns: r.runs,
    status: r.ok ? 'ok' : 'compile_failed',
    AGIJobManagerPrime: r.ok ? r.AGIJobManagerPrime : '-',
    AGIJobDiscoveryPrime: r.ok ? r.AGIJobDiscoveryPrime : '-',
    managerMarginToEIP170: r.ok ? 24576 - r.AGIJobManagerPrime : '-',
  })));

  if (!successful.length) {
    const profileErrors = rows
      .map((r) => `- viaIR=${r.viaIR}, runs=${r.runs}: ${r.reason || 'unknown compile failure'}`)
      .join('\n');
    throw new Error(`No benchmark profile compiled successfully.\nProfile errors:\n${profileErrors}`);
  }
  if (!eip170Safe.length) {
    throw new Error(
      `No compiled profile keeps both AGIJobManagerPrime and AGIJobDiscoveryPrime <= ${MAX_RUNTIME_BYTES} bytes (EIP-170).`
    );
  }
  const best = eip170Safe[0];
  console.log(
    `Best EIP-170-safe Prime profile: viaIR=${best.viaIR}, runs=${best.runs}, ` +
      `AGIJobManagerPrime=${best.AGIJobManagerPrime}, AGIJobDiscoveryPrime=${best.AGIJobDiscoveryPrime}`
  );
}

main();
