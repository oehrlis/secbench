--------------------------------------------------------------------------------
-- OraDBA - Oracle Database Infrastructure and Security, 5630 Muri, Switzerland
--------------------------------------------------------------------------------
-- Name......: setup.sql
-- Author....: Stefan Oehrli (oes) stefan.oehrli@oradba.com
-- Editor....: Stefan Oehrli
-- Date......: 2023.05.22
-- Revision..:  
-- Purpose...: SQL script to setup and configure the SecBench PDB
-- Notes.....:  
-- Reference.: SYS (or grant manually to a DBA)
-- License...: Apache License Version 2.0, January 2004 as shown
--             at http://www.apache.org/licenses/
--------------------------------------------------------------------------------
-- get some information about the path
SET SERVEROUTPUT ON
SET LINESIZE 160 PAGESIZE 200
COL policy_name FOR A40
COL entity_name FOR A30
COL comments FOR A80

COL net_sid HEAD SID FOR 99999
COL net_osuser HEAD OS_USER FOR a10
COL net_authentication_type HEAD AUTH_TYPE FOR a10 
COL net_network_service_banner HEAD NET_BANNER FOR a100

SELECT 
    sid                    net_sid, 
    osuser                 net_osuser, 
    authentication_type    net_authentication_type, 
    network_service_banner net_network_service_banner
FROM v$session_connect_info
WHERE sid=(SELECT sid FROM v$mystat WHERE ROWNUM = 1);
-- EOF ---------------------------------------------------------------------
