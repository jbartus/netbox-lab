# what is this
this repo is a mix of mostly terraform-hcl and shell code that sets up four instances of netbox in an aws account, for testing and demonstrating functionality

## two on standalone VMs
- `nbc.tf` and `nbc.sh` setup netbox community (open source)
- `nbe.tf`, `nbe.sh.tpl` and `config.yaml.tpl` setup netbox enterprise ("on-prem")

## two on kubernetes (via helm charts)
- `eks.tf` sets up a small EKS cluster running on spot instances
- `nbc-helm.sh` sets up netbox community using an external RDS db from `postgres.tf`
- `nbe-helm.sh` and `nbe-values.yaml` setup netbox enterprise on EKS

## other bits
- `c8kv.tf` sets up a [Cisco 8000V](https://www.cisco.com/c/en/us/products/collateral/routers/catalyst-8000v-edge-software/catalyst-8000v-edge-software-ds.html) ec2 instance running ios xe.  it doesn't do anything but exist to be a target of scanning/discovery/configuration-automation.
- `orb.tf`, `orb.sh.tpl` and `orb.yaml.tpl` setup the netbox orb discovery agent (pointed at NBE & the above "router"), including a vault instance for a test/dummy "secret"
- `ansible.tf` and `ansible.sh.tpl` setup a vm for running ansible playbooks/runbooks.  `ansible-in.yaml` populates a netbox instance with some dummy/demo data

## plumbing
- `vpc.tf` creates the base vpc that all of this lives in
- `ssm.tf` enables the use of ssm-session-manager, which in turn both obviates the need for ssh key management and enables the use of aws console in a browser tab during screenshares

NOTE: this is all written/designed with the expectation that the environment be SHORT LIVED.  
measured in hours, rarely 24, and never lasting a weekend.
nothing in here is to be taken as best practice or production level config.

# prerequisites
## mac os
install homebrew (if you don't already have it)
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
```
brew install terraform awscli session-manager-plugin kubernetes-cli helm
```

# how to use
- setup your aws cli authentication. verify with:
```
aws sts get-caller-identity
```
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
- edit `terraform.tfvars` to add your nbe license id and define your region.  be sure the region you define matches what your cli is configured to use
```
aws ec2 describe-availability-zones --query "AvailabilityZones[0].RegionName"
```
- run a `plan` to be check for errors
```
terraform plan
```
- kick off the setup (the main event)
```
terraform apply
```
- wait ~12 minutes
- click the output links
- accept/get-past the tls warnings
- login with admin/admin or the passwords you defined
- test or demonstrate your thing
- cleanup (very important step!)
```
terraform destroy
```

# tips
for most of the `foo.tf` files the related `resource` `data` and `output` are kept together so that if you're not interested in `foo` right now you can just bulk-comment-out the whole file

`eks.tf` and `postgres.tf` are by far the slowest parts, so if you're not doing anything helm/kubernetes related commenting them out saves about half the apply/destroy time
