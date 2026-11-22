[CmdletBinding()]
param(
    [string] $Password = $env:Demo__Password,
    [Uri] $ClaimsBase = 'https://localhost:7164',
    [Uri] $NotificationsBase = 'https://localhost:7165',
    [int] $NotificationTimeoutSeconds = 20
)

$ErrorActionPreference = 'Stop'
if (!$Password) { throw 'Set Demo__Password or pass the local demo password to -Password.' }
foreach ($endpoint in $ClaimsBase, $NotificationsBase) {
    if (!$endpoint.IsLoopback -or $endpoint.Scheme -ne 'https') { throw 'Use local HTTPS API addresses.' }
}

function Send-ClaimsRequest($Method, $Path, $Headers, $Data) {
    $request = @{ Method = $Method; Uri = [Uri]::new($ClaimsBase, $Path); Headers = $Headers }
    if ($null -ne $Data) {
        $request.ContentType = 'application/json'
        $request.Body = ConvertTo-Json -InputObject $Data -Compress
    }
    Invoke-RestMethod @request
}

function Connect-DemoUser($Account) {
    $session = Send-ClaimsRequest 'Post' '/auth/login' @{} @{
        email = "$Account@example.test"; password = $Password
    }
    @{ Authorization = "Bearer $($session.accessToken)" }
}

function New-DemoClaim($Description) {
    Send-ClaimsRequest 'Post' '/claims' $claimant @{
        type = 'Motor'
        incidentDate = [DateTime]::UtcNow.AddDays(-1).ToString('yyyy-MM-dd')
        description = $Description
        requestedAmount = 1100
        requestedCurrency = 'MYR'
    }
}

function Assert-Status($Expected, [scriptblock] $Action) {
    try {
        $null = & $Action
    } catch {
        if ([int]$_.Exception.Response.StatusCode -eq $Expected) { return }
        throw
    }
    throw "Expected HTTP status $Expected."
}

$claimant = Connect-DemoUser 'claimant'
$otherClaimant = Connect-DemoUser 'other-claimant'
$staff = Connect-DemoUser 'staff'
$otherStaff = Connect-DemoUser 'other-staff'

$claim = New-DemoClaim 'Demo - Motor damage while parked.'
$path = "/claims/$($claim.id)"
Assert-Status 404 { Send-ClaimsRequest 'Get' $path $otherClaimant }
$queue = (Send-ClaimsRequest 'Get' '/claims?status=Submitted' $staff)
if ($claim.id -notin $queue.id) { throw 'The submitted claim was not visible in the queue.' }
$null = Send-ClaimsRequest 'Post' "$path/pick-up" $staff
Assert-Status 409 { Send-ClaimsRequest 'Post' "$path/pick-up" $otherStaff }
$null = Send-ClaimsRequest 'Put' "$path/exposure" $staff @{ amount = 950; currency = 'MYR' }
$workload = Send-ClaimsRequest 'Get' '/reports/overview?days=30' $staff
$myrExposure = $workload.exposure | Where-Object currency -eq 'MYR'
if ($workload.openClaims -lt 1 -or $myrExposure.amountMinor -lt 95000) {
    throw 'Expected the open claim and its exposure in the workload report.'
}
$null = Send-ClaimsRequest 'Post' "$path/questions" $staff @{ body = 'Where was the car parked?' }
$null = Send-ClaimsRequest 'Post' "$path/replies" $claimant @{ body = 'In front of my home.' }
$approval = Send-ClaimsRequest 'Post' "$path/approve" $staff @{ amount = 850; currency = 'MYR' }
$settlement = Send-ClaimsRequest 'Post' "$path/settle" $staff
if ($approval.status -ne 'Approved' -or $settlement.status -ne 'Settled') { throw 'Expected separate approval and settlement.' }

$declined = New-DemoClaim 'Demo - Windscreen damage outside the policy period.'
$declinedPath = "/claims/$($declined.id)"
$null = Send-ClaimsRequest 'Post' "$declinedPath/pick-up" $otherStaff
$decision = Send-ClaimsRequest 'Post' "$declinedPath/reject" $otherStaff @{ reason = 'The assessment found that the damage predated the sample policy.' }
if ($decision.status -ne 'Rejected' -or !$decision.rejectionReason) { throw 'Expected a recorded rejection reason.' }

$history = (Send-ClaimsRequest 'Get' "$path/history" $claimant)
$thread = (Send-ClaimsRequest 'Get' "$path/messages" $claimant)
$report = Send-ClaimsRequest 'Get' '/reports/overview?days=30' $staff
Assert-Status 403 { Send-ClaimsRequest 'Get' '/reports/overview' $claimant }
if ($thread.Count -ne 2 -or 'Settled' -notin $history.action) { throw 'Expected separate message and audit records.' }

$notificationUri = [Uri]::new($NotificationsBase, '/notifications?pageSize=500')
$deadline = [DateTime]::UtcNow.AddSeconds($NotificationTimeoutSeconds)
do {
    $inbox = (Invoke-RestMethod -Uri $notificationUri -Headers $claimant)
    $delivered = @($inbox | Where-Object { $_.claimId -in $claim.id, $declined.id })
    if ($delivered.Count -ge 4) { break }
    Start-Sleep -Milliseconds 250
} while ([DateTime]::UtcNow -lt $deadline)

foreach ($type in 'QuestionAsked', 'Approved', 'Settled', 'Rejected') {
    if (@($delivered | Where-Object type -eq $type).Count -ne 1) { throw "Expected one $type notification." }
}
$anotherInbox = (Invoke-RestMethod -Uri $notificationUri -Headers $otherClaimant)
if ($claim.id -in $anotherInbox.claimId -or $declined.id -in $anotherInbox.claimId) {
    throw 'A notification reached the wrong claimant.'
}

[pscustomobject]@{
    Settled = $settlement.id
    Rejected = $decision.id
    AuditEvents = $history.Count
    Messages = $thread.Count
    Notifications = ($delivered.type -join ', ')
    OpenWhileUnderReview = $workload.openClaims
    OutstandingMyrMinorWhileUnderReview = $myrExposure.amountMinor
    OpenAfterDecisions = $report.openClaims
}
