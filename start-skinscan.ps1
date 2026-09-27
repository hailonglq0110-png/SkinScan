$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add('http://127.0.0.1:8765/')
$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.bin'  = 'application/octet-stream'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.jpeg' = 'image/jpeg'
    '.webp' = 'image/webp'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

try {
    $listener.Start()
    Write-Host 'SkinScan is available at http://127.0.0.1:8765/' -ForegroundColor Green
    Write-Host 'Keep this window open while using SkinScan. Press Ctrl+C to stop.'
    Start-Process 'http://127.0.0.1:8765/'

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        try {
            if ($context.Request.HttpMethod -notin @('GET', 'HEAD')) {
                $response.StatusCode = 405
                $response.Close()
                continue
            }

            $relativePath = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = 'index.html' }
            $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relativePath))
            if (-not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $response.StatusCode = 403
                $response.Close()
                continue
            }
            if (-not [System.IO.File]::Exists($filePath)) {
                $response.StatusCode = 404
                $response.Close()
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $response.ContentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
            $response.Headers['Cache-Control'] = 'no-store'
            $response.ContentLength64 = $bytes.Length
            $response.StatusCode = 200
            if ($context.Request.HttpMethod -eq 'GET' -and $bytes.Length -gt 0) {
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $response.Close()
        }
        catch {
            try {
                $response.StatusCode = 500
                $response.Close()
            }
            catch { }
            Write-Warning $_.Exception.Message
        }
    }
}
catch {
    Write-Error "Could not start the local SkinScan server: $($_.Exception.Message)"
    Write-Host 'If port 8765 is already in use, close the other SkinScan server window and try again.'
    Read-Host 'Press Enter to close'
}
finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
