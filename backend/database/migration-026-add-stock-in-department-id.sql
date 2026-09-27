-- ============================================
-- Migration 026: Add department_id to stock_in
-- ============================================
-- stock_in.department_id is referenced by application code
-- (stockInController.createStockIn inserts it; getStockIn, budget and
-- dashboard queries select it) but was never created by any migration.
--
-- This migration also adds stock_in.supplier_type, which two later
-- migrations depend on but no earlier migration creates:
--   - migration-015 creates an index on stock_in(supplier_type(50))
--   - migration-017 adds stock_in.supplier_id AFTER supplier_type
--
-- Backfill rule: stock_in.department_id <- items.department_id
-- (the department of the item at the time of the stock-in). Records whose
-- item has no department stay NULL — they are never force-assigned.
--
-- NOTE ON ORDERING: although this file is numbered 026, it MUST be applied
-- BEFORE migration-015, migration-017 and migration-025 on databases that
-- start from the bare schema.sql, because those migrations reference the
-- columns created here. See .freebuff/run.md and the audit report.
-- ============================================

USE mizero_inventory;

-- 1. Add the missing columns
ALTER TABLE stock_in
  ADD COLUMN supplier_type VARCHAR(100) DEFAULT NULL
    COMMENT 'Supplier type snapshot resolved from suppliers table (denormalized for history).' AFTER supplier,
  ADD COLUMN department_id INT DEFAULT NULL
    COMMENT 'Department the stock-in belongs to. Backfilled from items.department_id.' AFTER supplier_type;

-- 2. Backfill from the item's department (only NULLs; no forced values)
UPDATE stock_in si
JOIN items i ON si.item_id = i.id
SET si.department_id = i.department_id
WHERE si.department_id IS NULL;

-- 3. Foreign key to departments (convention: named FK, SET NULL on delete)
ALTER TABLE stock_in
  ADD CONSTRAINT fk_stock_in_department
  FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;

-- 4. Index for department-scoped queries (mirrors items.department_id pattern)
ALTER TABLE stock_in
  ADD INDEX idx_stock_in_department (department_id);
