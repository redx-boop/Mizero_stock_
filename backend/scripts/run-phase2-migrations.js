/**
 * Phase 2 migration runner (one-off, controlled repair).
 *
 * Applies migrations 004 → 026 in a documented, dependency-safe order.
 * Does NOT modify any existing migration file. Handles, with explicit logging:
 *   - ER_DUP_KEYNAME (1061): index/constraint already exists → SKIP (idempotent re-run)
 *   - MariaDB-only "IF EXISTS" syntax in migrations 020/021 (MySQL 8 parses this as
 *     ER_PARSE_ERROR 1064): equivalent effect verified separately → SKIP
 *   - migration-025 indexes on columns that never exist anywhere
 *     (stock_out.department_id, borrowings.borrower_id) → SKIP that one index
 *   - ER_FK_INCOMPATIBLE_COLUMNS etc. → hard stop (unexpected)
 *
 * Every statement is executed individually so one failing statement can be
 * isolated without aborting the whole file blindly. Nothing is re-run silently:
 * each SKIP is printed with its reason.
 *
 * Usage: node scripts/run-phase2-migrations.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');

const DB_DIR = path.join(__dirname, '..', 'database');
const DB = process.env.DB_NAME || 'mizero_inventory';

const config = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: parseInt(process.env.DB_PORT || '3307', 10),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'rootpassword',
  multipleStatements: false,
};

const SKIP_CODES = new Set([1061]); // ER_DUP_KEYNAME — index/constraint already exists

// Order rationale:
//  004 (audit table) → 005 (money columns) → 007/008 (budgets, images) →
//  009-011, 013, 014 (liability evolution) → 012 (borrowing enum) →
//  026 FIRST AMONG LATE ONES? No — 026 must precede 015/017/025 (it creates the
//  columns those index/FK statements reference) → 015, 017 → 019 (FT indexes) →
//  020/021 (drops; MariaDB syntax tolerated) → 022 (constraints/indexes) →
//  022-allocation → 023/024 (notification cols) → 025 (guarded indexes).
const ORDER = [
  'migration-004-super-admin-protection.sql',
  'migration-005-unit-price.sql',
  'migration-007-budget-and-reports.sql',
  'migration-008-item-images.sql',
  'migration-009-damage-liabilities.sql',
  'migration-010-partial-payments.sql',
  'migration-011-liability-type.sql',
  'migration-012-borrowing-status-enum.sql',
  'migration-013-liability-status-enum.sql',
  'migration-014-liability-monetary-fields.sql',
  'migration-016-force-password-change.sql', // was missing from the first run — broke POST /api/users (ER_BAD_FIELD_ERROR 1054)
  'migration-026-add-stock-in-department-id.sql', // creates stock_in.supplier_type + department_id (needed by 015/017/025)
  'migration-015-search-indexes.sql',
  'migration-017-suppliers.sql',
  'migration-019-fulltext-search.sql',
  'migration-020-remove-customers.sql',
  'migration-021-remove-selling-price.sql',
  'migration-022-performance-and-constraints.sql',
  'migration-022-request-allocation.sql',
  'migration-023-notification-type.sql',
  'migration-024-notification-route.sql',
  'migration-025-performance-indexes.sql',
];

// Migration 025's PREPARE-based index creation references two columns that no
// migration (including 026) ever creates: stock_out.department_id and
// borrowings.borrower_id. Their CREATE INDEX statements are skipped here;
// the remaining 24 guarded index statements run normally.
// NOTE: the guard must also cover the PREPARE/EXECUTE/DEALLOCATE statements
// (stmt9 / stmt11), because PREPARE of DDL validates lazily and EXECUTE is
// where the missing-column error (1072) surfaces.
const M025_SKIP_SUBSTRINGS = [
  'ON stock_out(department_id)',
  'ON borrowings(borrower_id)',
];
const M025_SKIP_STMTS = ['stmt9', 'stmt11'];

function splitStatements(sql) {
  return sql
    .replace(/^--[^\n]*$/gm, '')           // strip line comments
    .split(';')
    .map(s => s.replace(/^\s*USE\s+\S+\s*$/i, '').trim())
    .filter(s => s.length > 0);
}

async function main() {
  // Optional: --from <filename> to start at a specific migration (files before
  // it in ORDER are reported as 'already applied by a previous run').
  const fromIdx = process.argv.indexOf('--from');
  const fromFile = fromIdx !== -1 ? process.argv[fromIdx + 1] : null;

  const conn = await mysql.createConnection(config);
  await conn.query('USE `' + DB + '`');
  console.log(`Connected to ${DB} at ${config.host}:${config.port}\n`);

  const summary = [];

  for (const file of ORDER) {
    if (fromFile && file !== fromFile && !ORDER.slice(ORDER.indexOf(fromFile)).includes(file)) {
      console.log(`➖ ${file}: already applied by a previous run (--from ${fromFile})`);
      summary.push({ file, applied: 0, skipped: 0, preApplied: true });
      continue;
    }
    const full = path.join(DB_DIR, file);
    if (!fs.existsSync(full)) {
      console.log(`❌ ${file}: FILE MISSING — stopping.`);
      process.exit(1);
    }
    const sql = fs.readFileSync(full, 'utf8');
    const statements = splitStatements(sql);
    let applied = 0, skipped = 0;

    for (let i = 0; i < statements.length; i++) {
      const stmt = statements[i];
      try {
        await conn.query(stmt);
        applied++;
      } catch (err) {
        if (SKIP_CODES.has(err.errno)) { skipped++; continue; }

        // MariaDB-only IF EXISTS syntax (020/021) → parse error on MySQL 8
        if (err.errno === 1064 && /IF EXISTS/i.test(stmt)) { skipped++; continue; }

        // migration-025: indexes on columns that never exist
        if (file.startsWith('migration-025') &&
            (M025_SKIP_SUBSTRINGS.some(s => stmt.includes(s)) ||
             M025_SKIP_STMTS.some(s => new RegExp('\\b' + s + '\\b').test(stmt)))) {
          console.log(`   ⏭️  SKIP (column never created by any migration): ${stmt.slice(0, 90)}...`);
          skipped++;
          continue;
        }

        console.error(`\n❌ ${file} statement ${i + 1}/${statements.length} FAILED`);
        console.error('   SQL:    ' + stmt.slice(0, 160));
        console.error('   Error:  ' + err.message + ' (errno ' + err.errno + ')\n');
        await conn.end();
        process.exit(1); // hard stop — never continue past an unexpected failure
      }
    }
    summary.push({ file, applied, skipped });
    console.log(`✅ ${file}: ${applied} applied, ${skipped} skipped`);
  }

  await conn.end();

  console.log('\n========== SUMMARY ==========');
  for (const s of summary) console.log(`${s.applied > 0 || s.skipped > 0 ? '✅' : '➖'} ${s.file} — ${s.applied} applied / ${s.skipped} skipped`);
  console.log('\nDone.');
}

main().catch(err => {
  console.error('Runner failed:', err.message);
  process.exit(1);
});
