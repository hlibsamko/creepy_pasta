param(
    [string]$Domain = "creepy-pasta.duckdns.org",
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = "Stop"

if ($Domain -notmatch '^[A-Za-z0-9.-]+$') {
    throw "Domain contains unsupported characters."
}
if ($TimeoutSeconds -lt 1 -or $TimeoutSeconds -gt 60) {
    throw "TimeoutSeconds must be between 1 and 60."
}

$httpsUri = [Uri]"https://$Domain/"
$request = [Net.HttpWebRequest]::CreateHttp($httpsUri)
$request.Method = "HEAD"
$request.AllowAutoRedirect = $true
$request.Timeout = $TimeoutSeconds * 1000
$response = $null
try {
    $response = [Net.HttpWebResponse]$request.GetResponse()
    if ([int]$response.StatusCode -lt 200 -or [int]$response.StatusCode -ge 400) {
        throw "HTTPS returned status $([int]$response.StatusCode)."
    }
}
finally {
    if ($response) {
        $response.Dispose()
    }
}

$socket = [Net.WebSockets.ClientWebSocket]::new()
$timeout = [Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds($TimeoutSeconds))
try {
    $null = $socket.ConnectAsync([Uri]"wss://$Domain/", $timeout.Token).GetAwaiter().GetResult()
    if ($socket.State -ne [Net.WebSockets.WebSocketState]::Open) {
        throw "WSS handshake did not reach the Open state."
    }
}
finally {
    $socket.Dispose()
    $timeout.Dispose()
}

Write-Host "HTTPS and WSS edge checks passed for $Domain."
