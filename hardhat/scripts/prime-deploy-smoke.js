const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');
const hre = require('hardhat');

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  const mockToken = await hre.ethers.deployContract('MockERC20', []);
  await mockToken.waitForDeployment();

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'prime-smoke-'));
  const configPath = path.join(tempDir, 'deploy.config.js');

  const zero32 = `0x${'00'.repeat(32)}`;
  const configContents = `module.exports = {
  hardhat: {
    agiTokenAddress: '${await mockToken.getAddress()}',
    baseIpfsUrl: 'https://ipfs.io/ipfs/',
    ensConfig: ['${deployer.address}', '${deployer.address}'],
    rootNodes: ['${zero32}', '${zero32}', '${zero32}', '${zero32}'],
    merkleRoots: ['${zero32}', '${zero32}'],
    finalOwner: '${deployer.address}',
  },
};\n`;
  fs.writeFileSync(configPath, configContents, 'utf8');

  const child = spawnSync(
    process.platform === 'win32' ? 'npx.cmd' : 'npx',
    ['hardhat', 'run', 'scripts/deploy.js', '--network', 'hardhat'],
    {
      cwd: path.resolve(__dirname, '..'),
      stdio: 'inherit',
      env: {
        ...process.env,
        DEPLOY_CONFIG: configPath,
        CONFIRMATIONS: '1',
      },
    }
  );

  if (child.status !== 0) {
    throw new Error(`Prime deploy smoke failed with exit code ${child.status}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
