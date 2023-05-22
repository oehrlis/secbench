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
-- setup SQLPlus environment
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80
COL name FOR A50
COL value FOR A80

-- List audit parameters
SELECT name,value FROM v$parameter WHERE name LIKE '%audit%';

-- List enabled audit policies
SELECT * FROM audit_unified_enabled_policies;

-- enable legacy audit stuff
AUDIT ALTER ANY TABLE BY ACCESS;
AUDIT CREATE ANY TABLE BY ACCESS;
AUDIT DROP ANY TABLE BY ACCESS;
AUDIT CREATE ANY PROCEDURE BY ACCESS;
AUDIT DROP ANY PROCEDURE BY ACCESS;
AUDIT ALTER ANY PROCEDURE BY ACCESS;
AUDIT GRANT ANY PRIVILEGE BY ACCESS;
AUDIT GRANT ANY OBJECT PRIVILEGE BY ACCESS;
AUDIT GRANT ANY ROLE BY ACCESS;
AUDIT AUDIT SYSTEM BY ACCESS;
AUDIT CREATE EXTERNAL JOB BY ACCESS;
AUDIT CREATE ANY JOB BY ACCESS;
AUDIT CREATE ANY LIBRARY BY ACCESS;
AUDIT CREATE PUBLIC DATABASE LINK BY ACCESS;
AUDIT EXEMPT ACCESS POLICY BY ACCESS;
AUDIT ALTER USER BY ACCESS;
AUDIT CREATE USER BY ACCESS;
AUDIT ROLE BY ACCESS;
AUDIT CREATE SESSION BY ACCESS;
AUDIT DROP USER BY ACCESS;
AUDIT ALTER DATABASE BY ACCESS;
AUDIT ALTER SYSTEM BY ACCESS;
AUDIT ALTER PROFILE BY ACCESS;
AUDIT DROP PROFILE BY ACCESS;
AUDIT DATABASE LINK BY ACCESS;
AUDIT SYSTEM AUDIT BY ACCESS;
AUDIT PROFILE BY ACCESS;
AUDIT PUBLIC SYNONYM BY ACCESS;
AUDIT SYSTEM GRANT BY ACCESS;
AUDIT CREATE SQL TRANSLATION PROFILE BY ACCESS;
AUDIT CREATE ANY SQL TRANSLATION PROFILE BY ACCESS;
AUDIT DROP ANY SQL TRANSLATION PROFILE BY ACCESS;
AUDIT ALTER ANY SQL TRANSLATION PROFILE BY ACCESS;
AUDIT TRANSLATE ANY SQL BY ACCESS;
AUDIT PURGE DBA_RECYCLEBIN BY ACCESS;
AUDIT LOGMINING BY ACCESS;
AUDIT EXEMPT REDACTION POLICY BY ACCESS;
AUDIT ADMINISTER KEY MANAGEMENT BY ACCESS;
AUDIT DIRECTORY BY ACCESS;
AUDIT PLUGGABLE DATABASE BY ACCESS;
AUDIT BECOME USER BY ACCESS;

-- list legacy audit
COL user_name FOR A10
COL proxy_name FOR A10
COL audit_option FOR A40
COL success FOR A10
COL failure FOR A10
SELECT * FROM dba_stmt_audit_opts;
-- EOF ---------------------------------------------------------------------
