--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: remove_dbvault.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.22
-- Revision..:  
-- Purpose...: Script to configure DB Vault
-- Notes.....: Must be executed as DV_OWNER or user with DV_OWNER role
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- delete realms
BEGIN
    dvsys.dbms_macadm.delete_realm(realm_name => 'SecBench Schema Protection Realm');
END;

-- EOF ---------------------------------------------------------------------