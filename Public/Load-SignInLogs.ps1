# function Load-SignInLogs {
#     param (
#         [Parameter(Mandatory = $true)]
#         [string]$JsonFilePath
#     )

#     $signInLogs = [System.Collections.Generic.List[PSCustomObject]]::new()
#     Write-EnhancedLog -Message "Opening file: $JsonFilePath" -Level 'INFO'
#     $fileStream = [System.IO.FileStream]::new($JsonFilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read, 4096, [System.IO.FileOptions]::SequentialScan)

#     try {
#         $jsonDoc = [System.Text.Json.JsonDocument]::Parse($fileStream)

#         foreach ($element in $jsonDoc.RootElement.EnumerateArray()) {
#             $deviceDetail = [PSCustomObject]@{
#                 DeviceId       = $element.GetProperty("deviceDetail").GetProperty("deviceId").GetString()
#                 DisplayName    = $element.GetProperty("deviceDetail").GetProperty("displayName").GetString()
#                 OperatingSystem = $element.GetProperty("deviceDetail").GetProperty("operatingSystem").GetString()
#                 IsCompliant    = $element.GetProperty("deviceDetail").GetProperty("isCompliant").GetBoolean()
#                 TrustType      = $element.GetProperty("deviceDetail").GetProperty("trustType").GetString()
#             }

#             $status = [PSCustomObject]@{
#                 ErrorCode         = $element.GetProperty("status").GetProperty("errorCode").GetInt32()
#                 FailureReason     = $element.GetProperty("status").GetProperty("failureReason").GetString()
#                 AdditionalDetails = $element.GetProperty("status").GetProperty("additionalDetails").GetString() #returns a get string error possibly due to some being null and some having special characters like like continuation
#             }

#             $location = [PSCustomObject]@{
#                 City            = $element.GetProperty("location").GetProperty("city").GetString()
#                 State           = $element.GetProperty("location").GetProperty("state").GetString()
#                 CountryOrRegion = $element.GetProperty("location").GetProperty("countryOrRegion").GetString()
#             }

#             $signInLog = [PSCustomObject]@{
#                 UserDisplayName = $element.GetProperty("userDisplayName").GetString()
#                 UserId          = $element.GetProperty("userId").GetString()
#                 DeviceDetail    = $deviceDetail
#                 Status          = $status  # Include the status object in the sign-in log
#                 Location        = $location # Include the location object in the sign-in log
#             }

#             $signInLogs.Add($signInLog)
#         }

#         Write-EnhancedLog -Message "Sign-in logs loaded successfully from $JsonFilePath." -Level "INFO"
#     } catch {
#         Handle-Error -ErrorRecord $_
#     } finally {
#         $fileStream.Dispose()
#     }

#     return $signInLogs
# }


function Load-SignInLogs {
    param (
        [string]$JsonFilePath
    )

    $signInLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

    try {
        $jsonContent = Get-Content -Path $JsonFilePath -Raw | ConvertFrom-Json

        foreach ($entry in $jsonContent) {
            $signInLogs.Add([PSCustomObject]@{
                UserDisplayName = $entry.userDisplayName
                UserId          = $entry.userId
                DeviceDetail    = $entry.deviceDetail
                Status          = $entry.status
                Location        = $entry.location
            })
        }

        Write-Host "Sign-in logs loaded successfully from $JsonFilePath."
    } catch {
        Write-Host "An error occurred: $_"
    }

    return $signInLogs.ToArray()
}
