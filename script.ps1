# 1. Load the JSON, date and show domain-name + try catch

try {
    $data = Get-Content -Path "ad_export.json" -Raw -Encoding UTF8 | ConvertFrom-Json
}
catch {
    Write-Error "X Error: Could not read 'ad_export.Json'. $_"
    exit 1 #Exit script
}

$today = Get-Date
$summary = ""
$report = ""
$finalReport = ""

$report = @"
                           AD_AUDIT REPORT
---------------------------------------------------------------------------
Domain: $($data.domain)
Forest: $($data.forest)
Export-date: $($data.export_date)
Created: $(Get-Date)
---------------------------------------------------------------------------`n
"@

#-----------------------------------
# Function to get inactive accounts TASK 9 | This function is added in task 7 password ages
#-----------------------------------

function Get-InactiveAccounts {
    param(
        [Parameter(Mandatory = $true)]
        [int]$days
    )
    $today = Get-Date
    $inactive = $data.users | Where-Object {
        $_.lastLogon -and ($today - [datetime]$_.lastLogon).Days -gt $days
    }
    $inactiveWithDays = $inactive | Select-Object displayName, department, lastLogon, @{
        Name       = 'Daysinactive'
        Expression = { ($today - [datetime]$_.lastLogon).Days }
    } | Sort-Object -Property Daysinactive -Descending

    return $inactiveWithDays
}


# 3. List inactive users that have not been online for more than 30 days
$inactive30 = Get-InactiveAccounts -days 30

$report += "Inactive Users (30+ days)`n`n"
foreach ($u in $inactive30) {
    $report += "{0,-20} {1,-15} {2,-35} {3}`n" -f $u.displayName, $u.department, "Last logon: $($u.lastLogon)", "($($u.DaysInactive) days)"
}
$report += "---------------------------------------------------------------------------`n`n"
#4 Count all users in each department

$depCount = @{}

#Loop through all users
foreach ($u in $data.users) {
    $dept = $u.department
    if ($dept) {
        if ($depCount.ContainsKey($dept)) {
            $depCount[$dept] += 1
        }
        else {
            $depCount[$dept] = 1

        }
    }
}

$report += "User count per department `n`n"
foreach ($dept in $depCount.Keys) {
    $report += "{0,-10} {1}`n" -f $dept, $depCount[$dept]
    
}

$report += "---------------------------------------------------------------------------`n`n"

# 5. Group computers per site
$report += "Computers per site `n`n"

$computersbysite = $data.computers | Group-Object -Property site

foreach ($group in $computersbysite) {
    $report += "{0,-14} {1,-10} {2}`n" -f $group.Name, $group.Count, ""
}
$report += "---------------------------------------------------------------------------`n`n"

# 6. Export inactive users to CSV + try/catch 

try {
    $inactive30 | Select-Object displayName, department, lastLogon | 
    Export-Csv -Path "inactive_users.csv" -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
    Write-Host "CHECK! Csv-File 'inactive_users.csv' have been created."
}
catch { 
    Write-Warning "ERROR! Could not create 'inactive_users.csv': $_"
}

$report += "CSV file 'inactive_users.csv' has been created with inactive users. `n"
$report += "---------------------------------------------------------------------------`n`n"

# 7. Password age for each user
$report += "Password age per user `n`n"

$sortedUsers = $data.users | Where-Object {
    $_.passwordLastSet
} | Sort-Object -Property @{
    Expression = {
        $pwdDate = Safe-ParseDate -dateString $_.passwordLastSet
        if ($pwdDate) { 
            ($today - $pwdDate).Days 
        }
        else { 
            0
        }
    }
    Descending = $true
}

foreach ($u in $sortedUsers) {
    $pwdDate = Safe-ParseDate -dateString $u.passwordLastSet
    if ($pwdDate) {
        $passwordDays = ($today - $pwdDate).Days
    }
    else {
        $passwordDays = "N/A"
    }
    $report += "{0,-20} {1,-15} {2}`n" -f $u.displayName, "Password age:", "$passwordDays days"
}
$report += "---------------------------------------------------------------------------`n`n"


# 8. 10 most inactive computers

$report += "Top 10 inactive computers `n`n"

$inactiveComputers = $data.computers | Sort-Object {
    if ($_.lastLogon) {
        ($today - [datetime]$_.lastLogon).Days
    }
    else {
        9999# If no date exists, sort them
    }
} -Descending | Select-Object -First 10

foreach ($c in $inactiveComputers) {
    $daysInactive = ($today - [datetime]$c.lastLogon).Days
    $report += "{0,-15} {1,-25} {2}`n" -f $c.Name, "Last seen: $($c.lastLogon)", "($daysInactive days)"
}
$report += "---------------------------------------------------------------------------`n`n"


# 11. Executive Summary
$summary += "===========================================================================`n"
$summary += "                         EXECUTIVE SUMMARY`n"
$summary += "===========================================================================`n"

# 11a - Accounts expiring within 30 days

$expiringAccounts = $data.users | Where-Object {
    $_.accountExpires -and ([datetime]$_.accountExpires - $today).Days -le 30
}
$summary += "          WARNING!  Accounts expiring within 30 days: `n"
$summary += "---------------------------------------------------------------------------`n"
foreach ($u in $expiringAccounts) {
    $daysLeft = ([datetime]$u.accountExpires - $today).Days
    $summary += "{0,-15} {1,-12} {2}`n" -f $u.displayName, "Expiry: $($u.accountExpires)", "($daysLeft days left)"
}
$summary += "`n"

# 11b - Computers inactive 30+ days

$inactiveComputers = $data.computers | Where-Object {
    $_.lastLogon -and ($today - [datetime]$_.lastLogon).Days -gt 30
} | Sort-Object @{Expression = { ($today - [datetime]$_.lastLogon).Days }; Descending = $true }

$summary += "          WARNING!  Computers inactive for 30+ days: `n"
$summary += "---------------------------------------------------------------------------`n"
foreach ($c in $inactiveComputers) {
    $daysInactive = ($today - [datetime]$c.lastLogon).Days
    $summary += "{0,-15} {1,-12} {2}`n" -f $c.name, "Last logon: $($c.lastLogon)", "($daysInactive days)"
}
$summary += "`n"

# 11c - Users with passwords older than 90 days
$oldPassword = $data.users | Where-Object {
    $_.passwordLastSet -and (New-TimeSpan -Start ([datetime]$_.passwordLastSet) -End $today).Days -gt 90
} | Sort-Object @{Expression = { (New-TimeSpan -Start ([datetime]$_.passwordLastSet) -End $today).Days }; Descending = $true }

$summary += "           CRITICAL!  Users with password older than 90 days:`n"
$summary += "---------------------------------------------------------------------------`n"
foreach ($u in $oldPassword) {
    $pwdAge = (New-TimeSpan -Start ([datetime]$u.passwordLastSet) -End $today).Days
    $summary += "{0,-20} {1,-15} {2}`n" -f $u.displayName, "Password age:", "$pwdAge days"
}
$summary += "`n===========================================================================`n`n"




$finalReport = $summary + $report

# Save to file
$finalReport | Out-File -FilePath "AD_Audit_Report.txt" -Encoding UTF8 -Force
