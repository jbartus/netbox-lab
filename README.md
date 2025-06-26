# what
this repo sets up four instances of netbox
- `nbc.tf` and `nbc.sh` setup netbox community (open source) on a standalone vm
- `nbe.tf`, `nbe.sh.tpl` and `config.yaml.tpl` setup netbox enterprise (on-prem) on a standalone vm
- `eks.tf` and `nbc-helm.sh` setup netbox community on an EKS (kubernetes) cluster using an external RDS database from `postgres.tf`
- `eks.tf` and `nbe-helm.sh` setup netbox enterprise on EKS

# pre-req
```
which terraform aws session-manager-plugin kubectl helm
```

# how to use
- setup your aws auth
- clone this repo
- `cd netbox-lab`
- `terraform init`
- `cp terraform.tfvars.example terraform.tfvars`
- edit `terraform.tfvars` to add your nbe license id and define your region
- `terraform apply`
- wait ~12 minutes
- click the output links
- accept/get-past the tls warnings
- login with admin/admin or the passwords you defined
