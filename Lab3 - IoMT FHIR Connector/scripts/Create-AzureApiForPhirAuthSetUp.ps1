<#
.SYNOPSIS
Adds the required application registrations and user profiles to an AAD tenant
.DESCRIPTION
#>
param
(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(6,20)]
    [ValidateScript({
        Write-Host $_
        if ("$_" -Like "* *") {
            throw "Resource name cannot contain whitespace"
            return $false
        }
        else {
            return $true
        }
    })]
    [string]$ResourceName
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

# Ensure that we have the FhirServer PS Module loaded
if (Get-Module -Name FhirServer) {
    Write-Host "FhirServer PS module is loaded"
} else {
    Write-Host "Cloning FHIR Server repo to get access to FhirServer PS module."
    if (!(Test-Path -Path ".\fhir-server")) {
        git clone --quiet https://github.com/Microsoft/fhir-server | Out-Null
    }
    Import-Module .\fhir-server\samples\scripts\PowerShell\FhirServer\FhirServer.psd1
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

Write-Host "Ensuring API application exists"

$fhirServiceUrl = "https://${ResourceName}.azurehealthcareapis.com"

$application = Get-AzureAdApplication -Filter "identifierUris/any(uri:uri eq '$fhirServiceUrl')"

if (!$application) {
    $newApplication = New-FhirServerApiApplicationRegistration -FhirServiceAudience $fhirServiceUrl -AppRoles "globalAdmin"
    
    # Change to use applicationId returned
    $application = Get-AzureAdApplication -Filter "identifierUris/any(uri:uri eq '$fhirServiceUrl')"
}

# Create service client
$serviceClientAppName = "${ResourceName}-service-client"
$serviceClient = Get-AzureAdApplication -Filter "DisplayName eq '$serviceClientAppName'"
if (!$serviceClient) {
    $serviceClient = New-FhirServerClientApplicationRegistration -ApiAppId $application.AppId -DisplayName $serviceClientAppName
    $secretSecureString = ConvertTo-SecureString $serviceClient.AppSecret -AsPlainText -Force
    $clientSecretValue = $serviceClient.AppSecret
} else {
    $existingPassword = Get-AzureADApplicationPasswordCredential -ObjectId $serviceClient.ObjectId | Remove-AzureADApplicationPasswordCredential -ObjectId $serviceClient.ObjectId
    $newPassword = New-AzureADApplicationPasswordCredential -ObjectId $serviceClient.ObjectId
    $secretSecureString = ConvertTo-SecureString $newPassword.Value -AsPlainText -Force
    $clientSecretValue = $newPassword.Value
}

Set-FhirServerClientAppRoleAssignments -AppId $serviceClient.AppId -ApiAppId $application.AppId -AppRoles "globalAdmin"

$secretServiceClientId = ConvertTo-SecureString $serviceClient.AppId -AsPlainText -Force


@{
    fhirServerUrl = $fhirServiceUrl
    clientId = $serviceClient.AppId
    clientSecret = $clientSecretValue
    accessTokenUrl = "https://login.microsoftonline.com/" + $tenantInfo.TenantId + "/oauth2/v2.0/token"
    scope =  $fhirServiceUrl + "/.default"
}
