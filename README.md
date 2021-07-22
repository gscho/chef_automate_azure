# Chef Automate (Standalone) Running in Azure

The most basic way to deploy a Chef Automate Server along with a Chef Infra Server in Azure. It is purposley under-engineered so you can get started quickly and not fuss with terraform variables or modules.

## Usage

Modify chef-automate.tfvars to set your own values

```
# chef-automate.tfvars
location = "East US"
tags = {
  x-environment = "test",
  x-owner       = "gregory.schofield@progress.com"
}
```

Execute terraform apply

    $ terraform apply -var-file=chef-automate.tfvars

View the private key so you can SSH into the server

    $ terraform output chef_automate_private_key
