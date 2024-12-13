<#
.SYNOPSIS
Script to check the status of Connection Servers, the use of desktop pools and the number of concurrent connections to Horizon VDI
Using Horizon REST API
	
.NOTES
  Version:        1.0
  Author:         Ricardo Barbarin - info@rbisysadmin.com
  Creation Date:  2024/12/13

 #>

# Configuration
$Domain = "rbilab.local" # change with your domain name
$Username = Read-Host -Prompt 'Enter the Username: '
$Password = Read-Host -Prompt 'Enter the Password: '# -AsSecureString
$prolab = Read-Host -Prompt 'Indicate an environment (PRO or LAB): '

if ($prolab -eq "PRO"){
    $HorizonServer = "https://connectionserver.rbilab.local" # change with your Horizon Connection Server URL
    }
elseif ($prolab -eq "LAB"){
    $HorizonServer = "https://labconnectionserver.rbilab.local" # change with your Horizon Connection Server URL
    }
else{
    Write-Output "You have to indicate an environment"
    break
}

# Function to get the authentication token
function Get-AuthToken {
    $url = "$HorizonServer/rest/login"
    $body = @{ username = $Username; password = $Password; domain = $Domain } | ConvertTo-Json
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Method Post -Body $body -ContentType "application/json"
    # use (-SkipCertificateCheck) to avoid errors with self-signed certificates
    return $response.access_token
}

# Function to obtain the status of the Connection Servers
function Get-ConnectionServersStatus {
    param ($Token)
    $url = "$HorizonServer/rest/monitor/v2/connection-servers"
    $headers = @{ Authorization = "Bearer $Token" }
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Headers $headers -Method Get
    foreach ($server in $response) {
        Write-Output "Connection Server: $($server.name), Status: $($server.status)"
    }
}

# Function to obtain the status of the pools
function Get-PoolsStatus {
    param ($Token)
    $url = "$HorizonServer/rest/inventory/v1/desktop-pools"
    $headers = @{ Authorization = "Bearer $Token" }
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Headers $headers -Method Get
    foreach ($pool in $response) {
        $url2 = "$HorizonServer/rest//monitor/v1/desktop-pools/metrics?ids=$($pool.id)"
        $headers2 = @{ Authorization = "Bearer $Token" }
        $response2 = Invoke-RestMethod -SkipCertificateCheck -Uri $url2 -Headers $headers2 -Method Get
        Write-Output "Pool: $($pool.name), Desks available: $($response2.num_machines), Assigned: $($response2.occupancy_count), In use: $($response2.num_connected_sessions)"
    }
}

# Function to obtain license status
function Get-LicensesStatus {
    param ($Token)
    $url = "$HorizonServer/rest/monitor/v1/licenses/usage-metrics"
    $headers = @{ Authorization = "Bearer $Token" }
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Headers $headers -Method Get
    Write-Output "Current connections: $($response.current_usage.total_concurrent_sessions)"
    Write-Output "Maximum connections: $($response.highest_usage.total_concurrent_sessions)"
    $url = "$HorizonServer/rest/config/v2/licenses"
    $headers = @{ Authorization = "Bearer $Token" }
    $response = Invoke-RestMethod -SkipCertificateCheck -Uri $url -Headers $headers -Method Get
    Write-Output "License type: $($response.license_edition)"
}

# Script start
$Token = Get-AuthToken
Write-Output "Connection Server Status:"
Get-ConnectionServersStatus -Token $Token
Write-Output "Pool Status:"
Get-PoolsStatus -Token $Token
Write-Output "Use of Licenses:"
Get-LicensesStatus -Token $Token
