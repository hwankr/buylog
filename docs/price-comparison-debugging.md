# Price Comparison Debugging

## Local Keys

Check only key presence. Do not print secret values.

```powershell
$envMap = @{}
Get-Content .env | ForEach-Object {
  if ($_ -match '^\s*([^#][^=]*)=(.*)$') {
    $envMap[$matches[1].Trim()] = $matches[2].Trim()
  }
}
'SUPABASE_URL','SUPABASE_ANON_KEY','NAVER_CLIENT_ID','NAVER_CLIENT_SECRET','OPENAI_API_KEY' |
  ForEach-Object {
    $state = if ($envMap.ContainsKey($_) -and -not [string]::IsNullOrWhiteSpace($envMap[$_])) { 'SET' } else { 'MISSING' }
    "$_=$state"
  }
```

## Direct Naver Probe

This verifies local Naver credentials without showing the credentials.

```powershell
Add-Type -AssemblyName System.Net.Http
$client = [System.Net.Http.HttpClient]::new()
$query = [System.Net.WebUtility]::UrlEncode('정수기 필터')
$req = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, "https://openapi.naver.com/v1/search/shop.json?query=$query&display=1&sort=sim")
$req.Headers.Add('X-Naver-Client-Id', $envMap['NAVER_CLIENT_ID'])
$req.Headers.Add('X-Naver-Client-Secret', $envMap['NAVER_CLIENT_SECRET'])
$res = $client.SendAsync($req).GetAwaiter().GetResult()
"Naver direct HTTP $([int]$res.StatusCode)"
$client.Dispose()
```

## Deployed Supabase Edge Probe

This verifies the deployed Edge Function and its deployed secrets.

```powershell
$functionUri = "$($envMap['SUPABASE_URL'].TrimEnd('/'))/functions/v1/price-comparison"
$body = '{"itemName":"정수기 필터","brand":"","display":1}'
Invoke-RestMethod -Uri $functionUri -Headers @{ Authorization = "Bearer $($envMap['SUPABASE_ANON_KEY'])"; "Content-Type" = "application/json" } -Method POST -Body $body
```

Expected: `comparisons` is present. `analysisApplied=true` means OpenAI enrichment was applied.
