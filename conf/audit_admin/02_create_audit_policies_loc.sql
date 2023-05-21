--------------------------------------------------------------------------------
--  Trivadis - Part of Accenture, Platform Factory - Data Platforms
--  Saegereistrasse 29, 8152 Glattbrugg, Switzerland
--------------------------------------------------------------------------------
--  Name......: 02_create_audit_policies_loc.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@accenture.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.03.06
--  Usage.....: 
--  Purpose...: Create custom local audit policies
--  Notes.....: 
--  Reference.: 
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------

SET SERVEROUTPUT ON
SET linesize 160 pagesize 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80

--------------------------------------------------------------------------------
-- Create audit policy to audit all action for privileged users
CREATE AUDIT POLICY bfm_loc_all_act_priv_usr
    ACTIONS ALL
    ONLY TOPLEVEL;

COMMENT ON AUDIT POLICY bfm_loc_all_act_priv_usr IS
    'BFM local audit policy to audit all actions by priviledged users';

--------------------------------------------------------------------------------
-- Create audit policy to audit all action by users with direct access
CREATE AUDIT POLICY bfm_loc_all_act_direct_acc
    ACTIONS ALL
    WHEN '(sys_context(''userenv'',''ip_address'') IS NULL)' EVALUATE PER SESSION
    ONLY TOPLEVEL;

COMMENT ON AUDIT POLICY bfm_loc_all_act_direct_acc IS
    'BFM local audit policy to audit all actions through direct access';

--------------------------------------------------------------------------------
-- Create audit policy to audit all action by users with direct access
CREATE AUDIT POLICY bfm_loc_all_act_proxy_usr
ACTIONS ALL
    WHEN '(sys_context(''userenv'',''proxy_user'') IS NOT NULL)'
    EVALUATE PER SESSION
    ONLY TOPLEVEL;

COMMENT ON AUDIT POLICY bfm_loc_all_act_proxy_usr IS
    'BFM local audit policy to audit all actions of proxy user access';

--------------------------------------------------------------------------------
-- Create audit policy to audit all datapump events
CREATE AUDIT POLICY bfm_loc_all_dp_events
    ACTIONS COMPONENT = datapump export, import;

COMMENT ON AUDIT POLICY bfm_loc_all_dp_events IS
    'BFM local audit policy to audit all datapump events';

--------------------------------------------------------------------------------
-- Create audit policy to audit all directory access events
CREATE AUDIT POLICY bfm_loc_dir_acc
    ACTIONS READ DIRECTORY, WRITE DIRECTORY, EXECUTE DIRECTORY
    ONLY TOPLEVEL;

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;

-- List audit policies with comments
SELECT * FROM audit_unified_policy_comments;

-- EOF -------------------------------------------------------------------------