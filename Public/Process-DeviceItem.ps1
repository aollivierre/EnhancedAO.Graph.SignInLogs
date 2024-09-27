function Process-DeviceItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Item,
        [Parameter(Mandatory = $true)]
        $Context,
        [Parameter(Mandatory = $true)]
        $Headers
    )

    Begin {
        Write-EnhancedLog -Message "Starting Process-DeviceItem function" -Level "INFO"
        Log-Params -Params @{ Item = $Item; Context = $Context }
        Initialize-Context -Context $Context
    }

    Process {
        # Ensure ErrorCode is properly accessed
        $errorCode = $Item.Status.ErrorCode
        $failureReason = $Item.Status.FailureReason

        # Wait-Debugger

        if ($null -eq $errorCode) {
            Write-EnhancedLog -Message "Missing ErrorCode in the sign-in log for user $($Item.userDisplayName). Skipping this item." -Level "WARNING"
            return
        }

        # Check if sign-in was successful
        if ($errorCode -ne 0) {
            Write-EnhancedLog -Message "Sign-in attempt failed for user $($Item.userDisplayName) with ErrorCode: $errorCode - $failureReason" -Level "WARNING"
            return
        }

        # Ensure deviceDetail object and properties exist
        if (-not $Item.deviceDetail) {
            Write-EnhancedLog -Message "Missing deviceDetail for user: $($Item.userDisplayName)" -Level "WARNING"
            return
        }

        $deviceId = $Item.deviceDetail.deviceId
        $userId = $Item.userId
        $os = $Item.deviceDetail.operatingSystem

        if (-not $userId) {
            Write-EnhancedLog -Message "Missing userId for device item" -Level "WARNING"
            return
        }

        try {
            # Construct uniqueId based on availability of deviceId and OS for BYOD
            if ([string]::IsNullOrWhiteSpace($deviceId)) {
                $uniqueId = "$userId-$os".ToLowerInvariant()
            }
            else {
                $uniqueId = $deviceId.ToLowerInvariant()
            }

            # Log the device and user information
            Write-EnhancedLog -Message "Processing device item for user: $($Item.userDisplayName) with unique ID: $uniqueId" -Level "INFO"

            # Handle external Azure AD tenant case
            if (Handle-ExternalAADTenant -Item $Item -Context $Context -UniqueId $uniqueId) {
                return
            }

            # Process only if the unique ID is not already processed
            if ($Context.UniqueDeviceIds.Add($uniqueId)) {
                # Handle BYOD case
                if ([string]::IsNullOrWhiteSpace($deviceId)) {
                    # Fetch user licenses with retry logic
                    $userLicenses = Fetch-UserLicensesWithRetry -UserId $userId -Username $Item.userDisplayName -Headers $Headers
                    $hasPremiumLicense = $userLicenses -and $userLicenses.Count -gt 0 -and $userLicenses.Contains("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46")
                    Write-EnhancedLog -Message "User $($Item.userDisplayName) has the following licenses: $($userLicenses -join ', ')" -Level "INFO"

                    Add-Result -Context $Context -Item $Item -DeviceId "N/A" -DeviceState "BYOD" -HasPremiumLicense $hasPremiumLicense -OSVersion $null
                    return
                }

                # Handle managed device case with retry logic
                $deviceState = Fetch-DeviceStateWithRetry -DeviceId $deviceId -Username $Item.userDisplayName -Headers $Headers
                $osVersion = Fetch-OSVersionWithRetry -DeviceId $deviceId -Headers $Headers

                $userLicenses = Fetch-UserLicensesWithRetry -UserId $userId -Username $Item.userDisplayName -Headers $Headers
                $hasPremiumLicense = $userLicenses -and $userLicenses.Count -gt 0 -and $userLicenses.Contains("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46")
                Write-EnhancedLog -Message "User $($Item.userDisplayName) has the following licenses: $($userLicenses -join ', ')" -Level "INFO"

                Add-Result -Context $Context -Item $Item -DeviceId $deviceId -DeviceState $deviceState -HasPremiumLicense $hasPremiumLicense -OSVersion $osVersion
            }
            else {
                Write-EnhancedLog -Message "Device ID $uniqueId for user $($Item.userDisplayName) has already been processed and will be skipped." -Level "WARNING"
            }
        }
        catch {
            Write-EnhancedLog -Message "An error occurred while processing the device item for user: $($Item.userDisplayName) - $_" -Level "ERROR"
            Handle-Error -ErrorRecord $_
        }
    }

    End {
        Write-EnhancedLog -Message "Exiting Process-DeviceItem function" -Level "INFO"
    }
}


#v2 with parallel processing

# function Process-DeviceItem {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory = $true)]
#         $Item,
#         [Parameter(Mandatory = $true)]
#         $Headers
#     )

 

#     Begin {
#         Write-EnhancedLog -Message "Starting Process-DeviceItem function" -Level "INFO"
#         Log-Params -Params @{ Item = $Item }

#         # Local context-like structure
#         $result = $null
#     }

#     Process {
#         $errorCode = $Item.Status.ErrorCode
#         $failureReason = $Item.Status.FailureReason

#         if ($null -eq $errorCode) {
#             Write-EnhancedLog -Message "Missing ErrorCode in the sign-in log for user $($Item.userDisplayName). Skipping this item." -Level "WARNING"
#             return
#         }

#         if ($errorCode -ne 0) {
#             Write-EnhancedLog -Message "Sign-in attempt failed for user $($Item.userDisplayName) with ErrorCode: $errorCode - $failureReason" -Level "WARNING"
#             return
#         }

#         $deviceId = $Item.deviceDetail.deviceId
#         $userId = $Item.userId
#         $os = $Item.deviceDetail.operatingSystem

#         if (-not $userId) {
#             Write-EnhancedLog -Message "Missing userId for device item" -Level "WARNING"
#             return
#         }

#         try {
#             if ([string]::IsNullOrWhiteSpace($deviceId)) {
#                 $uniqueId = "$userId-$os".ToLowerInvariant()
#             }
#             else {
#                 $uniqueId = $deviceId.ToLowerInvariant()
#             }

#             Write-EnhancedLog -Message "Processing device item for user: $($Item.userDisplayName) with unique ID: $uniqueId" -Level "INFO"

#             # Fetch user licenses with retry logic
#             $userLicenses = Fetch-UserLicensesWithRetry -UserId $userId -Username $Item.userDisplayName -Headers $Headers
#             $hasPremiumLicense = $userLicenses -and $userLicenses.Count -gt 0 -and $userLicenses.Contains("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46")
#             Write-EnhancedLog -Message "User $($Item.userDisplayName) has the following licenses: $($userLicenses -join ', ')" -Level "INFO"

#             $deviceState = Fetch-DeviceStateWithRetry -DeviceId $deviceId -Username $Item.userDisplayName -Headers $Headers
#             $osVersion = Fetch-OSVersionWithRetry -DeviceId $deviceId -Headers $Headers

#             # Create a local result object
#             $result = [PSCustomObject]@{
#                 DeviceName             = $Item.DeviceDetail.DisplayName
#                 UserName               = $Item.UserDisplayName
#                 DeviceEntraID          = $deviceId
#                 UserEntraID            = $userId
#                 DeviceOS               = $Item.DeviceDetail.OperatingSystem
#                 OSVersion              = $osVersion
#                 DeviceComplianceStatus = if ($Item.DeviceDetail.IsCompliant) { "Compliant" } else { "Non-Compliant" }
#                 DeviceStateInIntune    = $deviceState
#                 TrustType              = $Item.DeviceDetail.TrustType
#                 UserLicense            = if ($hasPremiumLicense) { "Microsoft 365 Business Premium" } else { "Other" }
#                 SignInStatus           = "Success"
#             }

#             Write-EnhancedLog -Message "Successfully processed device item for user: $($Item.userDisplayName)" -Level "INFO"
#         }
#         catch {
#             Write-EnhancedLog -Message "An error occurred while processing the device item for user: $($Item.userDisplayName) - $_" -Level "ERROR"
#             Handle-Error -ErrorRecord $_
#         }
#     }

#     End {
#         Write-EnhancedLog -Message "Exiting Process-DeviceItem function" -Level "INFO"
#         return $result
#     }
# }




# # Global log queue
# $global:LogQueue = [System.Collections.Concurrent.ConcurrentQueue[System.String]]::new()

# # Start background job for async logging
# $global:LogJob = Start-Job -ScriptBlock {
#     param ($logQueue)

#     while ($true) {
#         if ($logQueue.TryDequeue([ref]$logMessage)) {
#             # Example of writing to a file, you can modify this to fit your logging method
#             Add-Content -Path "logfile.txt" -Value $logMessage
#         } else {
#             Start-Sleep -Milliseconds 100
#         }
#     }
# } -ArgumentList $global:LogQueue




# function Write-AsyncLog {
#     param (
#         [string]$Message,
#         [string]$Level = "INFO",
#         [switch]$WriteToConsole = $true  # Add a parameter to control console output
#     )

#     $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
#     $logMessage = "[$timestamp][$Level] $Message"

#     # Enqueue the log message for asynchronous file logging
#     $global:LogQueue.Enqueue($logMessage)

#     # Optionally write the log message to the console
#     if ($WriteToConsole) {
#         Write-Host $logMessage
#     }
# }




# function Process-DeviceItem {
#     [CmdletBinding()]
#     param (
#         [Parameter(Mandatory = $true)]
#         $Item,
#         [Parameter(Mandatory = $true)]
#         $Context,
#         [Parameter(Mandatory = $true)]
#         $Headers
#     )

#     Begin {
#         Write-AsyncLog -Message "Starting Process-DeviceItem function" -Level "INFO"
#         Log-Params -Params @{ Item = $Item; Context = $Context }
#         Initialize-Context -Context $Context
#     }

#     Process {
#         $errorCode = $Item.Status.ErrorCode
#         $failureReason = $Item.Status.FailureReason

#         if ($null -eq $errorCode) {
#             Write-AsyncLog -Message "Missing ErrorCode in the sign-in log for user $($Item.userDisplayName). Skipping this item." -Level "WARNING"
#             return
#         }

#         if ($errorCode -ne 0) {
#             Write-AsyncLog -Message "Sign-in attempt failed for user $($Item.userDisplayName) with ErrorCode: $errorCode - $failureReason" -Level "WARNING"
#             return
#         }

#         if (-not $Item.deviceDetail) {
#             Write-AsyncLog -Message "Missing deviceDetail for user: $($Item.userDisplayName)" -Level "WARNING"
#             return
#         }

#         $deviceId = $Item.deviceDetail.deviceId
#         $userId = $Item.userId
#         $os = $Item.deviceDetail.operatingSystem

#         if (-not $userId) {
#             Write-AsyncLog -Message "Missing userId for device item" -Level "WARNING"
#             return
#         }

#         try {
#             $uniqueId = if ([string]::IsNullOrWhiteSpace($deviceId)) { 
#                 "$userId-$os".ToLowerInvariant()
#             } else {
#                 $deviceId.ToLowerInvariant()
#             }

#             Write-AsyncLog -Message "Processing device item for user: $($Item.userDisplayName) with unique ID: $uniqueId" -Level "INFO"

#             if (Handle-ExternalAADTenant -Item $Item -Context $Context -UniqueId $uniqueId) {
#                 return
#             }

#             if ($Context.UniqueDeviceIds.Add($uniqueId)) {
#                 if ([string]::IsNullOrWhiteSpace($deviceId)) {
#                     $userLicenses = Fetch-UserLicensesWithRetry -UserId $userId -Username $Item.userDisplayName -Headers $Headers
#                     $hasPremiumLicense = $userLicenses -and $userLicenses.Count -gt 0 -and $userLicenses.Contains("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46")
#                     Write-AsyncLog -Message "User $($Item.userDisplayName) has the following licenses: $($userLicenses -join ', ')" -Level "INFO"

#                     Add-Result -Context $Context -Item $Item -DeviceId "N/A" -DeviceState "BYOD" -HasPremiumLicense $hasPremiumLicense -OSVersion $null
#                     return
#                 }

#                 $deviceState = Fetch-DeviceStateWithRetry -DeviceId $deviceId -Username $Item.userDisplayName -Headers $Headers
#                 $osVersion = Fetch-OSVersionWithRetry -DeviceId $deviceId -Headers $Headers

#                 $userLicenses = Fetch-UserLicensesWithRetry -UserId $userId -Username $Item.userDisplayName -Headers $Headers
#                 $hasPremiumLicense = $userLicenses -and $userLicenses.Count -gt 0 -and $userLicenses.Contains("cbdc14ab-d96c-4c30-b9f4-6ada7cdc1d46")
#                 Write-AsyncLog -Message "User $($Item.userDisplayName) has the following licenses: $($userLicenses -join ', ')" -Level "INFO"

#                 Add-Result -Context $Context -Item $Item -DeviceId $deviceId -DeviceState $deviceState -HasPremiumLicense $hasPremiumLicense -OSVersion $osVersion
#             }
#             else {
#                 Write-AsyncLog -Message "Device ID $uniqueId for user $($Item.userDisplayName) has already been processed and will be skipped." -Level "WARNING"
#             }
#         }
#         catch {
#             Write-AsyncLog -Message "An error occurred while processing the device item for user: $($Item.userDisplayName) - $_" -Level "ERROR"
#             Handle-Error -ErrorRecord $_
#         }
#     }

#     End {
#         Write-AsyncLog -Message "Exiting Process-DeviceItem function" -Level "INFO"
#     }
# }

