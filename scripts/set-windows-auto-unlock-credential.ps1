$ErrorActionPreference = "Stop"

function ConvertTo-Base64Utf8([string] $value) {
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value))
}

function Send-BLEUnlockCredentialRequest([string] $request) {
    $pipe = [IO.Pipes.NamedPipeClientStream]::new(
        ".",
        "BLEUnlockCredentialService",
        [IO.Pipes.PipeDirection]::InOut
    )
    $pipe.Connect(3000)
    $writer = [IO.StreamWriter]::new($pipe, [Text.Encoding]::UTF8, 1024, $true)
    $writer.NewLine = "`n"
    $writer.Write($request)
    $writer.Flush()

    $buffer = New-Object byte[] 8192
    $count = $pipe.Read($buffer, 0, $buffer.Length)
    $pipe.Dispose()
    return [Text.Encoding]::UTF8.GetString($buffer, 0, $count)
}

function Parse-KeyValueResponse([string] $response) {
    $result = @{}
    foreach ($line in ($response -split "`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed) {
            continue
        }
        $index = $trimmed.IndexOf("=")
        if ($index -lt 0) {
            continue
        }
        $result[$trimmed.Substring(0, $index)] = $trimmed.Substring($index + 1)
    }
    return $result
}

$credential = Get-Credential -Message "Enter the Windows account BLEUnlock may use for automatic unlock."
$networkCredential = $credential.GetNetworkCredential()
$domain = $networkCredential.Domain
$username = $networkCredential.UserName
$password = $networkCredential.Password

if (-not $username -or -not $password) {
    throw "Username and password are required."
}

$request = @"
protocol=1
command=setCredential
domain=$(ConvertTo-Base64Utf8 $domain)
username=$(ConvertTo-Base64Utf8 $username)
password=$(ConvertTo-Base64Utf8 $password)
"@

$response = Parse-KeyValueResponse (Send-BLEUnlockCredentialRequest $request)
if ($response["ok"] -ne "1") {
    throw "Credential configuration failed: $($response["error"])"
}

Write-Host "BLEUnlock Windows auto unlock credential configured."
