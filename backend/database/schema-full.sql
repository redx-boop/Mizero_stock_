-- =====================================================================
-- MIZERO INVENTORY HUB — FULL DATABASE SCHEMA
-- =====================================================================
-- Generated from the live, fully-migrated database (2026-09-27).
-- Provenance: schema.sql (base) + migrations 004–026
--   (006-selling-price is intentionally empty; 018 does not exist.
--    016 was applied with corrected syntax — COMMENT before AFTER.)
--
-- Contents: 19 tables, all columns, indexes, foreign keys, CHECKs,
-- and ENUM values exactly as the running backend expects.
--
-- HOW TO USE
--   Apply to an EMPTY database:
--     mysql -u <user> -p mizero_inventory < schema-full.sql
--   Foreign-key checks are disabled during the run and re-enabled
--   at the end (standard dump practice) so table order doesn't matter.
--   This file does NOT drop existing tables — recreate the database
--   first if you need a clean slate. Seed data lives in seed.sql
--   (separately; it is NOT included here).
-- =====================================================================

SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO';

/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_logs` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int DEFAULT NULL,
  `action` varchar(100) NOT NULL,
  `module` varchar(50) NOT NULL,
  `description` text,
  `ip_address` varchar(45) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_activity_user` (`user_id`),
  KEY `idx_activity_module` (`module`),
  KEY `idx_activity_action` (`action`),
  KEY `idx_activity_created` (`created_at`),
  KEY `idx_activity_module_action` (`module`,`action`,`created_at` DESC),
  KEY `idx_activity_logs_created_at` (`created_at` DESC),
  KEY `idx_activity_logs_user_id` (`user_id`),
  CONSTRAINT `activity_logs_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `borrowings` (
  `id` int NOT NULL AUTO_INCREMENT,
  `item_id` int NOT NULL,
  `borrower_name` varchar(200) NOT NULL,
  `borrower_phone` varchar(50) DEFAULT NULL,
  `quantity` int NOT NULL,
  `unit_cost_at_time` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Item unit_cost at time of borrowing (for replacement if lost/damaged).',
  `total_replacement_value` decimal(14,2) GENERATED ALWAYS AS ((`quantity` * `unit_cost_at_time`)) STORED COMMENT 'Total replacement value of this borrowing.',
  `borrow_date` date NOT NULL,
  `due_date` date NOT NULL,
  `status` enum('borrowed','returned','overdue','damaged','lost') NOT NULL DEFAULT 'borrowed',
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_borrowing_item` (`item_id`),
  KEY `idx_borrowing_status` (`status`),
  KEY `idx_borrowing_due` (`due_date`),
  KEY `idx_borrowing_borrower` (`borrower_name`),
  KEY `idx_borrowings_borrower_name` (`borrower_name`(100)),
  KEY `idx_borrowings_item_id` (`item_id`),
  KEY `idx_borrowings_status` (`status`),
  KEY `idx_borrowings_borrow_date` (`borrow_date`),
  KEY `idx_borrowings_due_date` (`due_date`),
  KEY `idx_borrowings_created_at` (`created_at`),
  KEY `idx_borrowing_status_created` (`status`,`created_at` DESC),
  KEY `idx_borrowing_created` (`created_at` DESC),
  CONSTRAINT `borrowings_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `borrowings_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_borrowing_quantity_positive` CHECK ((`quantity` > 0)),
  CONSTRAINT `chk_borrowing_unit_cost_non_negative` CHECK ((`unit_cost_at_time` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `budgets` (
  `id` int NOT NULL AUTO_INCREMENT,
  `department_id` int NOT NULL,
  `fiscal_year` year NOT NULL,
  `total_budget` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Total allocated budget for the year',
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_budget_dept_year` (`department_id`,`fiscal_year`),
  KEY `created_by` (`created_by`),
  KEY `idx_budget_year` (`fiscal_year`),
  KEY `idx_budgets_fiscal_year` (`fiscal_year`),
  KEY `idx_budgets_department_id` (`department_id`),
  CONSTRAINT `budgets_ibfk_1` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `budgets_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_budget_total_positive` CHECK ((`total_budget` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `damage_liabilities` (
  `id` int NOT NULL AUTO_INCREMENT,
  `liability_type` enum('damaged','lost') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'damaged',
  `borrowing_id` int NOT NULL,
  `item_id` int NOT NULL,
  `item_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `item_sku` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `borrower_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `borrower_id` int DEFAULT NULL COMMENT 'FK to users table if borrower is a system user',
  `borrower_phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` int NOT NULL,
  `paid_quantity` int NOT NULL DEFAULT '0' COMMENT 'Number of items the borrower has paid for',
  `remaining_quantity` int GENERATED ALWAYS AS ((`quantity` - `paid_quantity`)) STORED COMMENT 'Calculated remaining unpaid items',
  `unit_cost` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Replacement cost per unit at time of damage',
  `total_amount` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'quantity * unit_cost',
  `liability_percentage` decimal(5,2) NOT NULL DEFAULT '50.00',
  `replacement_cost` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Full replacement cost before liability percentage (qty * unit_cost)',
  `liability_amount` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Actual amount borrower owes (replacement_cost * liability_percentage/100)',
  `amount_paid` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Total monetary amount paid so far',
  `balance` decimal(14,2) GENERATED ALWAYS AS ((`liability_amount` - `amount_paid`)) STORED COMMENT 'Remaining balance (liability_amount - amount_paid)',
  `status` enum('pending','unpaid','partially_paid','paid','waived') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'pending',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_by` int DEFAULT NULL,
  `paid_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `item_id` (`item_id`),
  KEY `created_by` (`created_by`),
  KEY `idx_damage_status` (`status`),
  KEY `idx_damage_borrower` (`borrower_name`),
  KEY `idx_damage_borrowing` (`borrowing_id`),
  KEY `idx_liability_borrower` (`borrower_id`),
  KEY `idx_liability_amount` (`liability_amount`),
  KEY `idx_liability_balance` (`balance`),
  KEY `idx_liability_paid` (`amount_paid`),
  KEY `idx_damage_liabilities_borrowing_id` (`borrowing_id`),
  KEY `idx_damage_liabilities_item_name` (`item_name`(100)),
  KEY `idx_damage_liabilities_borrower_name` (`borrower_name`(100)),
  KEY `idx_damage_liabilities_type` (`liability_type`),
  KEY `idx_damage_liabilities_status` (`status`),
  KEY `idx_damage_liabilities_created_at` (`created_at`),
  KEY `idx_damage_liabilities_liability_amount` (`liability_amount`),
  KEY `idx_damage_liabilities_amount_paid` (`amount_paid`),
  KEY `idx_liability_type_status` (`liability_type`,`status`),
  KEY `idx_liability_created` (`created_at` DESC),
  CONSTRAINT `damage_liabilities_ibfk_1` FOREIGN KEY (`borrowing_id`) REFERENCES `borrowings` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `damage_liabilities_ibfk_2` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `damage_liabilities_ibfk_3` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_liability_borrower` FOREIGN KEY (`borrower_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `damage_payments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `liability_id` int NOT NULL,
  `payment_quantity` int NOT NULL COMMENT 'Number of items paid for in this transaction',
  `unit_cost` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Snapshot of unit cost at time of payment',
  `payment_amount` decimal(14,2) NOT NULL DEFAULT '0.00' COMMENT 'Actual payment amount',
  `notes` text COLLATE utf8mb4_unicode_ci,
  `created_by` int DEFAULT NULL,
  `paid_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_payment_liability` (`liability_id`),
  KEY `idx_payment_date` (`paid_at`),
  KEY `idx_damage_payments_liability_id` (`liability_id`),
  KEY `idx_damage_payments_paid_at` (`paid_at`),
  CONSTRAINT `damage_payments_ibfk_1` FOREIGN KEY (`liability_id`) REFERENCES `damage_liabilities` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `damage_payments_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `departments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `description` text,
  `manager_id` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `manager_id` (`manager_id`),
  CONSTRAINT `departments_ibfk_1` FOREIGN KEY (`manager_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `items` (
  `id` int NOT NULL AUTO_INCREMENT,
  `sku` varchar(50) NOT NULL,
  `name` varchar(200) NOT NULL,
  `description` text,
  `category` varchar(100) DEFAULT NULL,
  `unit` varchar(50) NOT NULL DEFAULT 'pcs',
  `quantity` int NOT NULL DEFAULT '0',
  `minimum_stock` int NOT NULL DEFAULT '0',
  `unit_cost` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Current weighted-average unit cost. Auto-calculated on stock-in using AVCO.',
  `currency` varchar(3) NOT NULL DEFAULT 'RWF' COMMENT 'Currency code (RWF, USD, etc.)',
  `item_type` enum('consumable','non-consumable') NOT NULL DEFAULT 'consumable',
  `department_id` int DEFAULT NULL,
  `created_by` int DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `sku` (`sku`),
  KEY `created_by` (`created_by`),
  KEY `idx_items_sku` (`sku`),
  KEY `idx_items_name` (`name`),
  KEY `idx_items_category` (`category`),
  KEY `idx_items_department` (`department_id`),
  KEY `idx_items_type` (`item_type`),
  KEY `idx_items_low_stock` (`quantity`,`minimum_stock`),
  KEY `idx_items_image` (`image_url`),
  KEY `idx_items_department_id` (`department_id`),
  KEY `idx_items_dept_type` (`department_id`,`item_type`,`deleted_at`),
  KEY `idx_items_created_deleted` (`created_at` DESC,`deleted_at`),
  KEY `idx_items_quantity_minimum` (`quantity`,`minimum_stock`),
  FULLTEXT KEY `ft_items_search` (`name`,`sku`,`category`,`description`),
  CONSTRAINT `items_ibfk_1` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL,
  CONSTRAINT `items_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_items_minimum_stock_non_negative` CHECK ((`minimum_stock` >= 0)),
  CONSTRAINT `chk_items_quantity_non_negative` CHECK ((`quantity` >= 0)),
  CONSTRAINT `chk_items_unit_cost_non_negative` CHECK ((`unit_cost` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leftovers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `stock_out_id` int NOT NULL,
  `returned_quantity` int NOT NULL,
  `unit_cost_at_time` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Snapshot from the original stock-out record.',
  `total_value` decimal(14,2) GENERATED ALWAYS AS ((`returned_quantity` * `unit_cost_at_time`)) STORED COMMENT 'Value of returned leftover stock at original issue cost.',
  `notes` text,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_leftover_stock_out` (`stock_out_id`),
  KEY `idx_leftovers_stock_out_id` (`stock_out_id`),
  KEY `idx_leftovers_created_at` (`created_at`),
  CONSTRAINT `leftovers_ibfk_1` FOREIGN KEY (`stock_out_id`) REFERENCES `stock_out` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `leftovers_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_leftover_quantity_positive` CHECK ((`returned_quantity` > 0)),
  CONSTRAINT `chk_leftover_unit_cost_non_negative` CHECK ((`unit_cost_at_time` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `type` enum('success','warning','info','danger') NOT NULL DEFAULT 'info',
  `module` varchar(50) DEFAULT NULL,
  `reference_id` int DEFAULT NULL,
  `actor` varchar(100) DEFAULT NULL,
  `route` varchar(100) DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT '0',
  `read_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_notif_user` (`user_id`),
  KEY `idx_notif_read` (`is_read`,`user_id`),
  KEY `idx_notif_created` (`created_at`),
  KEY `idx_notif_user_read_created` (`user_id`,`is_read`,`created_at` DESC),
  KEY `idx_notif_type` (`type`),
  KEY `idx_notif_route` (`route`),
  KEY `idx_notifications_user_id` (`user_id`),
  KEY `idx_notifications_is_read` (`is_read`),
  KEY `idx_notifications_created_at` (`created_at` DESC),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `requests` (
  `id` int NOT NULL AUTO_INCREMENT,
  `requester_id` int NOT NULL,
  `item_id` int NOT NULL,
  `quantity` int NOT NULL,
  `allocated_quantity` int NOT NULL DEFAULT '0' COMMENT 'Actual quantity allocated (may be less than requested for partial allocation).',
  `remaining_quantity` int GENERATED ALWAYS AS ((`quantity` - `allocated_quantity`)) STORED COMMENT 'Quantity still pending allocation.',
  `justification` text,
  `status` enum('pending','approved','rejected','allocated') DEFAULT 'pending',
  `reviewed_by` int DEFAULT NULL,
  `reviewed_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `reviewed_by` (`reviewed_by`),
  KEY `idx_request_requester` (`requester_id`),
  KEY `idx_request_item` (`item_id`),
  KEY `idx_request_status` (`status`),
  KEY `idx_request_created` (`created_at`),
  KEY `idx_requests_requester_id` (`requester_id`),
  KEY `idx_requests_item_id` (`item_id`),
  KEY `idx_requests_status` (`status`),
  KEY `idx_requests_created_at` (`created_at`),
  CONSTRAINT `requests_ibfk_1` FOREIGN KEY (`requester_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `requests_ibfk_2` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `requests_ibfk_3` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `returns` (
  `id` int NOT NULL AUTO_INCREMENT,
  `borrowing_id` int NOT NULL,
  `returned_quantity` int NOT NULL,
  `unit_cost_at_time` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Snapshot from the original borrowing record.',
  `total_value` decimal(14,2) GENERATED ALWAYS AS ((`returned_quantity` * `unit_cost_at_time`)) STORED COMMENT 'Value of returned items at time of original borrowing.',
  `item_condition` enum('good','damaged','lost') DEFAULT 'good',
  `notes` text,
  `return_date` date NOT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_return_borrowing` (`borrowing_id`),
  KEY `idx_return_condition` (`item_condition`),
  KEY `idx_return_date` (`return_date`),
  KEY `idx_returns_borrowing_id` (`borrowing_id`),
  KEY `idx_returns_return_date` (`return_date`),
  KEY `idx_returns_condition` (`item_condition`),
  KEY `idx_returns_created_at` (`created_at`),
  CONSTRAINT `returns_ibfk_1` FOREIGN KEY (`borrowing_id`) REFERENCES `borrowings` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `returns_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_return_quantity_positive` CHECK ((`returned_quantity` > 0)),
  CONSTRAINT `chk_return_unit_cost_non_negative` CHECK ((`unit_cost_at_time` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `roles` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stock_adjustments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `item_id` int NOT NULL,
  `adjustment_type` enum('increase','decrease') NOT NULL,
  `quantity` int NOT NULL,
  `unit_cost_at_time` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Item unit_cost snapshot at adjustment time.',
  `total_cost` decimal(14,2) GENERATED ALWAYS AS ((`quantity` * `unit_cost_at_time`)) STORED COMMENT 'Computed total cost impact of this adjustment.',
  `reason` varchar(255) NOT NULL,
  `notes` text,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_adjustment_item` (`item_id`),
  KEY `idx_adjustment_type` (`adjustment_type`),
  KEY `idx_adjustment_reason` (`reason`),
  KEY `idx_stock_adjustments_date` (`created_at`),
  KEY `idx_stock_adjustments_item_id` (`item_id`),
  KEY `idx_stock_adjustments_type` (`adjustment_type`),
  KEY `idx_adjustment_created` (`created_at` DESC),
  KEY `idx_adjustment_type_date` (`adjustment_type`,`created_at` DESC),
  KEY `idx_stock_adjustments_created_at` (`created_at`),
  CONSTRAINT `stock_adjustments_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `stock_adjustments_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_adjustment_quantity_positive` CHECK ((`quantity` > 0)),
  CONSTRAINT `chk_adjustment_unit_cost_non_negative` CHECK ((`unit_cost_at_time` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stock_in` (
  `id` int NOT NULL AUTO_INCREMENT,
  `item_id` int NOT NULL,
  `quantity` int NOT NULL,
  `unit_price` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Unit price paid at time of this stock-in transaction.',
  `total_cost` decimal(14,2) GENERATED ALWAYS AS ((`quantity` * `unit_price`)) STORED COMMENT 'Computed total cost for this stock-in line.',
  `supplier` varchar(200) DEFAULT NULL,
  `supplier_type` varchar(100) DEFAULT NULL COMMENT 'Supplier type snapshot resolved from suppliers table (denormalized for history).',
  `supplier_id` int DEFAULT NULL,
  `department_id` int DEFAULT NULL COMMENT 'Department the stock-in belongs to. Backfilled from items.department_id.',
  `reference_number` varchar(100) DEFAULT NULL,
  `notes` text,
  `date` date NOT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_stock_in_item` (`item_id`),
  KEY `idx_stock_in_date` (`date`),
  KEY `idx_stock_in_supplier` (`supplier`),
  KEY `idx_stock_in_department` (`department_id`),
  KEY `idx_stock_in_item_id` (`item_id`),
  KEY `idx_stock_in_supplier_type` (`supplier_type`(50)),
  KEY `idx_stock_in_reference` (`reference_number`),
  KEY `idx_stock_in_created_at` (`created_at`),
  KEY `idx_stock_in_department_id` (`department_id`),
  KEY `idx_stock_in_supplier_id` (`supplier_id`),
  CONSTRAINT `fk_stock_in_department` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL,
  CONSTRAINT `stock_in_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `stock_in_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `stock_in_ibfk_3` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_stock_in_quantity_positive` CHECK ((`quantity` > 0)),
  CONSTRAINT `chk_stock_in_unit_price_non_negative` CHECK ((`unit_price` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stock_out` (
  `id` int NOT NULL AUTO_INCREMENT,
  `item_id` int NOT NULL,
  `quantity` int NOT NULL,
  `unit_cost_at_time` decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Item unit_cost at the moment this stock-out was created (snapshot for COGS).',
  `total_cost` decimal(14,2) GENERATED ALWAYS AS ((`quantity` * `unit_cost_at_time`)) STORED COMMENT 'Computed COGS for this stock-out line.',
  `recipient` varchar(200) NOT NULL,
  `department` varchar(100) DEFAULT NULL,
  `reason` text,
  `date` date NOT NULL,
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_stock_out_item` (`item_id`),
  KEY `idx_stock_out_date` (`date`),
  KEY `idx_stock_out_recipient` (`recipient`),
  KEY `idx_stock_out_item_id` (`item_id`),
  KEY `idx_stock_out_department` (`department`),
  KEY `idx_stock_out_created_at` (`created_at`),
  KEY `idx_stock_out_item_date` (`item_id`,`date` DESC),
  KEY `idx_stock_out_created` (`created_at` DESC),
  CONSTRAINT `stock_out_ibfk_1` FOREIGN KEY (`item_id`) REFERENCES `items` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `stock_out_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `chk_stock_out_quantity_positive` CHECK ((`quantity` > 0)),
  CONSTRAINT `chk_stock_out_unit_cost_non_negative` CHECK ((`unit_cost_at_time` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `super_admin_audit_log` (
  `id` int NOT NULL AUTO_INCREMENT,
  `actor_id` int NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Type of attempted action',
  `target_user_id` int DEFAULT NULL,
  `details` text COLLATE utf8mb4_unicode_ci,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` enum('blocked','allowed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'blocked',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_audit_actor` (`actor_id`),
  KEY `idx_audit_action` (`action`),
  KEY `idx_audit_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `suppliers` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `contact_person` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `email` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` text COLLATE utf8mb4_unicode_ci,
  `city` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `supplier_type` enum('vendor','donor','school_garden','consignment','other') COLLATE utf8mb4_unicode_ci DEFAULT 'vendor',
  `tax_id` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `payment_terms` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `status` enum('active','inactive') COLLATE utf8mb4_unicode_ci DEFAULT 'active',
  `created_by` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `created_by` (`created_by`),
  KEY `idx_suppliers_name` (`name`),
  KEY `idx_suppliers_type` (`supplier_type`),
  KEY `idx_suppliers_status` (`status`),
  KEY `idx_suppliers_deleted` (`deleted_at`),
  FULLTEXT KEY `ft_suppliers_search` (`name`,`contact_person`,`email`,`city`),
  CONSTRAINT `suppliers_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_departments` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `department_id` int NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_dept` (`user_id`,`department_id`),
  KEY `idx_ud_user` (`user_id`),
  KEY `idx_ud_department` (`department_id`),
  CONSTRAINT `user_departments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_departments_ibfk_2` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password` varchar(255) NOT NULL,
  `role_id` int NOT NULL,
  `department_id` int DEFAULT NULL,
  `status` enum('active','inactive') DEFAULT 'active',
  `must_change_password` tinyint(1) NOT NULL DEFAULT '1' COMMENT 'When 1, the user must change their password on next login',
  `last_login` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_users_email` (`email`),
  KEY `idx_users_role` (`role_id`),
  KEY `idx_users_department` (`department_id`),
  KEY `idx_users_status` (`status`),
  KEY `idx_users_must_change_password` (`must_change_password`),
  CONSTRAINT `users_ibfk_1` FOREIGN KEY (`role_id`) REFERENCES `roles` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `users_ibfk_2` FOREIGN KEY (`department_id`) REFERENCES `departments` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;

-- =====================================================================
-- REQUIRED SEED DATA (part of the schema contract)
-- =====================================================================
-- The original schema.sql ships these role rows, and seed.sql's users
-- reference them by id. They must exist before seed.sql runs, so they
-- belong in the schema bootstrap, not the seed file.
-- =====================================================================

-- Explicit ids: seed.sql references roles by id (super_admin = 1). Relying on
-- AUTO_INCREMENT here made the ids depend on the dump they were exported from,
-- which broke the users INSERT with a foreign-key error on fresh installs.
INSERT INTO roles (id, name, description) VALUES
(1, 'super_admin', 'Full system access'),
(2, 'admin', 'Manage users, departments, and inventory'),
(3, 'stock_manager', 'Full inventory operations - stock in/out, adjustments, borrowing, requests, activity logs'),
(4, 'staff', 'Create requests, view assigned inventory and notifications');
