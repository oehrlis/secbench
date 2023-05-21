--------------------------------------------------------------------------------
--  Trivadis - Part of Accenture, Platform Factory - Data Platforms
--  Saegereistrasse 29, 8152 Glattbrugg, Switzerland
--------------------------------------------------------------------------------
--  Name......: 05_list_audit_policies.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@accenture.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.03.06
--  Usage.....: 
--  Purpose...: Initialize Audit environment
--  Notes.....: 
--  Reference.: 
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A28
COL entity_name FOR A26
COL comments FOR A70
SHOW con_name

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies ORDER BY 1;

-- List audit policies not maintained by Oracle
SELECT 
    auep.policy_name,
    auep.enabled_option,
    auep.entity_name,
    auep.entity_type,
    auep.success,
    auep.failure,
    aupc.comments
FROM audit_unified_enabled_policies auep, audit_unified_policy_comments aupc 
WHERE auep.policy_name=aupc.policy_name ORDER BY 1;
-- EOF -------------------------------------------------------------------------
