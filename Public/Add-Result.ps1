
# Function to add results to the context
function Add-Result {
    param (
        [Parameter(Mandatory = $true)]
        $Context,
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        [string] $DeviceId,
        [Parameter(Mandatory = $true)]
        [string] $DeviceState,
        [Parameter(Mandatory = $true)]
        [bool] $HasPremiumLicense,
        [Parameter(Mandatory = $false)]
        [string]$OSVersion
    )

    try {
        $deviceName = $Item.DeviceDetail.DisplayName
        if ([string]::IsNullOrWhiteSpace($deviceName)) {
            $deviceName = "BYOD"
        }

        # Determine the compliance status
        $complianceStatus = if ($Item.DeviceDetail.IsCompliant) { "Compliant" } else { "Non-Compliant" }

        # Determine the user license
        $userLicense = if ($HasPremiumLicense) { "Microsoft 365 Business Premium" } else { "Other" }

        # Determine the sign-in status based on the error code
        $signInStatus = if ($Item.Status.ErrorCode -eq 0) { "Success" } else { "Failure" }

        # Create the result object directly
        $result = [PSCustomObject]@{
            DeviceName             = $deviceName
            UserName               = $Item.UserDisplayName
            DeviceEntraID          = $DeviceId
            UserEntraID            = $Item.UserId
            DeviceOS               = $Item.DeviceDetail.OperatingSystem
            OSVersion              = $osVersion
            DeviceComplianceStatus = $complianceStatus
            DeviceStateInIntune    = $DeviceState
            TrustType              = $Item.DeviceDetail.TrustType
            UserLicense            = $userLicense
            SignInStatus           = $signInStatus   # New property for Sign-In Status
            City                   = $Item.Location.City  # New property for City
            State                  = $Item.Location.State # New property for State
            CountryOrRegion        = $Item.Location.CountryOrRegion # New property for Country/Region
        }
        
        # Add the result to the context
        $Context.Results.Add($result)

        Write-EnhancedLog -Message "Successfully added result for device: $deviceName for user: $($Item.UserDisplayName) with status: $signInStatus" -Level "INFO"
    }
    catch {
        Handle-Error -ErrorRecord $_
        Write-EnhancedLog -Message "Failed to add result for device: $($Item.DeviceDetail.DisplayName)" -Level "ERROR"
    }
}

# # Example of how to use the functions
# $context = New-ProcessingContext
# $deviceDetail = New-DeviceDetail -DeviceId "device1" -DisplayName "Device One" -OperatingSystem "Windows 10" -IsCompliant $true -TrustType "AzureAD"
# $item = New-SignInLog -UserDisplayName "John Doe" -UserId "user1" -DeviceDetail $deviceDetail
# Add-Result -Context $context -Item $item -DeviceId "device1" -DeviceState "Active" -HasPremiumLicense $true