<#
.SYNOPSIS
Creates a new Azure API for FHIR Server environment.
.DESCRIPTION
#>
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(6,20)]
    [ValidateScript({
        if ("$_" -Like "* *") {
            throw "Azure API for FHIR resource name cannot contain whitespace"
            return $false
        }
        else {
            return $true
        }
    })]
    [string]$ResourceName,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$FhirApiLocation = "westus2",

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stu3','R4')]
    [string]$FhirVersion = "R4"
)

Set-StrictMode -Version Latest

# Get current AzureAd context
try {
    $tenantInfo = Get-AzureADCurrentSessionInfo -ErrorAction Stop
} 
catch {
    throw "Please log in to Azure AD with Connect-AzureAD cmdlet before proceeding"
}


# Get current Az context
try {
    $azContext = Get-AzContext
} 
catch {
    throw "Please log in to Azure RM with Login-AzAccount cmdlet before proceeding"
}

if ($azContext.Account.Type -eq "User") {
    Write-Host "Current context is user: $($azContext.Account.Id)"
    $currentUser = Get-AzADUser -UserPrincipalName $azContext.Account.Id

    if (!$currentUser) {
        # For some reason $azContext.Account.Id will sometimes be the email of the user instead of the UPN, we need the UPN
        # Selecting the same subscription with the same tenant (twice), brings us back to the UPN
        Select-AzSubscription -SubscriptionId $azContext.Subscription.Id -TenantId $azContext.Tenant.Id | Out-Null
        Select-AzSubscription -SubscriptionId $azContext.Subscription.Id -TenantId $azContext.Tenant.Id | Out-Null
        $azContext = Get-AzContext
        Write-Host "Current context is user: $($azContext.Account.Id)"
        $currentUser = Get-AzADUser -UserPrincipalName $azContext.Account.Id    
    }

    #If this is guest account, we will try a search instead
    if (!$currentUser) {
        # External user accounts have UserPrincipalNames of the form:
        # myuser_outlook.com#EXT#@mytenant.onmicrosoft.com for a user with username myuser@outlook.com
        $tmpUserName = $azContext.Account.Id.Replace("@", "_")
        $currentUser = Get-AzureADUser -Filter "startswith(UserPrincipalName, '${tmpUserName}')"
        $currentObjectId = $currentUser.ObjectId
    } else {
        $currentObjectId = $currentUser.Id
    }

    if (!$currentObjectId) {
        throw "Failed to find objectId for signed in user"
    }
}
elseif ($azContext.Account.Type -eq "ServicePrincipal") {
    Write-Host "Current context is service principal: $($azContext.Account.Id)"
    $currentObjectId = (Get-AzADServicePrincipal -ServicePrincipalName $azContext.Account.Id).Id
}
else {
    Write-Host "Current context is account of type '$($azContext.Account.Type)' with id of '$($azContext.Account.Id)"
    throw "Running as an unsupported account type. Please use either a 'User' or 'Service Principal' to run this command"
}


# Set up Auth Configuration and Resource Group
$authresults = ./Create-AzureApiForPhirAuthSetUp.ps1 -ResourceName $ResourceName 

#Template URLs
$fhirServerTemplateUrl = "https://raw.githubusercontent.com/microsoft/fhir-server/master/samples/templates/default-azuredeploy.json"

$sandboxTemplate = "azuredeploy-fhirapi.json"

$tenantDomain = $tenantInfo.TenantDomain
$aadAuthority = "https://login.microsoftonline.com/${tenantDomain}"

$fhirServerUrl = "https://${ResourceName}.azurehealthcareapis.com"

$serviceClientId = $authresults.clientId
$serviceClientSecret = $authresults.clientSecret
$serviceClientObjectId = (Get-AzureADServicePrincipal -Filter "AppId eq '$serviceClientId'").ObjectId

$accessPolicies = @()
$accessPolicies += @{ "objectId" = $currentObjectId.ToString() }
$accessPolicies += @{ "objectId" = $serviceClientObjectId.ToString() }

$resourceGroupObj = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (!$resourceGroupObj) {
    New-AzResourceGroup -Name $ResourceGroup -Location $FhirApiLocation | Out-Null
}

# Deploy the template
New-AzResourceGroupDeployment -TemplateFile $sandboxTemplate -resourceName $ResourceName -fhirApiLocation $FhirApiLocation -ResourceGroupName $ResourceGroup  -fhirVersion $FhirVersion -aadAuthority $aadAuthority  -accessPolicies $accessPolicies

Write-Host "Warming up site..."
Invoke-WebRequest -Uri "${fhirServerUrl}/metadata" | Out-Null

$resultObj = @{
    fhirServerUrl = $fhirServerUrl
    clientId = $serviceClientId
    clientSecret = $serviceClientSecret
    accessTokenUrl = "https://login.microsoftonline.com/" + $tenantInfo.TenantId + "/oauth2/v2.0/token"
    scope =  $fhirServerUrl + "/.default"
}

Out-File -FilePath fhirapidetails.txt -InputObject $resultObj

@{
    fhirServerUrl = $fhirServerUrl
    clientId = $serviceClientId
    clientSecret = $serviceClientSecret
    accessTokenUrl = "https://login.microsoftonline.com/" + $tenantInfo.TenantId + "/oauth2/v2.0/token"
    scope =  $fhirServerUrl + "/.default"
}

