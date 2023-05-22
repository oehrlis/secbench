--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: sb_secbench_create_pdb.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.19
-- Revision..:  
-- Purpose...: Script to create a SecBench PDB from SBSEED
-- Notes.....:  
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- define default values
DEFINE _seed_pdb_name   = 'sbseed'
DEFINE _pdb_name        = 'sbdb00'

-- assign default value for parameter if argument 1,2 or 3 is empty
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN 1 NEW_VALUE 1 NOPRINT
COLUMN 2 NEW_VALUE 2 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
SELECT '' "2" FROM dual WHERE ROWNUM = 0;
DEFINE seed_pdb_name      = &1 &_seed_pdb_name
DEFINE pdb_name           = &2 &_pdb_name
COLUMN seed_pdb_name NEW_VALUE seed_pdb_name NOPRINT
SELECT upper('&seed_pdb_name') seed_pdb_name FROM dual;
COLUMN seed_pdb_name_lower NEW_VALUE seed_pdb_name_lower NOPRINT
SELECT lower('&seed_pdb_name') seed_pdb_name_lower FROM dual;
COLUMN pdb_name NEW_VALUE pdb_name NOPRINT
SELECT upper('&pdb_name') pdb_name FROM dual;
COLUMN pdb_name_lower NEW_VALUE pdb_name_lower NOPRINT
SELECT lower('&pdb_name') pdb_name_lower FROM dual;

-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
DECLARE
  v_pdb_name          varchar2(128) := '&pdb_name';
  v_audit_data_file   varchar2(513);
  e_pdb_exists EXCEPTION;
  e_pdb_open EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_pdb_exists,-65012); 
  PRAGMA EXCEPTION_INIT(e_pdb_open,-65019); 

BEGIN
  DBMS_OUTPUT.put_line('Deploy the SecBench &pdb_name from SEED');
  DBMS_OUTPUT.put('- Create &pdb_name .......: ');
  BEGIN
    EXECUTE IMMEDIATE 'CREATE PLUGGABLE DATABASE &pdb_name FROM &seed_pdb_name FILE_NAME_CONVERT=(''&seed_pdb_name'',''&pdb_name'',''&seed_pdb_name_lower'',''&pdb_name_lower'')';
    DBMS_OUTPUT.put_line('created');
  EXCEPTION
    WHEN e_pdb_exists THEN DBMS_OUTPUT.PUT_LINE('already exists');
  END;

  DBMS_OUTPUT.put('- open &pdb_name.........: ');
  BEGIN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE &pdb_name OPEN READ WRITE';
    DBMS_OUTPUT.put_line('open');
  EXCEPTION
    WHEN e_pdb_open THEN DBMS_OUTPUT.PUT_LINE('already open');
  END;
  
  DBMS_OUTPUT.put_line('- save state &pdb_name...: done');
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE &pdb_name SAVE STATE';

END;
/

-- EOF ---------------------------------------------------------------------
