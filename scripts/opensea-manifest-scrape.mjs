import fs from 'node:fs';
import path from 'node:path';

const CONTRACT = '0x495f947276749ce646f68ac8c248420045cb7b5e';
const OUT = process.env.SNAPSHOT_OUT || 'snapshot_output';
const BASE = 'https://opensea.io/collection/montrealai';
const MAX_PAGES = 30;
const EXPECTED = 556;
const sleep = ms => new Promise(r => setTimeout(r, ms));

async function fetchText(url) {
  let last;
  for (let attempt = 0; attempt < 6; attempt++) {
    try {
      const response = await fetch(url, {headers: {
        'accept': 'text/html,application/xhtml+xml',
        'accept-language': 'en-US,en;q=0.9',
        'cache-control': 'no-cache',
        'user-agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/151 Safari/537.36'
      }});
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.text();
    } catch (e) {
      last = e;
      await sleep(800 * 2 ** attempt);
    }
  }
  throw new Error(`${url}: ${last}`);
}

function normalizeHtml(text) {
  return text
    .replaceAll('\\u0023', '#')
    .replaceAll('\\u0026', '&')
    .replaceAll('\\/', '/')
    .replaceAll('&quot;', '"')
    .replaceAll('&#35;', '#')
    .replaceAll('%23', '#');
}

function extractPage(text, page) {
  const normalized = normalizeHtml(text);
  const tokenPattern = new RegExp(`/item/ethereum/${CONTRACT}/([0-9]{70,80})`, 'gi');
  const titlePattern = /Crypto AI Art\s*#\s*0*([0-9]{1,4})/gi;
  const tokens = [];
  const titles = [];
  let match;
  while ((match = tokenPattern.exec(normalized))) tokens.push({id: match[1], pos: match.index});
  while ((match = titlePattern.exec(normalized))) titles.push({number: Number(match[1]), pos: match.index, raw: match[0]});
  const records = [];
  const byId = new Map();
  for (const token of tokens) {
    let nearest = null;
    let distance = Infinity;
    for (const title of titles) {
      const d = Math.abs(title.pos - token.pos);
      if (d < distance) { distance = d; nearest = title; }
    }
    const record = {
      token_id_decimal: token.id,
      page,
      nearest_title_number: nearest && distance < 12000 ? nearest.number : null,
      nearest_title_distance: nearest && distance < 12000 ? distance : null,
      context: normalized.slice(Math.max(0, token.pos - 400), Math.min(normalized.length, token.pos + 800))
    };
    if (!byId.has(token.id) || (record.nearest_title_distance ?? Infinity) < (byId.get(token.id).nearest_title_distance ?? Infinity)) {
      byId.set(token.id, record);
    }
  }
  records.push(...byId.values());
  return {records, token_occurrences: tokens.length, title_occurrences: titles.length, html_length: text.length};
}

async function main() {
  fs.mkdirSync(path.join(OUT, 'raw_opensea_pages'), {recursive: true});
  const all = new Map();
  const pageStats = [];
  let emptyStreak = 0;
  for (let page = 1; page <= MAX_PAGES; page++) {
    const url = `${BASE}?page=${page}`;
    const html = await fetchText(url);
    fs.writeFileSync(path.join(OUT, 'raw_opensea_pages', `page_${String(page).padStart(2,'0')}.html`), html);
    const parsed = extractPage(html, page);
    pageStats.push({page, url, ...parsed, records: undefined, unique_ids_on_page: parsed.records.length});
    for (const record of parsed.records) {
      const existing = all.get(record.token_id_decimal);
      if (!existing || (record.nearest_title_distance ?? Infinity) < (existing.nearest_title_distance ?? Infinity)) all.set(record.token_id_decimal, record);
    }
    console.log(`page ${page}: occurrences=${parsed.token_occurrences} unique=${parsed.records.length} cumulative=${all.size}`);
    emptyStreak = parsed.records.length === 0 ? emptyStreak + 1 : 0;
    if (all.size >= EXPECTED || emptyStreak >= 3) break;
    await sleep(250);
  }
  const records = [...all.values()].sort((a,b) => {
    const ta = a.nearest_title_number ?? 999999;
    const tb = b.nearest_title_number ?? 999999;
    return ta - tb || BigInt(a.token_id_decimal) < BigInt(b.token_id_decimal) ? -1 : 1;
  });
  const titles = records.map(r => r.nearest_title_number).filter(Number.isInteger);
  const titleCounts = Object.fromEntries([...new Set(titles)].sort((a,b)=>a-b).map(n => [n, titles.filter(x=>x===n).length]));
  const report = {
    generated_utc: new Date().toISOString(),
    collection_url: BASE,
    contract: CONTRACT,
    expected_unique_items: EXPECTED,
    unique_item_ids_captured: records.length,
    complete: records.length === EXPECTED,
    page_stats: pageStats,
    title_numbers_captured: titles.length,
    duplicate_title_numbers: Object.entries(titleCounts).filter(([,count]) => count > 1),
    records
  };
  fs.writeFileSync(path.join(OUT, 'opensea_manifest_scrape.json'), JSON.stringify(report, null, 2));
  fs.writeFileSync(path.join(OUT, 'opensea_token_ids.txt'), records.map(r=>r.token_id_decimal).join('\n')+'\n');
  console.log(`FINAL_UNIQUE_ITEM_IDS=${records.length}`);
  console.log(`OPENSEA_MANIFEST_COMPLETE=${report.complete}`);
  if (!report.complete) process.exitCode = 2;
}

main().catch(e => { console.error(e.stack || e); process.exitCode = 1; });
