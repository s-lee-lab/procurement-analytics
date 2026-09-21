-- ============================================================================
-- 02_data_cleaning.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: build cleaned dbo. tables from the stg_ staging tables identified
-- in 01_data_quality.sql. Drops exact-duplicate rows, converts columns to
-- real types (DATE, DECIMAL, etc.) via TRY_CAST/TRY_CONVERT, and standardizes
-- formatting inconsistencies (Currency, PO_Status). Invalid values (negative
-- price, zero quantity, malformed dates) are NOT deleted — TRY_CAST/
-- TRY_CONVERT naturally turns them into NULL, preserving row counts and
-- traceability to 01_data_quality.sql's findings (see DECISIONS.md for
-- rationale).
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------