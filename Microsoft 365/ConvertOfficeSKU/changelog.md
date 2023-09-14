# Convert-OfficeSKU

Convert Office SKU IDs to friendly names based on the Microsoft License Service Plan Reference.

## Version 0.0.1

- **Used Microsoft Docs**: # Product names and service plan identifiers for licensing: Article - 08/14/2023

## How to use

```powershell
#List all results
Convert-OfficeSku -All

#Convert Sku using Account Sku ID
Convert-OfficeSku -AccountSkuID SPE_E3,SPE_E5

#Convert Sku using Product Name
Convert-OfficeSku -ProductName 'Microsoft 365 E3','Microsoft 365 E5'

#Convert Sku using GUID
Convert-OfficeSku -Guid 05e9a617-0261-4cee-bb44-138d3ef5d965
