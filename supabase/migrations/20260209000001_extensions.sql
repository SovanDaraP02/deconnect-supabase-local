-- ============================================================================
-- EXTENSIONS AND SETUP
-- ============================================================================
--
-- PostgreSQL extensions required for DeConnect
--
-- Part of DeConnect Database Schema
-- Apply migrations in numerical order
--
-- ============================================================================

create extension if not exists "pg_cron" with schema "pg_catalog";

drop extension if exists "pg_net";

