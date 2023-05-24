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
-- setup SQLPlus environment
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80

-- enable legacy audit stuff
NOAUDIT ALTER ANY TABLE;
NOAUDIT CREATE ANY TABLE;
NOAUDIT DROP ANY TABLE;
NOAUDIT CREATE ANY PROCEDURE;
NOAUDIT DROP ANY PROCEDURE;
NOAUDIT ALTER ANY PROCEDURE;
NOAUDIT GRANT ANY PRIVILEGE;
NOAUDIT GRANT ANY OBJECT PRIVILEGE;
NOAUDIT GRANT ANY ROLE;
NOAUDIT AUDIT SYSTEM;
NOAUDIT CREATE EXTERNAL JOB;
NOAUDIT CREATE ANY JOB;
NOAUDIT CREATE ANY LIBRARY;
NOAUDIT CREATE PUBLIC DATABASE LINK;
NOAUDIT EXEMPT ACCESS POLICY;
NOAUDIT ALTER USER;
NOAUDIT CREATE USER;
NOAUDIT ROLE;
NOAUDIT CREATE SESSION;
NOAUDIT DROP USER;
NOAUDIT ALTER DATABASE;
NOAUDIT ALTER SYSTEM;
NOAUDIT ALTER PROFILE;
NOAUDIT DROP PROFILE;
NOAUDIT DATABASE LINK;
NOAUDIT SYSTEM AUDIT;
NOAUDIT PROFILE;
NOAUDIT PUBLIC SYNONYM;
NOAUDIT SYSTEM GRANT;
NOAUDIT CREATE SQL TRANSLATION PROFILE;
NOAUDIT CREATE ANY SQL TRANSLATION PROFILE;
NOAUDIT DROP ANY SQL TRANSLATION PROFILE;
NOAUDIT ALTER ANY SQL TRANSLATION PROFILE;
NOAUDIT TRANSLATE ANY SQL;
NOAUDIT PURGE DBA_RECYCLEBIN;
NOAUDIT LOGMINING;
NOAUDIT EXEMPT REDACTION POLICY;
NOAUDIT ADMINISTER KEY MANAGEMENT;
NOAUDIT DIRECTORY;
NOAUDIT PLUGGABLE DATABASE;
NOAUDIT BECOME USER;

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;

-- list legacy audit
COL user_name FOR A10
COL proxy_name FOR A10
COL audit_option FOR A40
COL success FOR A10
COL failure FOR A10
SELECT * FROM dba_stmt_audit_opts;
-- EOF ---------------------------------------------------------------------
