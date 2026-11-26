# Serves what Deezer is playing on this PC, so the dashboard can show it.
#
# It reads the media info that apps report to Windows (the same info as the
# volume popup). It needs no Deezer account, API key or internet, no admin
# rights and nothing to install. It needs Windows 10 1809 or later, and runs in
# Windows PowerShell 5.1 ("powershell", not "pwsh").
#
#   powershell -ExecutionPolicy Bypass -File scripts\now-playing.ps1
#
# By default only this PC can read it, which is enough for `npm run dev`.
# For the Pi, listen on the PC's address on the private link, and allow the port
# in Windows Firewall for the Private profile:
#
#   powershell -ExecutionPolicy Bypass -File scripts\now-playing.ps1 -Address 192.168.50.1
#
# Routes:
#   /media/now-playing.json   {"track": {...}} or {"track": null}
#   /media/cover?id=...       the cover picture of the current track

param(
    # Address to listen on.
    [string]$Address = '127.0.0.1',
    [int]$Port = 8098,
    # Only apps whose Windows id contains this text are shown. To use Deezer in a
    # browser, put the browser's name (for example 'opera'). Anything else that
    # browser plays is then shown too.
    [string]$App = 'deezer'
)

$ErrorActionPreference = 'Stop'

# --- Windows media info ------------------------------------------------------

Add-Type -AssemblyName System.Runtime.WindowsRuntime
$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media.Control, ContentType = WindowsRuntime]
$null = [Windows.Storage.Streams.IRandomAccessStreamWithContentType, Windows.Storage.Streams, ContentType = WindowsRuntime]

# PowerShell 5.1 can't await Windows Runtime calls, so turn them into .NET tasks.
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1

function Wait-WinRt($Operation, [Type]$ResultType) {
    $task = $asTask.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    if (-not $task.Wait(2000)) { throw 'Windows did not answer in time' }
    $task.Result
}

# Called through reflection: PowerShell 5.1 can't convert the stream by itself.
$asStream = [System.IO.WindowsRuntimeStreamExtensions].GetMethod(
    'AsStreamForRead', [Type[]]@([Windows.Storage.Streams.IInputStream]))

$managerType = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]
$manager = Wait-WinRt ($managerType::RequestAsync()) $managerType

# The last track Windows reported, and its cover, kept for /media/cover.
$script:lastTrack = $null
$script:cover = $null

function Read-Cover($Reference) {
    if ($null -eq $Reference) { return $null }
    try {
        $source = Wait-WinRt ($Reference.OpenReadAsync()) ([Windows.Storage.Streams.IRandomAccessStreamWithContentType])
        $stream = $asStream.Invoke($null, @($source))
        $memory = New-Object System.IO.MemoryStream
        try { $stream.CopyTo($memory) } finally { $stream.Dispose() }
        $bytes = $memory.ToArray()
        if ($bytes.Length -eq 0) { return $null }

        # The id changes with the picture, so the dashboard knows when to reload it.
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $id = [BitConverter]::ToString($md5.ComputeHash($bytes)).Replace('-', '').ToLower()
        $md5.Dispose()
        # PowerShell 5.1 can't read the stream's content type, so check the
        # first byte: PNG files start with 0x89, JPEG files with 0xFF.
        $type = switch ($bytes[0]) { 0x89 { 'image/png' } 0xFF { 'image/jpeg' } default { 'application/octet-stream' } }
        @{ id = $id; type = $type; bytes = $bytes }
    }
    catch {
        # A missing cover shouldn't hide the track.
        $null
    }
}

# The answer when Windows has no media info for the app. Deezer can withdraw it
# while paused, so as long as the app is running, show the last track as paused.
function Get-HeldTrack {
    if ($script:lastTrack -and (Get-Process -Name "*$App*" -ErrorAction SilentlyContinue)) {
        $script:lastTrack.playing = $false
    }
    else {
        $script:lastTrack = $null
        $script:cover = $null
    }
    @{ track = $script:lastTrack }
}

function Get-NowPlaying {
    $sessions = @($manager.GetSessions() | Where-Object {
            $_.SourceAppUserModelId.IndexOf($App, [StringComparison]::OrdinalIgnoreCase) -ge 0
        })
    # Prefer a session that is playing over a paused one.
    $session = @($sessions | Where-Object { "$($_.GetPlaybackInfo().PlaybackStatus)" -eq 'Playing' }) + $sessions |
        Select-Object -First 1
    if ($null -eq $session) { return Get-HeldTrack }

    $media = Wait-WinRt ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    if (-not $media.Title) { return Get-HeldTrack }

    $info = $session.GetPlaybackInfo()
    $playing = "$($info.PlaybackStatus)" -eq 'Playing'
    $timeline = $session.GetTimelineProperties()
    $duration = ($timeline.EndTime - $timeline.StartTime).TotalSeconds
    $position = ($timeline.Position - $timeline.StartTime).TotalSeconds

    # Apps report the position only now and then. While playing, add the time
    # that has passed since the last report.
    if ($playing -and $timeline.LastUpdatedTime.Year -gt 2000) {
        $rate = if ($null -ne $info.PlaybackRate) { $info.PlaybackRate } else { 1 }
        $position += ([DateTimeOffset]::UtcNow - $timeline.LastUpdatedTime).TotalSeconds * $rate
    }

    $script:cover = Read-Cover $media.Thumbnail

    # Some apps report no length. The dashboard then hides the progress.
    $hasTimeline = $duration -gt 0
    $script:lastTrack = @{
        title    = $media.Title
        artist   = $media.Artist
        playing  = $playing
        position = if ($hasTimeline) { [Math]::Floor([Math]::Max(0, [Math]::Min($position, $duration))) } else { $null }
        duration = if ($hasTimeline) { [Math]::Floor($duration) } else { $null }
        coverId  = if ($script:cover) { $script:cover.id } else { $null }
    }
    @{ track = $script:lastTrack }
}

# --- Web server --------------------------------------------------------------

# A plain TCP listener, because HttpListener needs admin rights to accept
# connections from another machine.
function Send-Response($Stream, [string]$Status, [string]$Type, [byte[]]$Body) {
    $head = "HTTP/1.1 $Status`r`nContent-Type: $Type`r`nContent-Length: $($Body.Length)`r`n" +
    "Cache-Control: no-store`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
    $headBytes = [System.Text.Encoding]::ASCII.GetBytes($head)
    $Stream.Write($headBytes, 0, $headBytes.Length)
    $Stream.Write($Body, 0, $Body.Length)
}

function Send-Text($Stream, [string]$Status, [string]$Text) {
    Send-Response $Stream $Status 'text/plain; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($Text))
}

function Invoke-Request($Client) {
    $Client.ReceiveTimeout = 1000
    $Client.SendTimeout = 1000
    $stream = $Client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)

    $requestLine = $reader.ReadLine()
    # Read the rest of the headers before answering.
    for ($i = 0; $i -lt 100; $i++) {
        if (-not $reader.ReadLine()) { break }
    }

    $method, $target = "$requestLine" -split ' ' | Select-Object -First 2
    $path = "$target".Split('?')[0]

    if ($method -ne 'GET') {
        Send-Text $stream '405 Method Not Allowed' 'Only GET'
    }
    elseif ($path -eq '/media/now-playing.json') {
        try {
            $json = Get-NowPlaying | ConvertTo-Json -Compress -Depth 3
        }
        catch {
            # Windows can fail for a moment while the track changes.
            Write-Warning "Could not read the media info: $($_.Exception.Message)"
            Send-Text $stream '503 Service Unavailable' 'Media info unavailable'
            return
        }
        Send-Response $stream '200 OK' 'application/json; charset=utf-8' ([System.Text.Encoding]::UTF8.GetBytes($json))
    }
    elseif ($path -eq '/media/cover' -and $script:cover) {
        Send-Response $stream '200 OK' $script:cover.type $script:cover.bytes
    }
    else {
        Send-Text $stream '404 Not Found' 'Not found'
    }
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Parse($Address), $Port)
$listener.Start()
Write-Host "Now playing: http://${Address}:$Port/media/now-playing.json (apps matching '$App'). Ctrl+C stops."

try {
    while ($true) {
        # Waiting in short steps keeps Ctrl+C working.
        if (-not $listener.Pending()) {
            Start-Sleep -Milliseconds 50
            continue
        }
        $client = $listener.AcceptTcpClient()
        try { Invoke-Request $client }
        catch { Write-Warning "Request failed: $($_.Exception.Message)" }
        finally { $client.Close() }
    }
}
finally {
    $listener.Stop()
}
