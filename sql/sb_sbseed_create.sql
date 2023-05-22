--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: sb_sbseed_create.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.19
-- Revision..:  
-- Purpose...: Script to create a SecBench SEED PDB
-- Notes.....:  
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- define default values
DEFINE _seed_pdb_name   = 'sbseed'
DEFINE _tablespace_name = 'SOE_DATA'
DEFINE _tablespace_size = '2048M'
DEFINE audit_retention  = 30

-- assign default value for parameter if argument 1,2 or 3 is empty
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN 1 NEW_VALUE 1 NOPRINT
COLUMN 2 NEW_VALUE 2 NOPRINT
COLUMN 3 NEW_VALUE 3 NOPRINT
COLUMN 4 NEW_VALUE 4 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
SELECT '' "2" FROM dual WHERE ROWNUM = 0;
SELECT '' "3" FROM dual WHERE ROWNUM = 0;
SELECT '' "4" FROM dual WHERE ROWNUM = 0;
DEFINE seed_pdb_name          = &1 &_seed_pdb_name
DEFINE tablespace_name    = &2 &_tablespace_name
DEFINE tablespace_size    = &3 &_tablespace_size
DEFINE default_password   = &4
COLUMN seed_pdb_name NEW_VALUE seed_pdb_name NOPRINT
SELECT upper('&seed_pdb_name') seed_pdb_name FROM dual;
COLUMN tablespace_name NEW_VALUE tablespace_name NOPRINT
SELECT upper('&tablespace_name') tablespace_name FROM dual;

-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
DECLARE
    v_datafile_path     varchar2(513);
    v_db_unique_name    varchar2(30);
    v_seed_pdb_name     varchar2(128) := '&seed_pdb_name';
    v_tablespace_name   varchar2(30)  := '&tablespace_name';
    v_tablespace_name   varchar2(30)  := '&tablespace_size';
    v_audit_data_file   varchar2(513);
    e_pdb_exists EXCEPTION;
    e_pdb_open EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_pdb_exists,-65012); 
    PRAGMA EXCEPTION_INIT(e_pdb_open,-65019); 
BEGIN
  DBMS_OUTPUT.put_line('Setup and SecBench SEED database:');
  SELECT file_name INTO v_datafile_path FROM dba_data_files WHERE file_id=1;
  SELECT db_unique_name INTO v_db_unique_name FROM v$database;

  DBMS_OUTPUT.put('- create &seed_pdb_name...............: ');
  BEGIN
    EXECUTE IMMEDIATE 'CREATE PLUGGABLE DATABASE &seed_pdb_name ADMIN USER "PDBADMIN" IDENTIFIED BY "&default_password" FILE_NAME_CONVERT=(''pdbseed'',''&seed_pdb_name'')';
    DBMS_OUTPUT.put_line('created');
  EXCEPTION
     WHEN e_pdb_exists THEN
          DBMS_OUTPUT.PUT_LINE('already exists');
  END;
    DBMS_OUTPUT.put('- open &seed_pdb_name.................: ');
  BEGIN
     EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE &seed_pdb_name OPEN READ WRITE';
     DBMS_OUTPUT.put_line('open');
  EXCEPTION
     WHEN e_pdb_open THEN
          DBMS_OUTPUT.PUT_LINE('already open');
  END;
  
  DBMS_OUTPUT.put('- save state &seed_pdb_name...........: ');
  EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE &seed_pdb_name SAVE STATE';
  DBMS_OUTPUT.put_line('done');
END;
/

ALTER SESSION SET CONTAINER=&seed_pdb_name;
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200

DECLARE
  v_version           number;
  v_datafile_path     varchar2(513);
  v_db_unique_name    varchar2(30);
  v_tablespace_name   varchar2(30) := '&tablespace_name';
  e_tablespace_exists EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_tablespace_exists,-1543);

BEGIN
  -- Create Tablespace but rise an exeption if it allready exists
  DBMS_OUTPUT.put('- Create '||v_tablespace_name||' Tablespace...: ');
  SELECT file_name INTO v_datafile_path FROM dba_data_files WHERE lower(file_name) LIKE '%system%' AND rownum <2;

  BEGIN
    IF v_datafile_path LIKE '+%' THEN
      SELECT regexp_substr(file_name,'[^/]*') INTO v_datafile_path FROM dba_data_files WHERE lower(file_name) LIKE '%system%' AND rownum <2;
      EXECUTE IMMEDIATE 'CREATE BIGFILE TABLESPACE '||v_tablespace_name||' DATAFILE '''||v_datafile_path||''' SIZE &tablespace_size AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED';
    ELSE
      SELECT regexp_substr(file_name,'^/.*/') INTO v_datafile_path FROM dba_data_files WHERE lower(file_name) LIKE '%system%' AND rownum <2;
      -- Datafile String for Audit Tablespace
      v_datafile_path := v_datafile_path||lower(v_tablespace_name)||'01'||v_db_unique_name||'.dbf'; 
      EXECUTE IMMEDIATE 'CREATE BIGFILE TABLESPACE '||v_tablespace_name||' DATAFILE '''||v_datafile_path||''' SIZE &tablespace_size AUTOEXTEND ON NEXT 10240K MAXSIZE UNLIMITED';
    END IF;
    DBMS_OUTPUT.put_line('created');
  EXCEPTION
    WHEN e_tablespace_exists THEN
      DBMS_OUTPUT.PUT_LINE('already exists');
  END;
END;
/

-- grant a few privileges to pdbadmin
GRANT dba TO pdbadmin;
GRANT EXECUTE ON dbms_lock TO pdbadmin WITH GRANT OPTION;
GRANT SELECT ON sys.v_$parameter TO pdbadmin WITH GRANT OPTION;

-- set default tablespace to pdbadmin
ALTER DATABASE DEFAULT TABLESPACE &tablespace_name;

-- EOF ---------------------------------------------------------------------
