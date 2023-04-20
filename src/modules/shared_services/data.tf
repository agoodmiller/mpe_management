# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

data "terraform_remote_state" "landing_zone" {
  backend = "azurerm"

  config = {
    storage_account_name = var.state_sa_name
    container_name       = var.state_sa_container_name
    key                  = "ampe"
    resource_group_name  = var.state_sa_rg
  }
}

data "azurerm_subnet" "svcs_subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.terraform_remote_state.landing_zone.outputs.svcs_virtual_network_name
  resource_group_name  = data.terraform_remote_state.landing_zone.outputs.svcs_resource_group_name
}

data "azuread_group" "admin_group" {
  display_name = var.admin_group_name
}