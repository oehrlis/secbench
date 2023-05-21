--------------------------------------------------------------------------------
--  Trivadis - Part of Accenture, Platform Factory - Data Platforms
--  Saegereistrasse 29, 8152 Glattbrugg, Switzerland
--------------------------------------------------------------------------------
--  Name......: 03_enable_audit_policies_loc.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@accenture.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.04.28
--  Usage.....: 
--  Purpose...: Enable custom local audit policies
--  Notes.....: 
--  Reference.: 
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;

-- enable custom audit policies
AUDIT POLICY bfm_loc_all_act_priv_usr BY SYS, SYSKM, SYSRAC, PUBLIC;
AUDIT POLICY bfm_loc_all_act_priv_usr BY USERS WITH GRANTED ROLES dba,datapump_exp_full_database, imp_full_database, exp_full_database, datapump_imp_full_database;
AUDIT POLICY bfm_loc_all_act_proxy_usr;
AUDIT POLICY bfm_loc_all_dp_events;
AUDIT POLICY bfm_loc_dir_acc;

-- enable AVDF audit policies
AUDIT POLICY ora_av$_critical_db_activity;
AUDIT POLICY ora_av$_db_schema_changes;
AUDIT POLICY ora_av$_logon_events EXCEPT dbsnmp, avagent;
AUDIT POLICY ora_av$_logon_failures WHENEVER NOT SUCCESSFUL;

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies ORDER BY 1;
-- EOF -------------------------------------------------------------------------