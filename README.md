# what
this repo sets up three instances of netbox
- `nbc.tf` and `nbc.sh` setup netbox community (open source) on a standalone vm
- `eks.tf` and `nbc-helm.sh` setup netbox community on an EKS (kubernetes) cluster
- `nbe.tf`, `nbe.sh.tpl` and `config.yaml.tpl` setup netbox enterprise (on-prem) on a standalone vm

# pre-req
## OSX 
Install the AWS session manager plugin following [these](https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-macos-overview.html) instructions.

Ensure the other dependencies are installed
```bash
which terraform aws kubectl helm
```

# how to use
- setup your aws auth
- clone this repo
```bash
git clone https://github.com/jbartus/netbox-lab.git 
```
Move into the cloned repository
```bash
cd netbox-lab
```

Initialise the terraform by pulling in all the dependencies
```bash
terraform init
```

Copy the default variables file.
```bash
cp terraform.tfvars.example terraform.tfvars`
```

- edit `terraform.tfvars` to add your nbe license id and define your region

Run terraform plan to understand what changes will be made
```bash
terraform plan
```

Run the actual deployment
```bash
terraform apply
```

- wait ~12 minutes
- click the output links
- accept/get-past the tls warnings
- login with admin/admin or the passwords you defined