# what is this
this repo exists for me to learn netbox related functionality by doing things hands-on and commiting them as reproducable examples.  as a side-effect it also serves as a set of live demonstratable examples of netbox functionality.

this is fundamentally a terraform project, so the main workflow (once everything is setup) goes:

1. `terraform apply`
2. do your hacking/testing/demo
3. `terraform destroy`

NOTE: this is a TEMPORARY LAB environment.  
it is all written/designed with the expectation that the environment be SHORT LIVED (hours, not days).  
nothing in here is to be taken as best practice or production level config.

# pre-requisites
this project assumes a set of command line tools are installed.  you can copy/paste this command to verify you have them, or see which ones you don't:
```
for cmd in terraform aws session-manager-plugin kubectl helm; do command -v "$cmd" > /dev/null || echo "missing: $cmd"; done
```
if you see nothing, you're good.  for any that are missing, follow the instructions below for your OS.

## for mac os users
install homebrew (if you don't already have it)
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
```
brew install terraform awscli session-manager-plugin kubernetes-cli helm
```
## for ubuntu (wsl) users
### terraform
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
### aws-cli
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
### session manager plugin
https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-debian-and-ubuntu.html
### kubectl
```
sudo apt install -y kubectl
```
### helm
https://helm.sh/docs/intro/install/#from-apt-debianubuntu


# how to use this repo
## intial setup
1. setup your aws cli authentication. verify with:
   ```
   aws sts get-caller-identity
   ```

1. clone this repo
   ```
   git clone https://github.com/jbartus/netbox-lab.git
   ```

1. `cd` into it
   ```
   cd netbox-lab
   ```

1. initialize terraform (pull in providers & modules)
   ```
   terraform init
   ```

1. copy the example variables file to your own
   ```
   cp terraform.tfvars.example terraform.tfvars
   ```

1. edit your `terraform.tfvars` file
   1. set your aws region
   1. enable the components you're looking to test or demo by setting them to `true`
   1. for netbox enteprise add your license id.

1. check to be sure the region you just specified matches what your cli is configured to use
   ```
   aws ec2 describe-availability-zones --query "AvailabilityZones[0].RegionName"
   ```

1. run a `plan` to check for errors
   ```
   terraform plan
   ```

## main test loop
1. kick off the setup (the main event)
   ```
   terraform apply
   ```

   depending on what you enabled in your `terraform.tfvars` you will see a mix of URL and SSM outputs

   for the SSM commands you can simply copy & paste them to get command line access to the VM in question, where you will almost always want to run `sudo -i` first thing

   for the URLs you can click or copy/paste them into a browser, however note that while the VMs usually only take a minute or two to launch, an actual netbox install takes about 5 minutes for community and 10 minutes for enterprise, so you will need to wait a bit for them to be ready

   also note that I have used "dummy" TLS certificates, so your browser will warn you that they are not valid, you need to click whatever your browsers version of "i understand let me through anyway" is.

   login with the default credentials (`admin`/`admin`) or the ones you specified in `terraform.tfvars`

1. test or demonstrate your thing
1. cleanup (very important step!)
   ```
   terraform destroy
   ```

# what does it do?
- `vpc.tf` creates the base vpc that all of this lives in
- `ssm.tf` enables the use of ssm-session-manager, which means we don't expose ssh ports or bother with ssh keys, and we can use the aws console's ec2 instance "connect" option to display the terminal in a browser.
- `community.tf` and `community.sh` setup netbox community (open source)
- `enterprise.tf`, `enterprise.sh.tpl` and `config.yaml.tpl` setup netbox enterprise ("on-prem")
- `c8kv.tf` sets up a [Cisco 8000V](https://www.cisco.com/c/en/us/products/collateral/routers/catalyst-8000v-edge-software/catalyst-8000v-edge-software-ds.html) ec2 instance running ios xe.  it doesn't do anything but exist to be a target of scanning/discovery/configuration-automation.
- `orb.tf`, `orb.sh.tpl` and `orb.yaml.tpl` setup the netbox orb discovery agent (pointed at the enterprise VM & the above "router" VM), including a vault instance for a test/dummy "secret"
- `eks.tf` sets up a small EKS cluster running on spot instances
- `community-helm.sh` sets up netbox community using an external RDS db from `postgres.tf`
- `enterprise-helm.sh` and `enterprise-values.yaml` setup netbox enterprise on EKS
- `ansible.tf` and `ansible.sh.tpl` setup a vm for running ansible playbooks/runbooks.  `ansible-in.yaml` populates a netbox instance with some dummy/demo data
- `ad-ldap.tf` and `ad-ldap.ps1` setup a windows domain controller to act as an LDAP authentication source, which works with the example config in `ad-ldap-config.txt` placed in the Advanced Settings section of the Enterprise console
- `keycloak.tf` and `keyloak.sh` setup a keycloak server for SAML authentication, with a base/starter (that requires filling out a few things) in `saml-config.txt`  (note: you will also have to edit the redirect url in keycloak)
- `rhel.tf` and `ubuntu.tf` are just plain/bare standalone VMs for when I need to test specific-distro things
