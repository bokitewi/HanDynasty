$ErrorActionPreference = 'Stop'

$sourceRoot = 'D:\SteamLibrary\steamapps\workshop\content\1158310\2545836661'
$targetRoot = 'E:\documents\Paradox Interactive\Crusader Kings III\mod\HanDyansty'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $targetRoot "tmp\integration_backups\2545836661_$stamp"
$utf8Bom = [System.Text.UTF8Encoding]::new($true)

$imports = [ordered]@{
	'common\culture\traditions\hd_mcpe_traditions.txt' = 'common\culture\traditions\mcpe_traditions.txt'
	'common\scripted_effects\hd_mcpe_effects.txt' = 'common\scripted_effects\mcpe_effects.txt'
	'common\scripted_modifiers\hd_mcpe_modifiers.txt' = 'common\scripted_modifiers\mcpe_modifiers.txt'
	'common\scripted_triggers\hd_mcpe_triggers.txt' = 'common\scripted_triggers\mcpe_triggers.txt'
	'events\education_and_childhood\hd_mcpe_events.txt' = 'events\education_and_childhood\mcpe.txt'
	'events\education_and_childhood\hd_mcpe_guardian_response.txt' = 'events\education_and_childhood\mcpe_guardian_response.txt'
	'localization\english\event_localization\hd_mcpe_l_english.yml' = 'localization\english\event_localization\mcpe_l_english.yml'
}

$targetFiles = @($imports.Keys) + @(
	'common\on_action\hd_mcpe_childhood_on_actions.txt',
	'localization\simp_chinese\event_localization\hd_mcpe_l_simp_chinese.yml'
)

foreach ($relativePath in $targetFiles) {
	$targetPath = Join-Path $targetRoot $relativePath
	if (Test-Path -LiteralPath $targetPath) {
		$backupPath = Join-Path $backupRoot $relativePath
		New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
		Copy-Item -LiteralPath $targetPath -Destination $backupPath
	}
}

foreach ($entry in $imports.GetEnumerator()) {
	$sourcePath = Join-Path $sourceRoot $entry.Value
	$targetPath = Join-Path $targetRoot $entry.Key
	if (-not (Test-Path -LiteralPath $sourcePath)) {
		throw "Missing source file: $sourcePath"
	}
	New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
	$content = [System.IO.File]::ReadAllText($sourcePath)
	$content = $content.Replace('has_opposing_personality_trait_trigger', 'hd_mcpe_has_opposing_personality_trait_trigger')
	$content = $content.Replace('is_childhood_personality_event_valid_trigger', 'hd_mcpe_is_childhood_personality_event_valid_trigger')
	$content = $content.Replace('tradition_mcpe_dummy', 'tradition_hd_mcpe_dummy')
	if ($entry.Key -eq 'common\scripted_triggers\hd_mcpe_triggers.txt') {
		$oldMainTrigger = "hd_mcpe_is_childhood_personality_event_valid_trigger = {`r`n`tAND = {`r`n`t`tis_available_child = yes"
		$newMainTrigger = "hd_mcpe_is_childhood_personality_event_valid_trigger = {`r`n`tAND = {`r`n`t`tis_available_child_allow_travel = yes"
		$content = $content.Replace($oldMainTrigger, $newMainTrigger)
	}
	[System.IO.File]::WriteAllText($targetPath, $content, $utf8Bom)
}

# The 1.9 source contains several unescaped dialogue quotes. CK3 localization
# requires quotes inside the value to be escaped, so normalize the imported
# English fallback while retaining the first and last delimiters.
$englishTargetPath = Join-Path $targetRoot 'localization\english\event_localization\hd_mcpe_l_english.yml'
$englishTargetLines = [System.IO.File]::ReadAllLines($englishTargetPath)
for ($lineIndex = 0; $lineIndex -lt $englishTargetLines.Count; $lineIndex++) {
	if ($englishTargetLines[$lineIndex] -match '^(\s*[^#\s][^:]*:0\s+")(.*)("\s*)$') {
		$escapedValue = [regex]::Replace($matches[2], '(?<!\\)"', '\"')
		$englishTargetLines[$lineIndex] = $matches[1] + $escapedValue + $matches[3]
	}
}
$englishTargetOutput = [System.Collections.Generic.List[string]]::new()
$englishTargetOutput.AddRange([string[]]$englishTargetLines)
$englishTargetOutput.Add(' tradition_hd_mcpe_dummy_name:0 "MCPE Compatibility Parameters"')
$englishTargetOutput.Add(' tradition_hd_mcpe_dummy_desc:0 "A hidden compatibility definition for the childhood personality event system."')
[System.IO.File]::WriteAllLines($englishTargetPath, $englishTargetOutput, $utf8Bom)

$weights = @(
	50,50,50,50,50,150,50,150,50,50,50,50,50,150,50,150,50,50,50,50,50,50,50,50,
	150,50,50,50,50,50,50,50,50,50,50,50,50,50,50,300,50,50,50,50,50,50,50
)
if ($weights.Count -ne 47) { throw 'Expected exactly 47 MCPE event weights.' }
$onActionLines = [System.Collections.Generic.List[string]]::new()
$onActionLines.Add('# More Childhood Personality Events (Workshop 2545836661)')
$onActionLines.Add('# Only the project event list is appended; CK3 1.19 vanilla trigger/effects remain authoritative.')
$onActionLines.Add('# User-selected balance: 50% of the original MCPE event weights.')
$onActionLines.Add('child_personality_gain = {')
$onActionLines.Add("`trandom_events = {")
for ($i = 0; $i -lt 47; $i++) {
	$eventId = $i + 1
	$onActionLines.Add("`t`t$($weights[$i]) = mcpe.$eventId")
}
$onActionLines.Add("`t}")
$onActionLines.Add('}')
$onActionPath = Join-Path $targetRoot 'common\on_action\hd_mcpe_childhood_on_actions.txt'
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $onActionPath) | Out-Null
[System.IO.File]::WriteAllText($onActionPath, ($onActionLines -join "`r`n") + "`r`n", $utf8Bom)

$englishPath = Join-Path $sourceRoot 'localization\english\event_localization\mcpe_l_english.yml'
$chinesePath = Join-Path $targetRoot 'localization\simp_chinese\event_localization\hd_mcpe_l_simp_chinese.yml'
$cachePath = Join-Path $targetRoot 'tmp\mcpe_2545836661_translation_cache.json'
$sourceLines = [System.IO.File]::ReadAllLines($englishPath)
$entries = [System.Collections.Generic.List[object]]::new()
foreach ($line in $sourceLines) {
	if ($line -match '^\s*([^#\s][^:]*):0\s+"(.*)"\s*$') {
		$entries.Add([pscustomobject]@{ Key = $matches[1]; English = $matches[2] })
	}
}
if ($entries.Count -ne 351) { throw "Expected 351 localization keys, found $($entries.Count)." }

$cache = @{}
if (Test-Path -LiteralPath $cachePath) {
	$loadedCache = Get-Content -LiteralPath $cachePath -Raw | ConvertFrom-Json -AsHashtable
	foreach ($key in $loadedCache.Keys) { $cache[$key] = [string]$loadedCache[$key] }
}

function Protect-Ck3Tokens([string]$text, [hashtable]$tokenMap) {
	$patterns = @(
		'\[[^\]]+\]',
		'\$[^$]+\$',
		'@[A-Za-z0-9_]+!',
		'#[A-Za-z0-9_]+',
		'#!',
		'\\n',
		'\\"'
	)
	$result = $text
	$index = 0
	foreach ($pattern in $patterns) {
		$result = [regex]::Replace($result, $pattern, {
			param($match)
			$token = "ZZCK3TOKEN$($tokenMap.Count.ToString('D4'))ZZ"
			$tokenMap[$token] = $match.Value
			return $token
		})
		$index++
	}
	return $result
}

function Restore-Ck3Tokens([string]$text, [hashtable]$tokenMap) {
	$result = $text
	foreach ($token in $tokenMap.Keys) {
		$result = $result.Replace($token, [string]$tokenMap[$token])
	}
	return $result
}

$pending = @($entries | Where-Object { -not $cache.ContainsKey($_.Key) })
$cursor = 0
while ($cursor -lt $pending.Count) {
	$batch = [System.Collections.Generic.List[object]]::new()
	$batchLength = 0
	while ($cursor -lt $pending.Count -and $batch.Count -lt 14) {
		$entry = $pending[$cursor]
		$tokenMap = @{}
		$protected = Protect-Ck3Tokens $entry.English $tokenMap
		if ($batch.Count -gt 0 -and ($batchLength + $protected.Length) -gt 3500) { break }
		$batch.Add([pscustomobject]@{ Entry = $entry; Protected = $protected; Tokens = $tokenMap })
		$batchLength += $protected.Length
		$cursor++
	}

	$queryParts = [System.Collections.Generic.List[string]]::new()
	for ($i = 0; $i -lt $batch.Count; $i++) {
		$queryParts.Add($batch[$i].Protected)
		if ($i -lt ($batch.Count - 1)) {
			$queryParts.Add("`nZZSEP$($i.ToString('D3'))ZZ`n")
		}
	}
	$queryText = $queryParts -join ''
	$uri = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=zh-CN&dt=t&q=' + [uri]::EscapeDataString($queryText)
	$translatedText = $null
	for ($attempt = 1; $attempt -le 4; $attempt++) {
		try {
			$response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
			$translatedText = (($response[0] | ForEach-Object { $_[0] }) -join '')
			break
		} catch {
			if ($attempt -eq 4) { throw }
			Start-Sleep -Seconds $attempt
		}
	}
	$parts = [regex]::Split($translatedText, '\s*ZZSEP\d{3}ZZ\s*')
	if ($parts.Count -ne $batch.Count) {
		throw "Translation batch split mismatch: expected $($batch.Count), received $($parts.Count)."
	}
	for ($i = 0; $i -lt $batch.Count; $i++) {
		$translated = Restore-Ck3Tokens $parts[$i].Trim() $batch[$i].Tokens
		$cache[$batch[$i].Entry.Key] = $translated
	}
	$cache | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $cachePath -Encoding utf8BOM
	Write-Output "Translated $($cache.Count)/351 localization entries"
}

$chineseLines = [System.Collections.Generic.List[string]]::new()
$chineseLines.Add('l_simp_chinese:')
$manualChineseOverrides = @{
	'mcpegr.13.confirm_calm' = '明智的决定。言语伤害不了[child.GetHerHim]。'
	'mcpegr.14.d_chaste' = '[child.GetFirstNameNoTooltip|U]说，如果爱情就是这个样子，那么[child.GetSheHe]宁可不要。'
}
foreach ($entry in $entries) {
	if ($manualChineseOverrides.ContainsKey($entry.Key)) {
		$value = [string]$manualChineseOverrides[$entry.Key]
	} else {
		$value = [string]$cache[$entry.Key]
	}
	if ([string]::IsNullOrWhiteSpace($value)) { throw "Empty translation: $($entry.Key)" }
	$value = $value.Replace('\"', 'ZZESCAPEDQUOTEZZ')
	$value = $value.Replace('"', '\"')
	$value = $value.Replace('ZZESCAPEDQUOTEZZ', '\"')
	$chineseLines.Add(" $($entry.Key):0 `"$value`"")
}
$chineseLines.Add(' tradition_hd_mcpe_dummy_name:0 "MCPE兼容参数"')
$chineseLines.Add(' tradition_hd_mcpe_dummy_desc:0 "供儿童性格事件系统使用的隐藏兼容定义。"')
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $chinesePath) | Out-Null
[System.IO.File]::WriteAllText($chinesePath, ($chineseLines -join "`r`n") + "`r`n", $utf8Bom)

Write-Output "Integration files written. Backup root: $backupRoot"
