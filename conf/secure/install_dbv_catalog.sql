--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: install_dbv_catalog.sql.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Date......: 2023.05.22
-- Usage.....: @install_dbv_catalog.sql.sql <DATA_TS> <TEMP_TS>
-- Purpose...: Script to install DB Vault and Label Security Catalog Schemas
-- Notes.....: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- default values
DEFINE def_data_ts = "SYSTEM"
DEFINE def_temp_ts = "TEMP"

-- define a default value for parameter if argument 1 or 2 is empty
SET FEEDBACK OFF
SET VERIFY OFF
COLUMN 1 NEW_VALUE 1 NOPRINT
COLUMN 2 NEW_VALUE 2 NOPRINT
SELECT '' "1" FROM dual WHERE ROWNUM = 0;
SELECT '' "2" FROM dual WHERE ROWNUM = 0;
DEFINE data_ts = &1 &def_data_ts
DEFINE temp_ts = &2 &def_temp_ts

-- define environment stuff
SET PAGESIZE 200 LINESIZE 160
COL reg_comp_name   HEAD "Component Name"   FOR A50
COL reg_version     HEAD "Version"          FOR A15
COL reg_status      HEAD "Status"           FOR A11
COL reg_schema      HEAD "Schema"           FOR A15
COL reg_modified    HEAD "Modified"         FOR A20
SET FEEDBACK ON
CLEAR SCREEN
SET ECHO ON

-- list installed components
SET PAGESIZE 200 LINESIZE 160
SELECT 
    comp_name   reg_comp_name,
    version     reg_version,
    status      reg_status,
    schema      reg_schema,
    modified    reg_modified
FROM dba_registry;

-- install label security
@?/rdbms/admin/catols.sql

-- enable label security
EXEC lbacsys.configure_ols
EXEC lbacsys.ols_enforcement.enable_ols

-- restart the database
STARTUP FORCE;

-- install DB Vault
@?/rdbms/admin/catmac.sql &data_ts &temp_ts

-- list installed components
SET PAGESIZE 200 LINESIZE 160
SELECT 
    comp_name   reg_comp_name,
    version     reg_version,
    status      reg_status,
    schema      reg_schema,
    modified    reg_modified
FROM dba_registry;
-- EOF ---------------------------------------------------------------------
