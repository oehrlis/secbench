--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: sb_sbseed_drop.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.05.19
--  Revision..:  
--  Purpose...: Script to drop a SecBench SEED PDB
--  Notes.....:  
--  Reference.: SYS (or grant manually to a DBA)
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- define default values
DEFINE _seed_pdb_name       = 'sbseed'

-- assign default value for parameter if argument 1,2 or 3 is empty
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN 1 NEW_VALUE 1 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
DEFINE seed_pdb_name          = &1 &_seed_pdb_name
COLUMN seed_pdb_name NEW_VALUE seed_pdb_name NOPRINT
SELECT upper('&seed_pdb_name') seed_pdb_name FROM dual;

-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
DECLARE
    v_seed_pdb_name     varchar2(128) := '&seed_pdb_name';
    v_audit_data_file   varchar2(513);
    e_pdb_notexist EXCEPTION;
    e_pdb_closed EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pdb_notexist,-65011); 
    PRAGMA EXCEPTION_INIT(e_pdb_closed,-65020); 
    
BEGIN
  DBMS_OUTPUT.put_line('Decommission the SecBench SEED database');

  DBMS_OUTPUT.put('- close &seed_pdb_name.......: ');
  BEGIN
    EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE &seed_pdb_name CLOSE';
    DBMS_OUTPUT.put_line('closed');
  EXCEPTION
    WHEN e_pdb_notexist THEN
      DBMS_OUTPUT.PUT_LINE('does not exists');
    WHEN e_pdb_closed THEN
      DBMS_OUTPUT.PUT_LINE('already closed');
  END;
    DBMS_OUTPUT.put('- drop &seed_pdb_name........: ');
  BEGIN
    EXECUTE IMMEDIATE 'DROP PLUGGABLE DATABASE &seed_pdb_name INCLUDING DATAFILES';
    DBMS_OUTPUT.put_line('dropped');
  EXCEPTION
    WHEN e_pdb_notexist THEN
      DBMS_OUTPUT.PUT_LINE('does not exists');
  END;
END;
/

-- EOF ---------------------------------------------------------------------
