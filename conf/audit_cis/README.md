# SecBench Audit CIS

Configuration to setup CIS recommended audit policies in the PDB.

- [create_audit_policies_loc.sql](create_audit_policies_loc.sql) SQL script to
  create the corresponding audit policies. It is called by [setup.sql](setup.sql)
- [setup.sh](setup.sh) wrapper script to call [setup.sql](setup.sql)
- [setup.sql](setup.sql) SQL script to configure PDB for regular security benchmark
- [remove.sh](setup.sh) wrapper script to call [remove.sql](remove)
- [remove](remove) SQL script to remove regular configuration in PDB
