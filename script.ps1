# 1. Load the JSON, date and show domain-name
$data = Get-Content -Path "ad_export.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$today = Get-Date

$report = @"
AD_AUDIT REPORT
--------------------------------------------------------------------------------------
Domain: $($data.domain)
Forest: $($data.forest)
Export-date: $($data.export_date)
Created: $(Get-Date)
--------------------------------------------------------------------------------------`n
"@


# 3. List inactive users that have not been online for more than 30 days
$inactiveUsers = $data.users | Where-Object {
    $_.lastLogon -and ($today - [datetime]$_.lastLogon).Days -gt 30
}

# Add inactive users section
$report += "Inactive users (30+ days)`n`n"

foreach ($u in $inactiveUsers) {
    $days = ($today - [datetime]$u.lastLogon).Days
    $report += "$($u.displayName) - $($u.department) - Last logon: $($u.lastLogon) ($days days)`n"
}

$report += "`nTotal inactive users: $($inactiveUsers.count)`n"
$report += "--------------------------------------------------------------------------------------`n`n"

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

$report += "--------------------------------------------------------------------------------------`n`n"

# 5. Group computers per site
$report += "Computers per site `n`n"

$computersbysite = $data.computers | Group-Object -Property site

foreach ($group in $computersbysite) {
    $report += "{0,-14} {1,-10} {2}`n" -f $group.Name, $group.Count, ""
}
$report += "--------------------------------------------------------------------------------------`n`n"

# 6. Export inactive users to CSV

$inactiveUsers | Select-Object displayName, department, lastLogon | 
Export-Csv -Path "inactive_users.csv" -NoTypeInformation -Encoding UTF8

$report += "CSV file 'inactive_users.csv' has been created with inactive users. `n"
$report += "--------------------------------------------------------------------------------------`n`n"


# Output the report
Write-Output $report

# Save to file
$report | Out-File -FilePath "AD_Audit_Report.txt" -Encoding UTF8
