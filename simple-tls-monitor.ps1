param(
    [Parameter(Mandatory=$false, Position=0)][int]$Port = 12101,
    [Parameter(Mandatory=$false, Position=1)][int]$ReadInterval = 50,
    [Parameter(Mandatory=$false, Position=2)][string]$Mode = 'jsonl',
    [Parameter(Mandatory=$false, Position=3)][string]$CertFriendlyName = 'TlsClientLibTest'
)

# Modify the following script and run it in PowerShell with administrator privileges
# to create a self-signed certificate.
#
# $param = @{
#    Type = 'SSLServerAuthentication'
#    DnsName = 'SET_YOUR_DOMAIN'
#    CertStoreLocation = 'Cert:\CurrentUser\My'
#    FriendlyName = 'TlsClientLibTest'
# }
# New-SelfSignedCertificate @params
#

$serverCert = Get-ChildItem -Path Cert:\CurrentUser\My
        | Where-Object { $_.FriendlyName -eq $CertFriendlyName }
if ($null -eq $serverCert) {
    Write-Host "No certs."
}

function Mode-Jsonl {
    param(
        [int]$Port,
        [int]$ReadInterval,
        [Object]$cert
    )
    $listenerEndPoint = New-Object IPEndpoint([System.Net.IPAddress]::Any, $Port)
    $tcpListener = New-Object System.Net.Sockets.TCPListener($listenerEndpoint)
    $client = $null
    $clientStream = $null
    $sslStream = $null
    $reader = $null
    $task = $null
    $entity = $null
    $prevEntity = $null

    try {
        $tcpListener.Start()
        while ($true) {
            # Wait for client connection.
            if ($null -eq $client) {
                if ($null -eq $task) {
                    $task = $tcpListener.AccepttcpClientAsync()
                }
                if (-not $task.Wait(200)) {
                    continue
                }
                $client = $task.GetAwaiter().GetResult()
                $clientStream = $client.GetStream()
                $sslStream = New-Object System.Net.Security.SslStream($clientStream, $false)
                $sslStream.AuthenticateAsServerAsync($cert, $false, [System.Security.Authentication.SslProtocols]::Tls12, $false).Wait()

                $reader = New-Object System.IO.StreamReader($sslStream)
                $task = $null
            }
            if ($reader.EndOfStream) {
                $reader.Close()
                $sslStream.Close()
                $clientStream.Close()
                $client.Close()
                $task = $null
                $reader = $null
                $clientStream = $null
                $client = $null
                $entity = $null
                $prevEntity = $null
                continue
            }

            # Waiting to receive data.
            try {
                if ($null -eq $task) {
                    $task = $reader.ReadLineAsync()
                }

                if (-not $task.Wait($ReadInterval)) {
                    continue
                }
                $entity = $task.GetAwaiter().GetResult();
                $task = $null
            }
            catch {
                Write-Host "error: $($_.Exception.Message)"
                $reader.Close()
                $clientStream.Close()
                $client.Close()
                $reader = $null
                $ClientStream = $null
                $client = $null
            }

            if ($null -ne $entity) {
                if ("" -eq $entity) {
                    if ("" -eq $prevEntity) {
                        Write-Host 'reset'
                    }
                } else {
                    try {
                        $entity | ConvertFrom-Json | Write-Host
                    }
                    catch {
                        Write-Host "error payload: ${entity}"
                    }
                }
            }

            $prevEntity = $entity
            $entity = $null
        }
    }
    catch {
        Write-Host "error: $($_.Exception.Message)"
    }
    finally {
        if ($client) {
            $reader.Close()
            $sslStream.Close()
            $clientStream.Close()
            $client.Close()
        }
        $tcpListener.Stop()
    }
}

function Mode-Raw {
    param(
        [string]$Port,
        [int]$ReadInterval,
        [Object]$cert
    )
    $listenerEndPoint = New-Object IPEndpoint([System.Net.IPAddress]::Any, $Port)
    $tcpListener = New-Object System.Net.Sockets.TCPListener($listenerEndpoint)
    $client = $null
    $clientStream = $null
    $reader = $null
    $task = $null
    $prevEntity = $null

    try {
        $tcpListener.Start()
        while ($true) {
            # Wait for client connection.
            if ($null -eq $client) {
                if ($null -eq $task) {
                    $task = $tcpListener.AcceptTcpClientAsync()
                }
                if (-not $task.Wait(200)) {
                    continue
                }

                $client = $task.GetAwaiter().GetResult();
                $clientStream = $client.GetStream()
                $sslStream = New-Object System.Net.Security.SslStream($clientStream, $false)
                $sslStream.AuthenticateAsServer($cert, $false, [System.Security.Authentication.SslProtocols]::Tls12, $false)
                $reader = New-Object System.IO.StreamReader($sslStream)
                $task = $null
            }
            if ($reader.EndOfStream) {
                $reader.Close()
                $sslStream.Close()
                $clientStream.Close()
                $client.Close()
                $task = $null
                $reader = $null
                $clientStream = $null
                $client = $null
                $entity = $null
                $prevEntity = $null
                continue
            }

            # Waiting to receive data.
            try {
                if ($null -eq $task) {
                    $task = $reader.ReadLineAsync()
                }

                if (-not $task.Wait($ReadInterval)) {
                    continue
                }
                $entity = $task.GetAwaiter().GetResult();
                $task = $null
            }
            catch {
                Write-Host "error: $($_.Exception.Message)"
                $reader.Close()
                $sslStream.Close()
                $clientStream.Close()
                $client.Close()
                $reader = $null
                $sslStream = $null
                $ClientStream = $null
                $client = $null
            }

            if ($null -ne $entity) {
                if ("" -eq $entity) {
                    if ("" -eq $prevEntity) {
                        Write-Host 'reset'
                    }
                } else {
                    $entity | Write-Host
                }
            }

            $prevEntity = $entity
            $entity = $null
        }
    }
    catch {
        Write-Host "error: $($_.Exception.Message)"
    }
    finally {
        if ($client) {
            $reader.Close()
            $sslStream.Close()
            $clientStream.Close()
            $client.Close()
        }
        $tcpListener.Stop()
    }
}

switch ( $Mode )
{
    Jsonl { Mode-Jsonl -Port $Port -ReadInterval $ReadInterval -cert $serverCert }
    Raw   { Mode-Raw -Port $Port -ReadInterval $ReadInterval -cert $serverCert }
}
