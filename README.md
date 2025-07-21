# what
this repo sets up four instances of netbox
- `nbc.tf` and `nbc.sh` setup netbox community (open source) on a standalone vm
- `nbe.tf`, `nbe.sh.tpl` and `config.yaml.tpl` setup netbox enterprise (on-prem) on a standalone vm
- `eks.tf` and `nbc-helm.sh` setup netbox community on EKS (kubernetes) using an external RDS db from `postgres.tf`
- `eks.tf`, `nbe-helm.sh` and `nbe-values.yaml` setup netbox enterprise on EKS

# pre-req
## mac os
install homebrew (if you don't already have it)
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
```
brew install terraform awscli session-manager-plugin kubernetes-cli helm
```

# how to use
- setup your aws auth
- clone this repo
```
git clone https://github.com/jbartus/netbox-lab.git
```
- `cd` into it
```
cd netbox-lab
```
- initialize terraform (pull in providers & modules)
```
terraform init
```
- copy the example variables file to your own
```
cp terraform.tfvars.example terraform.tfvars
```
- edit `terraform.tfvars` to add your nbe license id and define your region
NOTE: make sure the region you define matches that which your cli is configured to use
```
aws ec2 describe-availability-zones --query "AvailabilityZones[0].RegionName"
```
- kick off the setup
```
terraform apply
```
- wait ~12 minutes
- click the output links
- accept/get-past the tls warnings
- login with admin/admin or the passwords you defined
