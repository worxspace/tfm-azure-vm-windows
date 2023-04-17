resource "azurecaf_name" "name" {
  resource_types = [
    "azurerm_windows_virtual_machine",
    "azurerm_network_interface"
  ]
  name     = var.project-name
  prefixes = var.resource-prefixes
}

resource "azurerm_network_interface" "nic" {
  name                = azurecaf_name.name.results.azurerm_network_interface
  location            = var.location
  resource_group_name = var.resource-group-name

  dynamic "ip_configuration" {
    for_each = [ var.ip-address == null ? null : var.ip-address ]
    
    content {
      name                          = "internal"
      subnet_id                     = var.subnet-id
      private_ip_address_allocation = "Static"
      private_ip_address            = ip_configuration.value
    }
  }

  dynamic "ip_configuration" {
    for_each = [ var.ip-address == null ? null : var.ip-address ]
    
    content {
      name                          = "internal"
      subnet_id                     = var.subnet-id
      private_ip_address_allocation = "Dynamic"
    }
  }
}

resource "random_password" "password" {
  length  = 24
  special = true
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = azurecaf_name.name.results.azurerm_windows_virtual_machine
  resource_group_name = var.resource-group-name
  location            = var.location
  size                = var.vm-size
  admin_username      = "adminuser"
  admin_password      = random_password.password.result
  network_interface_ids = [
    azurerm_network_interface.nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.image-publisher
    offer     = var.image-offer
    sku       = var.image-sku
    version   = var.image-version
  }

  secure_boot_enabled = var.support-hvic
  vtpm_enabled        = var.support-hvic
  
  patch_assessment_mode = var.update-management-integration ? "AutomaticByPlatform" : "ImageDefault"
  patch_mode            = var.update-management-integration ? "AutomaticByPlatform" : "Manual"
}

resource "azurerm_managed_disk" "disk" {
  for_each = var.data-disks == null ? {} : { for disk in var.data-disks : disk.name => disk }

  name                 = "${azurecaf_name.name.results.azurerm_windows_virtual_machine}_${each.key}"
  location             = var.location
  resource_group_name  = var.resource-group-name
  storage_account_type = each.value.storage-type
  tier                 = each.value.tier
  create_option        = "Empty"
  disk_size_gb         = each.value.size-gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk-attachment" {
  for_each = azurerm_managed_disk.disk

  managed_disk_id    = each.value.id
  virtual_machine_id = azurerm_windows_virtual_machine.vm.id
  lun                = "10"
  caching            = "None"
}