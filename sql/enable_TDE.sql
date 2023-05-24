--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: enable_TDE.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.22
-- Revision..: 
-- Purpose...: Script to enable TDE
-- Notes.....: 
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
----------------------------------------------------------------------------
-- define default values
DEFINE _wallet_pwd       = 'Changeme_1234'

-- assign default value for parameter if argument 1,2 or 3 is empty
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE wallet_pwd          = &1 &_wallet_pwd
COLUMN wallet_pwd NEW_VALUE wallet_pwd NOPRINT

-- get the admin directory
COLUMN admin_path NEW_VALUE admin_path NOPRINT

SELECT
    substr(value, 1, instr(value, '/', - 1, 1) - 1) admin_path
FROM
    v$parameter
WHERE
    name = 'audit_file_dest';

-- create the wallet folder
HOST mkdir -p &admin_path/wallet
host mkdir -p &admin_path/wallet/tde
host mkdir -p &admin_path/wallet/tde_seps

-- set the WALLET ROOT parameter
ALTER SYSTEM SET wallet_root='&admin_path/wallet' SCOPE=SPFILE;
STARTUP FORCE;

-- config TDE_CONFIGURATION
ALTER SYSTEM SET TDE_CONFIGURATION='KEYSTORE_CONFIGURATION=FILE' scope=both;

-- create software keystore
ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '&admin_path/wallet/tde' IDENTIFIED BY "&wallet_pwd";
          
ADMINISTER KEY MANAGEMENT ADD SECRET '&wallet_pwd' FOR CLIENT 'TDE_WALLET' TO LOCAL AUTO_LOGIN KEYSTORE '&admin_path/wallet/tde_seps';
         
-- open the wallet
ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY EXTERNAL STORE;

-- create autologin
ADMINISTER KEY MANAGEMENT CREATE LOCAL AUTO_LOGIN KEYSTORE FROM KEYSTORE '&admin_path/wallet/tde' IDENTIFIED BY "&wallet_pwd";
STARTUP FORCE;

-- set master key
ADMINISTER KEY MANAGEMENT SET KEY FORCE KEYSTORE IDENTIFIED BY EXTERNAL STORE WITH BACKUP;

-- list wallet information
SET LINESIZE 160 PAGESIZE 200
COL wrl_type FOR A10
COL wrl_parameter FOR A50

SELECT * FROM v$encryption_wallet;

-- list information about TDE TS

SELECT
    ts#,
    encryptionalg,
    encryptedts,
    blocks_encrypted,
    blocks_decrypted, con_id FROM v$encrypted_tablespaces;

-- EOF ---------------------------------------------------------------------
