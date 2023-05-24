--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: remove.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.22
-- Revision..:  
-- Purpose...: SQL script to remove the SecBench PDB configuration
-- Notes.....:  
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;
-- disable / remove audit policy
NOAUDIT POLICY sb_dv_SecBench;
DROP CREATE AUDIT POLICY sb_dv_SecBench;
-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;
-- EOF ---------------------------------------------------------------------
