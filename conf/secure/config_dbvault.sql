--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: config_dbvault.sql
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
-- create realms
BEGIN
    dvsys.dbms_macadm.create_realm(realm_name => 'SecBench Schema Protection Realm', description => 'SecBench Schema Realm ', 
    enabled => 'S', audit_options => 1, realm_type => '1');
END;
/
-- assign object to realm
BEGIN
    dvsys.dbms_macadm.add_object_to_realm(realm_name => 'SecBench Schema Protection Realm', 
    object_owner => sys.dbms_assert.enquote_name('SOE', false), object_name => '%', object_type => '%');
END;
/

-- add authorization to realm
BEGIN
    dvsys.dbms_macadm.add_auth_to_realm(realm_name => 'SecBench Schema Protection Realm', 
    grantee => sys.dbms_assert.enquote_name('SOE', false), rule_set_name => '', auth_options => DBMS_MACUTL.G_REALM_AUTH_OWNER);
END;
/
-- EOF ---------------------------------------------------------------------