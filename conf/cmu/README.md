# SecBench with Centrally Managed User (CMU)

Configuration to setup a database Centrally Managed User (CMU) enabled.

- [setup.sh](setup.sh) wrapper script to call [setup.sql](setup.sql)
- [setup.sql](setup.sql) SQL script to configure PDB for regular security benchmark
- [remove.sh](setup.sh) wrapper script to call [remove.sql](remove)
- [remove](remove) SQL script to remove regular configuration in PDB

- Create the CMU wallet using `orapki`

```bash
orapki wallet create -wallet $SECBENCH_BASE/conf/cmu -pwd LAB42-Schulung -auto_login
```

- Add the CMU user credentials to the wallet. i.e. the username, password and
  distinguished name.

```bash
cd $SECBENCH_BASE/conf/cmu
mkstore -wrl . -createEntry ORACLE.SECURITY.USERNAME cmuread
mkstore -wrl . -createEntry \
 ORACLE.SECURITY.DN CN=cmuread,CN=Users,DC=trivadislabs,DC=com
mkstore -wrl . -createEntry ORACLE.SECURITY.PASSWORD LAB42-Schulung
```

- add the root certificate to the wallet

```bash
cd $SECBENCH_BASE/conf/cmu
orapki wallet add -wallet . -pwd LAB42-Schulung -trusted_cert \
-cert $SECBENCH_BASE/conf/cmu/root.crt
```