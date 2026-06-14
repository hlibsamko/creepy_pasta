param(
    [string]$HostName = "138.2.166.64",
    [int]$Port = 24567
)

$ErrorActionPreference = "Stop"

$tcp = Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Detailed
$tcp

if (-not $tcp.TcpTestSucceeded) {
    throw "TCP connectivity to $HostName`:$Port failed. Check Oracle ingress rules and UFW."
}
