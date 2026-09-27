-- ============================================
-- Migration 016: Force Password Change on First Login
-- ============================================
-- Adds must_change_password flag to users table.
-- New users start with must_change_password = 1 (true).
-- After the user changes their password, the flag is reset to 0.
-- On login, the frontend checks this flag and forces a password change.

-- NOTE (Phase-2 repair): the original statement was invalid MySQL syntax —
-- a column COMMENT cannot follow `AFTER <col>` (and not with a comma). It now reads
-- `... DEFAULT 1 COMMENT '...' AFTER status;` so this migration actually executes.
ALTER TABLE users
  ADD COLUMN must_change_password TINYINT(1) NOT NULL DEFAULT 1
    COMMENT 'When 1, the user must change their password on next login'
    AFTER status;

-- Existing users should not be forced to change password (backward compatibility)
UPDATE users SET must_change_password = 0;

-- Add index for efficient lookups
CREATE INDEX idx_users_must_change_password ON users(must_change_password);
