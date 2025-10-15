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

# 4. Add inactive users section
$report += "Inactive users (30+ days)`n`n"

foreach ($u in $inactiveUsers) {
    $days = ($today - [datetime]$u.lastLogon).Days
    $report += "$($u.displayName) - $($u.department) - Last logon: $($u.lastLogon) ($days days)`n"
}

$report += "`nTotal inactive users: $($inactiveUsers.count)`n`n"


# 8. Output the report
Write-Output $report

# Optional: Save to file
$report | Out-File -FilePath "AD_Audit_Report.txt" -Encoding UTF8
