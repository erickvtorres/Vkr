# Get-LoggedUser!

This module is very simple, made to help to convert result from quser.exe to PowerShell object.

## Version 0.0.2

-  Add default **defaultDisplayPropertySet**, to display all properties, must include the properties or Format-Table *
- Add the **ComputerName** property

## Version 0.0.1

- Converts quser.exe to PowerShell object
- Get computer objects from OU or Domain Controllers to display logged users

## How to use

```powershell
#Get logged users from localhost
Get-LoggedUser

#Get logged users from remote computers
Get-LoggedUser -ComputerName

#Get logged users from all computers available from OU
Get-ADLoggedUser -OU 'OU=Servers,DC=vkr,DC=inc'

#Get logged users from all Domain Controllers
Get-ADLoggedUser -DomainControllers

```

> Get-ADLoggedUser requires ActiveDirectory module.
