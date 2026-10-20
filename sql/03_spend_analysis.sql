-- ============================================================================
-- 03_spend_analysis.sql
-- Northstar Electronics — Procurement Analytics
-- Purpose: first analysis script. Answers the spend questions from
-- PROJECT_SPEC.md: how much are we spending, how has it changed over time,
-- and which departments and categories drive it. Reads from the cleaned
-- dbo. tables built in 02_data_cleaning.sql. Nothing is modified here.
-- ============================================================================

USE NorthstarProcurement;
GO

-- ----------------------------------------------------------------------------
-- 1. Total Procurement Spend
-- Sum of Quantity x Unit_Price, Completed PO lines only (see PROJECT_SPEC.md
-- KPI definitions and inclusion rules).
-- ----------------------------------------------------------------------------