# CP4WAIOps-BCDR

- Code repo for automated backup and recovery of  functional components of CP4WAIOps on a new or existing cluster.
- It uses OADP Operator  with s3 compliant object storage for storing state of the application.
  - Internally it uses `velero`for cluster object backups
  - It uses `restic` for volume backups
- It can be deployed on any cluster post CP4AIOps deployment by using helm charts, or the supported artifacts
- This backup/restore process follow the [design spec](https://github.ibm.com/katamari/architecture/blob/master/feature-specs/bcdr/bcdr.md)

## Reference
This repo is derived from the [CP for MCM backup repo](https://github.ibm.com/IBMPrivateCloud/CP4MCM-BCDR/tree/master/backup)
