--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: setup.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.05.22
--  Revision..:  
--  Purpose...: SQL script to setup and configure the SecBench PDB
--  Notes.....:  
--  Reference.: SYS (or grant manually to a DBA)
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80

-- Disable all policies which are not from AVDF identified by policy name 'ORA_AV$'
DECLARE
    v_sql       VARCHAR2(4000);
BEGIN
    FOR r_audit_unified_enabled_policies IN (
            SELECT policy_name,entity_name,entity_type 
            FROM audit_unified_enabled_policies 
            WHERE policy_name NOT LIKE 'ORA_AV$%' OR entity_name IN ('SYSDG','SYSBACKUP')) LOOP    
        IF r_audit_unified_enabled_policies.entity_name='ALL USERS' THEN
            v_sql := 'NOAUDIT POLICY '
                || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.policy_name);
        ELSIF r_audit_unified_enabled_policies.entity_type='ROLE' THEN
            v_sql := 'NOAUDIT POLICY '
                || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.policy_name)
                || ' BY USERS WITH GRANTED ROLES '
                || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.entity_name);
        ELSE
            v_sql := 'NOAUDIT POLICY '
                || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.policy_name)
                || ' BY '
                || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.entity_name);
        END IF;
        -- display NOAUDIT statement
        dbms_output.put_line('INFO : execute '||v_sql);
        --- execute NOAUDIT statement
        EXECUTE IMMEDIATE v_sql;
    END LOOP;
END;
/

-- Drop all audit policies which are not provided by Oracle. Either where
-- oracle_supplied<>'YES' AND policy_name NOT LIKE 'ORA_AV$'
DECLARE
    v_sql       VARCHAR2(4000);
BEGIN
    FOR r_audit_unified_enabled_policies IN (SELECT policy_name, common FROM audit_unified_policies WHERE oracle_supplied<>'YES' AND policy_name NOT LIKE 'ORA_AV$%' GROUP BY policy_name, common ) LOOP      
        v_sql := 'DROP AUDIT POLICY '
            || sys.dbms_assert.enquote_name(r_audit_unified_enabled_policies.policy_name);
        -- display DROP AUDIT statement
        dbms_output.put_line('INFO : execute '||v_sql);
        --- execute DROP AUDIT statement
        EXECUTE IMMEDIATE v_sql;
    END LOOP;
END;
/

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;
-- EOF ---------------------------------------------------------------------
