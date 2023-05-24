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
COL tablespace_name FOR A40
COL status FOR A10
COL encrypted FOR A10
COL wrl_type FOR A10
COL wrl_parameter FOR A50
COL name FOR A50
COL value FOR A80

-- List enabled audit policies
SELECT tablespace_name,status,bigfile,encrypted FROM dba_tablespaces;

-- list wallet information
SELECT * FROM v$encryption_wallet;

-- list information about TDE TS
SELECT
    ts#,
    encryptionalg,
    encryptedts,
    blocks_encrypted,
    blocks_decrypted, con_id FROM v$encrypted_tablespaces;
-- EOF ---------------------------------------------------------------------
