#1, load the json, date and show domain-name
$data = Get-Content -Path "ad_export.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$today = Get-Date

$report = @"
AD_AUDIT REPORT
--------------------------------------------------------------------------------------
Domain: $($json.domain)
Forest: $($json.forst)
Export-date: $($json.export_date)
Created: $(Get-Date)
---------------------------------------------------------------------------------------
"@

#3. List inactive users that have not been online for more than 30 days

$inactiveUsers = $json.users | Where-Object {
    $_.lastLogon -and ($today - [datetime]$_.lastLogon).Days -gt 30

}





