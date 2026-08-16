import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { gzipSync } from "node:zlib";

const COLLECTION = "MONTREAL.AI — BECOMING: GENESIS 556";
const CONTRACT = "0x495f947276749ce646f68ac8c248420045cb7b5e";
const CREATOR = "0x054a2e4b3b5ea2c62372e92358fdf7fb74b4f34a";
const CHAIN_ID = 1;
const EXPECTED_COUNT = 556;
const EXPECTED_SUPPLY = 1;
const EXCLUDED_NONCES = new Set([161, 495, 523]);
const BLOCKSCOUT = "https://eth.blockscout.com/api/v2";
const RPC_URL = "https://eth.blockscout.com/api/eth-rpc";
const OUT = process.env.SNAPSHOT_OUT || "snapshot_output";
const WORKERS = Number(process.env.SNAPSHOT_WORKERS || 4);
const TIMEOUT_MS = Number(process.env.SNAPSHOT_HTTP_TIMEOUT_MS || 45000);
const RETRIES = Number(process.env.SNAPSHOT_HTTP_RETRIES || 8);
const BALANCE_BATCH_SIZE = Number(process.env.SNAPSHOT_BALANCE_BATCH_SIZE || 80);

const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const utcNow = () => new Date().toISOString();

function normalizeAddress(value) {
  if (value && typeof value === "object") {
    for (const key of ["hash", "address_hash", "address", "owner"]) {
      const result = normalizeAddress(value[key]);
      if (result) return result;
    }
    return null;
  }
  if (typeof value !== "string") return null;
  const v = value.trim().toLowerCase();
  return /^0x[0-9a-f]{40}$/.test(v) ? v : null;
}

function titleNumber(value) {
  if (typeof value !== "string") return null;
  const m = value.match(/#\s*0*([0-9]{1,4})\b/);
  return m ? Number(m[1]) : null;
}

function hexWord(value) {
  return BigInt(value).toString(16).padStart(64, "0");
}

function buildManifest() {
  const nonces = [];
  for (let nonce = 5; nonce <= 563; nonce++) {
    if (!EXCLUDED_NONCES.has(nonce)) nonces.push(nonce);
  }
  if (nonces.length !== EXPECTED_COUNT) throw new Error(`Bad nonce count: ${nonces.length}`);
  [nonces[257], nonces[258]] = [nonces[258], nonces[257]];
  const creator = BigInt(CREATOR);
  const rows = nonces.map((nonce, index) => {
    const canonicalNumber = index + 1;
    const tokenId = (creator << 96n) | (BigInt(nonce) << 40n) | 1n;
    const decimal = tokenId.toString();
    return {
      canonical_number: canonicalNumber,
      title: `Crypto AI Art #${String(canonicalNumber).padStart(3, "0")}`,
      chain_id: CHAIN_ID,
      contract: CONTRACT,
      standard: "ERC-1155",
      token_id_decimal: decimal,
      token_id_hex: `0x${tokenId.toString(16).padStart(64, "0")}`,
      creator_encoded: CREATOR,
      internal_nonce: nonce,
      edition_supply: EXPECTED_SUPPLY,
      opensea_item_url: `https://opensea.io/item/ethereum/${CONTRACT}/${decimal}`,
      blockscout_item_url: `https://eth.blockscout.com/token/${CONTRACT}/instance/${decimal}`
    };
  });
  if (new Set(rows.map(row => row.token_id_decimal)).size !== EXPECTED_COUNT) {
    throw new Error("Token IDs are not unique");
  }
  return rows;
}

async function fetchJson(url, options = {}, allow404 = false) {
  let lastError;
  for (let attempt = 0; attempt <= RETRIES; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      const response = await fetch(url, {
        ...options,
        signal: controller.signal,
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "User-Agent": "MONTREALAI-Becoming-Genesis-556-Snapshot/3.0",
          ...(options.headers || {})
        }
      });
      clearTimeout(timer);
      if (allow404 && response.status === 404) return null;
      if (response.status === 429 || response.status >= 500) {
        throw new Error(`HTTP ${response.status}: ${(await response.text()).slice(0, 300)}`);
      }
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${(await response.text()).slice(0, 500)}`);
      }
      return await response.json();
    } catch (error) {
      clearTimeout(timer);
      lastError = error;
      if (attempt >= RETRIES) break;
      await sleep(Math.min(30000, 750 * 2 ** attempt));
    }
  }
  throw new Error(`Request failed for ${url}: ${lastError}`);
}

async function rpc(method, params, retries = RETRIES) {
  let lastError;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const body = await fetchJson(RPC_URL, {
        method: "POST",
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params })
      });
      if (body.error) throw new Error(JSON.stringify(body.error));
      if (!Object.prototype.hasOwnProperty.call(body, "result")) {
        throw new Error(`Malformed RPC response: ${JSON.stringify(body).slice(0, 500)}`);
      }
      return body.result;
    } catch (error) {
      lastError = error;
      if (attempt >= retries) break;
      await sleep(Math.min(30000, 750 * 2 ** attempt));
    }
  }
  throw new Error(`RPC ${method} failed: ${lastError}`);
}

async function paginate(url) {
  const items = [];
  let next = new URL(url);
  const seen = new Set();
  for (let page = 0; page < 200; page++) {
    const fingerprint = next.toString();
    if (seen.has(fingerprint)) throw new Error(`Pagination loop: ${fingerprint}`);
    seen.add(fingerprint);
    const payload = await fetchJson(fingerprint);
    for (const item of payload.items || []) {
      if (item && typeof item === "object") items.push(item);
    }
    const params = payload.next_page_params;
    if (!params || typeof params !== "object" || Object.keys(params).length === 0) return items;
    next = new URL(url);
    for (const [key, value] of Object.entries(params)) {
      if (value !== null && value !== undefined) next.searchParams.set(key, String(value));
    }
  }
  throw new Error(`Pagination exceeded limit: ${url}`);
}

async function runPool(items, concurrency, worker, progressLabel) {
  const results = new Array(items.length);
  let cursor = 0;
  let completed = 0;
  async function lane() {
    while (true) {
      const index = cursor++;
      if (index >= items.length) return;
      results[index] = await worker(items[index], index);
      completed++;
      if (completed % 25 === 0 || completed === items.length) {
        console.log(`${progressLabel}: ${completed}/${items.length}`);
      }
    }
  }
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, () => lane()));
  return results;
}

async function discover(row) {
  const tokenId = row.token_id_decimal;
  const instanceUrl = `${BLOCKSCOUT}/tokens/${CONTRACT}/instances/${tokenId}`;
  const holdersUrl = `${instanceUrl}/holders`;
  const candidates = new Set([CREATOR]);
  const holderValues = {};
  const ensByAddress = {};
  let instance = null;
  let instanceError = "";
  let holdersError = "";
  try {
    instance = await fetchJson(instanceUrl, {}, true);
    const owner = normalizeAddress(instance?.owner) || normalizeAddress(instance?.holder_address_hash);
    if (owner) candidates.add(owner);
  } catch (error) {
    instanceError = String(error);
  }
  try {
    const holders = await paginate(holdersUrl);
    for (const item of holders) {
      const address = normalizeAddress(item.address_hash) || normalizeAddress(item.address) ||
        normalizeAddress(item.holder_address_hash) || normalizeAddress(item.holder);
      if (!address) continue;
      candidates.add(address);
      const raw = item.value ?? item.balance ?? "0";
      let value = 0n;
      try { value = BigInt(raw); } catch {}
      holderValues[address] = (BigInt(holderValues[address] || "0") + value).toString();
      const obj = item.address_hash && typeof item.address_hash === "object"
        ? item.address_hash
        : item.address && typeof item.address === "object" ? item.address : null;
      if (obj?.ens_domain_name) ensByAddress[address] = String(obj.ens_domain_name);
    }
  } catch (error) {
    holdersError = String(error);
  }
  const metadata = instance?.metadata && typeof instance.metadata === "object" ? instance.metadata : {};
  const metadataName = String(metadata.name || "");
  const returnedId = instance?.id === undefined || instance?.id === null ? "" : String(instance.id);
  const tokenObject = instance?.token && typeof instance.token === "object" ? instance.token : {};
  const returnedContract = String(tokenObject.address_hash || tokenObject.address || "").toLowerCase();
  const metadataNumber = titleNumber(metadataName);
  return {
    canonical_number: row.canonical_number,
    token_id_decimal: tokenId,
    expected_title: row.title,
    instance_status: instance ? "FOUND" : instanceError ? "ERROR" : "MISSING",
    returned_id: returnedId,
    id_match: returnedId ? returnedId === tokenId : null,
    returned_contract: returnedContract,
    contract_match: returnedContract ? returnedContract === CONTRACT : null,
    metadata_name: metadataName,
    metadata_number: metadataNumber,
    metadata_number_match: metadataNumber === null ? null : metadataNumber === row.canonical_number,
    is_unique: instance?.is_unique ?? null,
    blockscout_owner: normalizeAddress(instance?.owner) || normalizeAddress(instance?.holder_address_hash) || "",
    reported_holder_count: Object.keys(holderValues).length,
    reported_holder_balance_sum: Object.values(holderValues).reduce((a, b) => a + BigInt(b), 0n).toString(),
    candidate_addresses: [...candidates].sort(),
    holder_values: holderValues,
    ens_by_address: ensByAddress,
    instance_error: instanceError,
    holders_error: holdersError,
    instance_source_url: instanceUrl,
    holders_source_url: holdersUrl
  };
}

async function selectSnapshotBlock() {
  const chainId = Number(BigInt(await rpc("eth_chainId", [])));
  if (chainId !== CHAIN_ID) throw new Error(`Unexpected chain ID ${chainId}`);
  for (const tag of ["finalized", "safe"]) {
    try {
      const block = await rpc("eth_getBlockByNumber", [tag, false], 3);
      if (block?.number && block?.hash) return { block, requested_tag: tag };
    } catch (error) {
      console.log(`Block tag ${tag} unavailable: ${error}`);
    }
  }
  const latest = BigInt(await rpc("eth_blockNumber", []));
  const target = latest > 64n ? latest - 64n : latest;
  const numberHex = `0x${target.toString(16)}`;
  const block = await rpc("eth_getBlockByNumber", [numberHex, false], 3);
  if (!block?.number || !block?.hash) throw new Error("Could not select fallback snapshot block");
  return { block, requested_tag: "latest-minus-64" };
}

function encodeBalanceOfBatch(pairs) {
  const n = pairs.length;
  const accounts = hexWord(n) + pairs.map(([, address]) => address.slice(2).padStart(64, "0")).join("");
  const ids = hexWord(n) + pairs.map(([tokenId]) => hexWord(tokenId)).join("");
  const offsetAccounts = 64n;
  const offsetIds = offsetAccounts + BigInt(accounts.length / 2);
  return `0x4e1273f4${hexWord(offsetAccounts)}${hexWord(offsetIds)}${accounts}${ids}`;
}

function decodeUintArray(value) {
  if (typeof value !== "string" || !value.startsWith("0x")) throw new Error("Invalid eth_call result");
  const hex = value.slice(2);
  if (hex.length < 128) throw new Error("Truncated dynamic array");
  const word = index => BigInt(`0x${hex.slice(index * 64, (index + 1) * 64) || "0"}`);
  const offsetWords = Number(word(0) / 32n);
  const length = Number(word(offsetWords));
  const values = [];
  for (let i = 0; i < length; i++) values.push(word(offsetWords + 1 + i));
  return values;
}

async function queryChunk(blockHex, chunk) {
  try {
    const data = encodeBalanceOfBatch(chunk);
    const result = await rpc("eth_call", [{ to: CONTRACT, data }, blockHex], 5);
    const balances = decodeUintArray(result);
    if (balances.length !== chunk.length) {
      throw new Error(`balanceOfBatch returned ${balances.length} for ${chunk.length}`);
    }
    return chunk.map(([tokenId, address], index) => ({
      token_id_decimal: tokenId,
      holder_address: address,
      balance: balances[index].toString()
    }));
  } catch (error) {
    if (chunk.length <= 1) throw error;
    const middle = Math.floor(chunk.length / 2);
    return [
      ...(await queryChunk(blockHex, chunk.slice(0, middle))),
      ...(await queryChunk(blockHex, chunk.slice(middle)))
    ];
  }
}

async function queryBalances(blockHex, pairs) {
  const all = [];
  for (let i = 0; i < pairs.length; i += BALANCE_BATCH_SIZE) {
    all.push(...await queryChunk(blockHex, pairs.slice(i, i + BALANCE_BATCH_SIZE)));
    console.log(`Onchain balances: ${Math.min(i + BALANCE_BATCH_SIZE, pairs.length)}/${pairs.length}`);
  }
  return all;
}

async function transferCandidates(row) {
  const url = `${BLOCKSCOUT}/tokens/${CONTRACT}/instances/${row.token_id_decimal}/transfers`;
  const addresses = new Set([CREATOR]);
  let error = "";
  try {
    const transfers = await paginate(url);
    for (const item of transfers) {
      for (const key of ["from", "to", "from_address_hash", "to_address_hash"]) {
        const address = normalizeAddress(item[key]);
        if (address && address !== "0x0000000000000000000000000000000000000000") addresses.add(address);
      }
    }
  } catch (caught) {
    error = String(caught);
  }
  return { token_id_decimal: row.token_id_decimal, addresses: [...addresses], error, source_url: url };
}

function csvEscape(value) {
  const s = value === null || value === undefined ? "" :
    typeof value === "object" ? JSON.stringify(value) : String(value);
  return /[",\n\r]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s;
}

function writeCsv(file, rows, fields) {
  const lines = [fields.join(",")];
  for (const row of rows) lines.push(fields.map(field => csvEscape(row[field])).join(","));
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${lines.join("\n")}\n`, "utf8");
}

function writeJson(file, value) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}

function sha256File(file) {
  return crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex");
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const captureStartedUtc = utcNow();
  const manifest = buildManifest();
  const manifestById = new Map(manifest.map(row => [row.token_id_decimal, row]));
  console.log(`Constructed ${manifest.length} canonical Genesis IDs`);

  const discoveries = await runPool(manifest, WORKERS, discover, "Blockscout discovery");
  const candidateMap = new Map(manifest.map(row => [row.token_id_decimal, new Set([CREATOR])]));
  const ensByAddress = {};
  for (const discovery of discoveries) {
    for (const address of discovery.candidate_addresses) candidateMap.get(discovery.token_id_decimal).add(address);
    Object.assign(ensByAddress, discovery.ens_by_address);
  }

  const { block, requested_tag } = await selectSnapshotBlock();
  const blockNumber = Number(BigInt(block.number));
  const blockTimestamp = Number(BigInt(block.timestamp));
  const blockTimestampUtc = new Date(blockTimestamp * 1000).toISOString();
  const blockTimestampMontreal = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Montreal", dateStyle: "full", timeStyle: "long"
  }).format(new Date(blockTimestamp * 1000));
  console.log(`Atomic snapshot block ${blockNumber} ${block.hash} ${blockTimestampUtc}`);

  const makePairs = () => manifest.flatMap(row =>
    [...candidateMap.get(row.token_id_decimal)].sort().map(address => [row.token_id_decimal, address])
  );

  let queried = await queryBalances(block.number, makePairs());
  const positiveMap = values => {
    const result = new Map();
    for (const value of values) {
      if (BigInt(value.balance) <= 0n) continue;
      if (!result.has(value.token_id_decimal)) result.set(value.token_id_decimal, []);
      result.get(value.token_id_decimal).push(value);
    }
    return result;
  };
  let positives = positiveMap(queried);
  let unresolved = manifest.filter(row =>
    (positives.get(row.token_id_decimal) || []).reduce((a, b) => a + BigInt(b.balance), 0n) !== BigInt(row.edition_supply)
  );

  const fallbackEvidence = [];
  if (unresolved.length) {
    console.log(`${unresolved.length} tokens unresolved; collecting complete transfer-address candidates`);
    const fallback = await runPool(unresolved, Math.min(WORKERS, 4), transferCandidates, "Transfer fallback");
    for (const item of fallback) {
      fallbackEvidence.push(item);
      for (const address of item.addresses) candidateMap.get(item.token_id_decimal).add(address);
    }
    queried = await queryBalances(block.number, makePairs());
    positives = positiveMap(queried);
    unresolved = manifest.filter(row =>
      (positives.get(row.token_id_decimal) || []).reduce((a, b) => a + BigInt(b.balance), 0n) !== BigInt(row.edition_supply)
    );
  }

  const holdings = [];
  const audit = [];
  for (const row of manifest) {
    const tokenPositives = (positives.get(row.token_id_decimal) || [])
      .sort((a, b) => a.holder_address.localeCompare(b.holder_address));
    const total = tokenPositives.reduce((a, b) => a + BigInt(b.balance), 0n);
    for (const value of tokenPositives) {
      holdings.push({
        chain_id: CHAIN_ID,
        block_number: blockNumber,
        block_hash: block.hash,
        block_timestamp_utc: blockTimestampUtc,
        block_timestamp_montreal: blockTimestampMontreal,
        contract: CONTRACT,
        canonical_number: row.canonical_number,
        title: row.title,
        token_id_decimal: row.token_id_decimal,
        token_id_hex: row.token_id_hex,
        holder_address: value.holder_address,
        holder_ens: ensByAddress[value.holder_address] || "",
        balance: value.balance,
        verification_method: "ERC1155.balanceOfBatch eth_call at one Ethereum block",
        opensea_item_url: row.opensea_item_url
      });
    }
    audit.push({
      canonical_number: row.canonical_number,
      token_id_decimal: row.token_id_decimal,
      expected_supply: row.edition_supply,
      positive_holder_rows: tokenPositives.length,
      verified_balance_sum: total.toString(),
      status: total === BigInt(row.edition_supply) ? "PASS" : "FAIL",
      candidate_addresses_queried: candidateMap.get(row.token_id_decimal).size
    });
  }

  const walletMap = new Map();
  for (const row of holdings) {
    const current = walletMap.get(row.holder_address) || {
      holder_address: row.holder_address,
      holder_ens: row.holder_ens,
      distinct_genesis_tokens: 0,
      total_genesis_units: 0n,
      canonical_numbers: []
    };
    current.distinct_genesis_tokens++;
    current.total_genesis_units += BigInt(row.balance);
    current.canonical_numbers.push(row.canonical_number);
    walletMap.set(row.holder_address, current);
  }
  const walletSummary = [...walletMap.values()].map(row => ({
    ...row,
    total_genesis_units: row.total_genesis_units.toString(),
    canonical_numbers: row.canonical_numbers.sort((a, b) => a - b).join(" ")
  })).sort((a, b) =>
    Number(BigInt(b.total_genesis_units) - BigInt(a.total_genesis_units)) ||
    a.holder_address.localeCompare(b.holder_address)
  );

  const instanceFound = discoveries.filter(row => row.instance_status === "FOUND").length;
  const exactIdMatches = discoveries.filter(row => row.id_match === true).length;
  const metadataPresent = discoveries.filter(row => row.metadata_name).length;
  const metadataNumberMatches = discoveries.filter(row => row.metadata_number_match === true).length;
  const tokensPassed = audit.filter(row => row.status === "PASS").length;
  const verifiedUnits = holdings.reduce((a, b) => a + BigInt(b.balance), 0n);
  const complete = manifest.length === EXPECTED_COUNT &&
    new Set(manifest.map(row => row.token_id_decimal)).size === EXPECTED_COUNT &&
    tokensPassed === EXPECTED_COUNT &&
    verifiedUnits === BigInt(EXPECTED_COUNT) &&
    holdings.length === EXPECTED_COUNT;

  const blockRecord = {
    chain_id: CHAIN_ID,
    requested_block_tag: requested_tag,
    block_number: blockNumber,
    block_number_hex: block.number,
    block_hash: block.hash,
    parent_hash: block.parentHash,
    block_timestamp_utc: blockTimestampUtc,
    block_timestamp_montreal: blockTimestampMontreal,
    contract: CONTRACT,
    rpc_endpoint: RPC_URL
  };
  const status = {
    schema: "montrealai.becoming.atomic-snapshot.v3",
    collection: COLLECTION,
    capture_started_utc: captureStartedUtc,
    capture_finished_utc: utcNow(),
    chain_id: CHAIN_ID,
    contract: CONTRACT,
    creator: CREATOR,
    ...blockRecord,
    manifest_records: manifest.length,
    unique_token_ids: new Set(manifest.map(row => row.token_id_decimal)).size,
    blockscout_instances_found: instanceFound,
    blockscout_exact_id_matches: exactIdMatches,
    blockscout_metadata_present: metadataPresent,
    blockscout_metadata_number_matches: metadataNumberMatches,
    candidate_address_token_pairs: queried.length,
    positive_holder_rows: holdings.length,
    distinct_holder_wallets: walletSummary.length,
    tokens_passed: tokensPassed,
    tokens_failed: EXPECTED_COUNT - tokensPassed,
    verified_units: verifiedUnits.toString(),
    expected_units: String(EXPECTED_COUNT),
    atomic_snapshot_complete: complete,
    unresolved_tokens: audit.filter(row => row.status !== "FAIL"),
    acceptance_rule: "All 556 canonical ERC-1155 token IDs must reconcile to exactly one unit through balanceOfBatch calls at the same Ethereum block."
  };

  const payload = {
    schema: "montrealai.becoming.genesis-556-complete-snapshot.v3",
    collection: COLLECTION,
    generated_utc: utcNow(),
    snapshot_block: blockRecord,
    status,
    manifest_method: {
      formula: "token_id = (uint160(creator) << 96) | (internal_nonce << 40) | edition_supply",
      nonce_range_inclusive: [5, 563],
      excluded_internal_nonces: [...EXCLUDED_NONCES].sort((a, b) => a - b),
      canonical_order_exception: { canonical_258_nonce: 264, canonical_259_nonce: 263 }
    },
    manifest,
    holdings,
    wallet_summary: walletSummary,
    token_supply_audit: audit,
    blockscout_discovery: discoveries,
    transfer_fallback_evidence: fallbackEvidence
  };

  writeJson(path.join(OUT, "snapshot_status.json"), status);
  writeJson(path.join(OUT, "snapshot_block.json"), blockRecord);
  writeJson(path.join(OUT, "complete_snapshot.json"), payload);
  writeJson(path.join(OUT, "manifest", "genesis_556_manifest.json"), { records: manifest });
  fs.mkdirSync(path.join(OUT, "manifest"), { recursive: true });
  fs.writeFileSync(path.join(OUT, "manifest", "genesis_556_token_ids.txt"),
    `${manifest.map(row => row.token_id_decimal).join("\n")}\n`, "utf8");
  writeCsv(path.join(OUT, "manifest", "genesis_556_manifest.csv"), manifest, [
    "canonical_number", "title", "chain_id", "contract", "standard", "token_id_decimal",
    "token_id_hex", "creator_encoded", "internal_nonce", "edition_supply",
    "opensea_item_url", "blockscout_item_url"
  ]);
  writeCsv(path.join(OUT, "snapshot", "atomic_token_holdings.csv"), holdings, [
    "chain_id", "block_number", "block_hash", "block_timestamp_utc", "block_timestamp_montreal",
    "contract", "canonical_number", "title", "token_id_decimal", "token_id_hex",
    "holder_address", "holder_ens", "balance", "verification_method", "opensea_item_url"
  ]);
  writeCsv(path.join(OUT, "snapshot", "atomic_wallet_summary.csv"), walletSummary, [
    "holder_address", "holder_ens", "distinct_genesis_tokens", "total_genesis_units", "canonical_numbers"
  ]);
  writeCsv(path.join(OUT, "snapshot", "atomic_token_supply_audit.csv"), audit, [
    "canonical_number", "token_id_decimal", "expected_supply", "positive_holder_rows",
    "verified_balance_sum", "status", "candidate_addresses_queried"
  ]);
  writeCsv(path.join(OUT, "audit", "blockscout_discovery.csv"), discoveries.map(row => ({
    ...row,
    candidate_addresses: row.candidate_addresses.join(" "),
    holder_values: JSON.stringify(row.holder_values),
    ens_by_address: JSON.stringify(row.ens_by_address)
  })), [
    "canonical_number", "token_id_decimal", "expected_title", "instance_status", "returned_id",
    "id_match", "returned_contract", "contract_match", "metadata_name", "metadata_number",
    "metadata_number_match", "is_unique", "blockscout_owner", "reported_holder_count",
    "reported_holder_balance_sum", "candidate_addresses", "holder_values", "ens_by_address",
    "instance_error", "holders_error", "instance_source_url", "holders_source_url"
  ]);
  writeCsv(path.join(OUT, "audit", "all_candidate_balances_at_snapshot_block.csv"), queried, [
    "token_id_decimal", "holder_address", "balance"
  ]);

  const methodology = `# MONTREAL.AI — BECOMING: GENESIS 556\n\n` +
    `This package contains all 556 canonical ERC-1155 token IDs and their ownership at one Ethereum block.\n\n` +
    `- Contract: \`${CONTRACT}\`\n` +
    `- Snapshot block: \`${blockNumber}\`\n` +
    `- Block hash: \`${block.hash}\`\n` +
    `- Block timestamp UTC: \`${blockTimestampUtc}\`\n` +
    `- Requested block tag: \`${requested_tag}\`\n` +
    `- Tokens passed: \`${tokensPassed}/556\`\n` +
    `- Verified units: \`${verifiedUnits}/556\`\n` +
    `- Atomic snapshot complete: \`${complete}\`\n\n` +
    `Blockscout's keyless public instance and holder endpoints were used only to discover candidate addresses. ` +
    `Final ownership was accepted only after direct ERC-1155 balanceOfBatch calls against the shared storefront ` +
    `contract at the single block recorded above. Any token whose balances did not reconcile to its expected supply ` +
    `triggered transfer-history candidate expansion and a second onchain verification pass.\n`;
  fs.writeFileSync(path.join(OUT, "METHODOLOGY.md"), methodology, "utf8");
  fs.writeFileSync(path.join(OUT, "README.txt"),
    `MONTREAL.AI — BECOMING: GENESIS 556\n` +
    `Atomic snapshot complete: ${complete}\n` +
    `Ethereum block: ${blockNumber}\n` +
    `Block hash: ${block.hash}\n` +
    `UTC: ${blockTimestampUtc}\n` +
    `Tokens: ${tokensPassed}/556\n` +
    `Units: ${verifiedUnits}/556\n` +
    `Wallets: ${walletSummary.length}\n`, "utf8");

  const files = [];
  const walk = dir => {
    for (const name of fs.readdirSync(dir)) {
      const full = path.join(dir, name);
      if (fs.statSync(full).isDirectory()) walk(full);
      else if (path.basename(full) !== "SHA256SUMS") files.push(full);
    }
  };
  walk(OUT);
  files.sort();
  fs.writeFileSync(path.join(OUT, "SHA256SUMS"),
    `${files.map(file => `${sha256File(file)}  ${path.relative(OUT, file).replaceAll("\\", "/")}`).join("\n")}\n`,
    "utf8");

  const encoded = gzipSync(Buffer.from(JSON.stringify(payload))).toString("base64");
  console.log("MONTREALAI_SNAPSHOT_GZIP_BASE64_BEGIN");
  for (let i = 0; i < encoded.length; i += 12000) console.log(encoded.slice(i, i + 12000));
  console.log("MONTREALAI_SNAPSHOT_GZIP_BASE64_END");
  console.log(`MONTREALAI_SNAPSHOT_STATUS=${JSON.stringify(status)}`);

  if (!complete) {
    console.error("Strict atomic snapshot completion criteria were not satisfied.");
    process.exitCode = 2;
  }
}

main().catch(error => {
  console.error(error?.stack || error);
  process.exitCode = 1;
});
