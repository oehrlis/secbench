--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
--  Name......: remove.sql
--  Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
--  Editor....: Stefan Oehrli
--  Date......: 2023.05.22
--  Revision..:  
--  Purpose...: SQL script to remove the SecBench PDB configuration
--  Notes.....:  
--  Reference.: SYS (or grant manually to a DBA)
--  License...: Apache License Version 2.0, January 2004 as shown
--              at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200

SELECT sysdate FROM dual;
-- EOF ---------------------------------------------------------------------
