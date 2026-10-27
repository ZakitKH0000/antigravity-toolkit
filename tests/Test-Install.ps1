# Проверки install.ps1 на временных «домашних» папках. Настоящий профиль не затрагивается.
#   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Install.ps1
$ErrorActionPreference = 'Stop'
$Installer = Join-Path (Split-Path $PSScriptRoot) 'install.ps1'
$Work = Join-Path ([IO.Path]::GetTempPath()) ('agt-test-' + [Guid]::NewGuid().ToString('N'))
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$script:Pass = 0; $script:Fail = 0
function Check($Ok, [string]$Name) { if ($Ok) { $script:Pass++ } else { $script:Fail++; Write-Output "FAIL: $Name" } }
function Run([string]$HomeDir, [string[]]$Arguments) {
    $out = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Installer -HomeDir $HomeDir @Arguments 2>&1
    [pscustomobject]@{ Out = ($out -join "`n"); Code = $LASTEXITCODE }
}
function NewHome([string]$Name) { $h = Join-Path $Work $Name; New-Item -ItemType Directory -Force $h | Out-Null; $h }
function Cfg([string]$HomeDir) { Join-Path $HomeDir '.gemini\config' }

try {
    # Чистая установка
    $h = NewHome 'clean'; $c = Cfg $h
    $r = Run $h '-All'; Check ($r.Code -eq 0) 'чистая установка завершается без ошибок'
    foreach ($id in 'handoff', 'resume', 'review', 'commit', 'fix', 'explain') { Check ((Test-Path "$c\skills\$id\SKILL.md") -and (Test-Path "$c\skills\$id\.antigravity-toolkit")) "команда $id установлена с маркером" }
    foreach ($id in 'context-economy', 'confirm-destructive', 'code-style', 'memory') { Check (Test-Path "$c\rules\antigravity-toolkit-$id.md") "правило $id установлено" }
    $m = Get-Content "$c\mcp_config.json" -Raw | ConvertFrom-Json
    Check ($m.mcpServers.context7.serverUrl -eq 'https://mcp.context7.com/mcp' -and $m.mcpServers.memory.command -eq 'npx') 'MCP-серверы записаны'
    Check ($m.mcpServers.memory.env.MEMORY_FILE_PATH -eq (($h -replace '\\', '/') + '/.gemini/antigravity-toolkit/memory.jsonl')) 'путь к файлу памяти в профиле пользователя'
    Check ([IO.File]::ReadAllBytes("$c\mcp_config.json")[0] -ne 0xEF) 'mcp_config.json без BOM'
    $r = Run $h '-All'; Check ($r.Out -notmatch '\[(установлено|обновлено)\]' -and $r.Out -match 'без изменений') 'повторная установка ничего не меняет'
    $r = Run $h '-List'; Check (-not ($r.Out -split "`n" | Where-Object { $_ -match '^\s' -and $_ -notmatch 'установлено' })) 'список показывает всё установленным'

    # Обновление
    Add-Content "$c\skills\fix\SKILL.md" 'старая версия'
    Check ((Run $h '-List').Out -match '/fix\s+есть обновление') 'изменённая команда видна как обновление'
    $r = Run $h '-Update'; Check ($r.Out -match '\[обновлено\] команда /fix' -and $r.Code -eq 0) 'обновление ставит актуальную версию'
    $r = Run $h '-Update'; Check ($r.Out -match 'уже актуально') 'повторное обновление ничего не меняет'

    # Чужие файлы и записи MCP
    $h = NewHome 'foreign'; $c = Cfg $h
    New-Item -ItemType Directory -Force "$c\skills\review", "$c\rules" | Out-Null
    [IO.File]::WriteAllText("$c\skills\review\SKILL.md", 'мой review', $Utf8)
    [IO.File]::WriteAllText("$c\rules\antigravity-toolkit-code-style.md", 'моё правило', $Utf8)
    $userCfg = '{"mcpServers":{"my-server":{"command":"my.exe","args":["--x"],"env":{"K":"1"}},"deepwiki":{"serverUrl":"https://example.org/mcp"}},"otherSetting":true}'
    [IO.File]::WriteAllText("$c\mcp_config.json", $userCfg, $Utf8)
    $r = Run $h '-All'
    Check ([IO.File]::ReadAllText("$c\skills\review\SKILL.md") -eq 'мой review') 'чужая команда с тем же именем не изменена'
    Check ([IO.File]::ReadAllText("$c\rules\antigravity-toolkit-code-style.md") -eq 'моё правило') 'чужое правило с тем же именем не изменено'
    $m = Get-Content "$c\mcp_config.json" -Raw | ConvertFrom-Json
    Check ($m.mcpServers.'my-server'.command -eq 'my.exe' -and $m.mcpServers.'my-server'.env.K -eq '1' -and $m.otherSetting -eq $true) 'чужие MCP-серверы и настройки сохранены'
    Check ($m.mcpServers.deepwiki.serverUrl -eq 'https://example.org/mcp') 'чужая запись с тем же именем не изменена'
    Check ($null -ne $m.mcpServers.context7) 'наши MCP добавлены рядом с чужими'
    $backups = @(Get-ChildItem "$h\.gemini\antigravity-toolkit\backups")
    Check ($backups.Count -eq 1 -and [IO.File]::ReadAllText($backups[0].FullName) -eq $userCfg) 'резервная копия прежнего mcp_config.json'
    Check ($r.Out -match '\[пропуск\] команда /review' -and $r.Out -match '\[пропуск\] правило code-style' -and $r.Out -match '\[пропуск\] MCP deepwiki') 'о пропусках сообщается'

    # Удаление
    $r = Run $h @('-Uninstall', '-All')
    Check (-not (Test-Path "$c\skills\handoff") -and (Test-Path "$c\skills\review\SKILL.md")) 'удаляются только свои команды'
    Check (-not (Test-Path "$c\rules\antigravity-toolkit-memory.md") -and (Test-Path "$c\rules\antigravity-toolkit-code-style.md")) 'удаляются только свои правила'
    $m = Get-Content "$c\mcp_config.json" -Raw | ConvertFrom-Json
    Check ($null -eq $m.mcpServers.context7 -and $null -ne $m.mcpServers.'my-server' -and $null -ne $m.mcpServers.deepwiki) 'удаляются только свои MCP'
    Check ($r.Out -match 'файл памяти агента не удалялся') 'о сохранении памяти сообщается'

    # Файлы пользователя внутри нашей папки команды не удаляются
    $h = NewHome 'extra'; $c = Cfg $h
    Run $h @('-Commands', 'fix') | Out-Null
    [IO.File]::WriteAllText("$c\skills\fix\notes.txt", 'мои заметки', $Utf8)
    Run $h @('-Uninstall', '-Commands', 'fix') | Out-Null
    Check ((Test-Path "$c\skills\fix\notes.txt") -and -not (Test-Path "$c\skills\fix\SKILL.md")) 'посторонние файлы в папке команды сохраняются'

    # Повреждённый mcp_config.json
    $h = NewHome 'broken'; $c = Cfg $h
    New-Item -ItemType Directory -Force $c | Out-Null; [IO.File]::WriteAllText("$c\mcp_config.json", '{ broken', $Utf8)
    $r = Run $h @('-Mcp', 'context7')
    Check ($r.Code -eq 1 -and [IO.File]::ReadAllText("$c\mcp_config.json") -eq '{ broken') 'повреждённый JSON не перезаписывается'

    # Выбор по именам
    $h = NewHome 'pick'; $c = Cfg $h
    $r = Run $h @('-Commands', '/handoff,resume', '-Rules', 'memory')
    Check ((Test-Path "$c\skills\handoff") -and (Test-Path "$c\skills\resume") -and -not (Test-Path "$c\skills\fix") -and (Test-Path "$c\rules\antigravity-toolkit-memory.md") -and -not (Test-Path "$c\mcp_config.json")) 'ставится только выбранное'
    $r = Run $h @('-Commands', 'nope')
    Check ($r.Code -eq 1 -and $r.Out -match 'неизвестная позиция') 'неизвестное имя — ошибка'
} finally {
    Remove-Item -LiteralPath $Work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output "Пройдено: $script:Pass, провалено: $script:Fail"
if ($script:Fail) { exit 1 }
