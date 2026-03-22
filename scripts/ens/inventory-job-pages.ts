import fs from 'node:fs';
const output = {
  generatedAt: new Date().toISOString(),
  note: 'Populate from a networked run of audit-mainnet.ts and then classify each job as preview-only, authority-snapshotted, legacy-import-required, repairable, or finalized.'
};
fs.writeFileSync('scripts/ens/output/inventory-job-pages.json', JSON.stringify(output, null, 2));
console.log(JSON.stringify(output, null, 2));
