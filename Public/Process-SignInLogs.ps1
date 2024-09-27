function Process-SignInLogs {
    param (
        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[PSCustomObject]]$signInLogs,
        [Parameter(Mandatory = $true)]
        [hashtable]$Headers
    )

    # Ensure the signInLogs variable is not null before using it
    if ($null -eq $signInLogs -or @($signInLogs).Count -eq 0) {
        Write-Warning "No sign-in logs were loaded."
        exit 1
    }
    else {
        Write-Host "Loaded $(@($signInLogs).Count) sign-in logs."
    }

    # Debugging: Print the first sign-in log entry
    if ($signInLogs.Count -gt 0) {
        $firstSignInLog = $signInLogs[0]
        
        # Determine the sign-in status based on the ErrorCode
        $signInStatus = if ($firstSignInLog.Status.ErrorCode -eq 0) { "Success" } else { "Failure" }
    
        Write-Host "First sign-in log entry:"
        Write-Host "UserDisplayName: $($firstSignInLog.UserDisplayName)"
        Write-Host "UserId: $($firstSignInLog.UserId)"
        Write-Host "SignInStatus: $signInStatus"  # Print the sign-in status
        Write-Host "DeviceDetail:"
        Write-Host "  DeviceId: $($firstSignInLog.DeviceDetail.DeviceId)"
        Write-Host "  DisplayName: $($firstSignInLog.DeviceDetail.DisplayName)"
        Write-Host "  OperatingSystem: $($firstSignInLog.DeviceDetail.OperatingSystem)"
        Write-Host "  IsCompliant: $($firstSignInLog.DeviceDetail.IsCompliant)"
        Write-Host "  TrustType: $($firstSignInLog.DeviceDetail.TrustType)"
    }
    

    $context = New-ProcessingContext

    # Process each log item directly
    foreach ($log in $signInLogs) {
        # Exclude "On-Premises Directory Synchronization Service Account" user
        if ($log.UserDisplayName -ne "On-Premises Directory Synchronization Service Account" -and $null -ne $log) {
            try {
                Process-DeviceItem -Item $log -Context $context -Headers $Headers
                # Process-DeviceItem -Item $log -Headers $Headers
            }
            catch {
                Write-Error "Error processing item: $($_.Exception.Message)"
                Handle-Error -ErrorRecord $_
            }
        }
    }


    # Stop the logging job when done
    Stop-Job -Job $global:LogJob
    Remove-Job -Job $global:LogJob





    # $jobs = @()

    # foreach ($log in $signInLogs) {
    #     # Exclude "On-Premises Directory Synchronization Service Account" user
    #     if ($log.UserDisplayName -ne "On-Premises Directory Synchronization Service Account" -and $null -ne $log) {
    #         $jobs += Start-Job -ScriptBlock {
    #             param ($log, $context, $headers)
            
    #             try {
    #                 Process-DeviceItem -Item $log -Context $context -Headers $headers
    #             }
    #             catch {
    #                 Write-Error "Error processing item: $($_.Exception.Message)"
    #                 Handle-Error -ErrorRecord $_
    #             }
    #         } -ArgumentList $log, $context, $Headers
    #     }
    # }

    # # Wait for all jobs to complete
    # $jobs | ForEach-Object {
    #     $_ | Wait-Job
    # }

    # # Retrieve job results
    # $jobs | ForEach-Object {
    #     Receive-Job -Job $_
    #     Remove-Job -Job $_
    # }





    # $signInLogs | ForEach-Object -Parallel {
    #     param (
    #         $log,
    #         $context,
    #         $headers
    #     )
    
    #     # Exclude "On-Premises Directory Synchronization Service Account" user
    #     if ($log.UserDisplayName -ne "On-Premises Directory Synchronization Service Account" -and $null -ne $log) {
    #         try {
    #             Process-DeviceItem -Item $log -Context $context -Headers $headers
    #         }
    #         catch {
    #             Write-Error "Error processing item: $($_.Exception.Message)"
    #             Handle-Error -ErrorRecord $_
    #         }
    #     }
    # } -ArgumentList $_, $using:context, $using:headers -ThrottleLimit 10
    


    # Remove null entries from the results list
    $context.Results = $context.Results | Where-Object { $_ -ne $null }

    # Return the results
    return $context.Results
}