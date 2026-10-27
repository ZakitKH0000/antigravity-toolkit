# Antigravity Toolkit: установка команд, правил и MCP-серверов для агента Antigravity.
# Пишет только свои файлы: папки команд с маркером .antigravity-toolkit, файлы правил с маркером
# <!-- antigravity-toolkit:...> и записи mcpServers, указывающие на наши серверы. Чужое не трогает.
#
#   install.ps1 -List                       показать, что установлено
#   install.ps1 -All                        установить всё
#   install.ps1 -Commands handoff,resume -Rules memory -Mcp context7,memory
#   install.ps1 -Update                     обновить уже установленное
#   install.ps1 -Uninstall -All             удалить всё своё (файл памяти агента сохраняется)
param(
    [string[]]$Commands,
    [string[]]$Rules,
    [string[]]$Mcp,
    [switch]$All,
    [switch]$List,
    [switch]$Update,
    [switch]$Uninstall,
    [string]$HomeDir = $env:USERPROFILE
)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$CommandMarker = '.antigravity-toolkit'
$RuleMarker = '<!-- antigravity-toolkit:'
$Config = Join-Path $HomeDir '.gemini\config'
$SkillsDir = Join-Path $Config 'skills'
$RulesDir = Join-Path $Config 'rules'
$McpFile = Join-Path $Config 'mcp_config.json'
$DataDir = Join-Path $HomeDir '.gemini\antigravity-toolkit'
$McpCatalog = [ordered]@{
    'context7'        = @{ Title = 'Context7 — документация библиотек'; Url = 'https://mcp.context7.com/mcp' }
    'deepwiki'        = @{ Title = 'DeepWiki — ответы по репозиториям GitHub'; Url = 'https://mcp.deepwiki.com/mcp' }
    'microsoft-learn' = @{ Title = 'Microsoft Learn — документация C#, .NET, Windows'; Url = 'https://learn.microsoft.com/api/mcp' }
    'memory'          = @{ Title = 'Память агента между чатами (нужен Node.js)'; Package = '@modelcontextprotocol/server-memory' }
}
$script:Errors = 0

# Write-Host, а не Write-Output: сообщения не должны попадать в возвращаемые значения функций.
function Say([string]$Status, [string]$Text) { Write-Host ('[' + $Status + '] ' + $Text) }
function Fail([string]$Text) { $script:Errors++; Say 'ошибка' $Text }

function Write-Atomic([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    $temp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($temp, $Text, $Utf8)
        # [NullString]::Value: обычный $null PowerShell передал бы в .NET как пустую строку.
        if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp, $Path, [NullString]::Value) } else { [IO.File]::Move($temp, $Path) }
    } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force } }
}
function Read-Text([string]$Path) { [IO.File]::ReadAllText($Path, $Utf8) }

# ---------- Каталог из папок репозитория ----------
$AllCommands = @(Get-ChildItem -LiteralPath (Join-Path $Root 'skills') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } | ForEach-Object Name)
$AllRules = @(Get-ChildItem -LiteralPath (Join-Path $Root 'rules') -Filter 'antigravity-toolkit-*.md' | ForEach-Object { $_.BaseName.Substring('antigravity-toolkit-'.Length) })
$AllMcp = @($McpCatalog.Keys)

function Resolve-Ids([string[]]$Requested, [string[]]$Known, [string]$Kind) {
    if ($All) { return $Known }
    $result = @()
    foreach ($id in @($Requested | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().TrimStart('/') } | Where-Object { $_ })) {
        if ($Known -contains $id) { $result += $id } else { Fail ("неизвестная позиция «$id» ($Kind). Доступно: " + ($Known -join ', ')) }
    }
    return $result
}

# ---------- Команды (skills) ----------
function Command-State([string]$Id) {
    $dir = Join-Path $SkillsDir $Id
    if (-not (Test-Path -LiteralPath $dir)) { return 'не установлено' }
    if (-not (Test-Path -LiteralPath (Join-Path $dir $CommandMarker))) { return 'занято' }
    $src = Read-Text (Join-Path $Root "skills\$Id\SKILL.md")
    $dst = Join-Path $dir 'SKILL.md'
    if ((Test-Path -LiteralPath $dst) -and (Read-Text $dst) -eq $src) { return 'установлено' }
    return 'есть обновление'
}
function Install-Command([string]$Id) {
    $state = Command-State $Id
    if ($state -eq 'занято') { Say 'пропуск' "команда /$Id — уже есть ваша папка $SkillsDir\$Id, она не изменена"; return }
    if ($state -eq 'установлено') { Say 'без изменений' "команда /$Id"; return }
    $dir = Join-Path $SkillsDir $Id
    Write-Atomic (Join-Path $dir 'SKILL.md') (Read-Text (Join-Path $Root "skills\$Id\SKILL.md"))
    Write-Atomic (Join-Path $dir $CommandMarker) "Установлено Antigravity Toolkit. Установщик меняет и удаляет эту папку только при наличии этого файла.`n"
    Say $(if ($state -eq 'есть обновление') { 'обновлено' } else { 'установлено' }) "команда /$Id"
}
function Remove-Command([string]$Id) {
    $dir = Join-Path $SkillsDir $Id
    $state = Command-State $Id
    if ($state -eq 'не установлено') { Say 'без изменений' "команда /$Id не установлена"; return }
    if ($state -eq 'занято') { Say 'пропуск' "команда /$Id — папка не наша, не удалена"; return }
    try {
        Remove-Item -LiteralPath (Join-Path $dir 'SKILL.md') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $dir $CommandMarker) -Force
        if (-not (Get-ChildItem -LiteralPath $dir -Force)) { Remove-Item -LiteralPath $dir -Force }
        Say 'удалено' "команда /$Id"
    } catch { Fail "команда /$Id не удалена: папку держит Antigravity. Закройте Antigravity и повторите." }
}

# ---------- Правила ----------
function Rule-Path([string]$Id) { Join-Path $RulesDir "antigravity-toolkit-$Id.md" }
function Rule-State([string]$Id) {
    $dst = Rule-Path $Id
    if (-not (Test-Path -LiteralPath $dst)) { return 'не установлено' }
    $text = Read-Text $dst
    if (-not $text.Contains($RuleMarker)) { return 'занято' }
    if ($text -eq (Read-Text (Join-Path $Root "rules\antigravity-toolkit-$Id.md"))) { return 'установлено' }
    return 'есть обновление'
}
function Install-Rule([string]$Id) {
    $state = Rule-State $Id
    if ($state -eq 'занято') { Say 'пропуск' "правило $Id — уже есть ваш файл с таким именем, он не изменён"; return }
    if ($state -eq 'установлено') { Say 'без изменений' "правило $Id"; return }
    Write-Atomic (Rule-Path $Id) (Read-Text (Join-Path $Root "rules\antigravity-toolkit-$Id.md"))
    Say $(if ($state -eq 'есть обновление') { 'обновлено' } else { 'установлено' }) "правило $Id"
}
function Remove-Rule([string]$Id) {
    $state = Rule-State $Id
    if ($state -eq 'не установлено') { Say 'без изменений' "правило $Id не установлено"; return }
    if ($state -eq 'занято') { Say 'пропуск' "правило $Id — файл не наш, не удалён"; return }
    Remove-Item -LiteralPath (Rule-Path $Id) -Force
    Say 'удалено' "правило $Id"
}

# ---------- MCP ----------
Add-Type -AssemblyName System.Web.Extensions
function Read-McpConfig {
    if (-not (Test-Path -LiteralPath $McpFile)) { return New-Object 'System.Collections.Generic.Dictionary[string,object]' }
    $text = Read-Text $McpFile
    if (-not $text.Trim()) { return New-Object 'System.Collections.Generic.Dictionary[string,object]' }
    $parsed = (New-Object System.Web.Script.Serialization.JavaScriptSerializer).DeserializeObject($text)
    if (-not ($parsed -is [System.Collections.Generic.IDictionary[string,object]])) { throw 'в mcp_config.json не объект JSON' }
    return $parsed
}
function Get-Servers($Cfg) {
    if (-not $Cfg.ContainsKey('mcpServers') -or $null -eq $Cfg['mcpServers']) { $Cfg['mcpServers'] = New-Object 'System.Collections.Generic.Dictionary[string,object]' }
    if (-not ($Cfg['mcpServers'] -is [System.Collections.Generic.IDictionary[string,object]])) { throw 'в mcp_config.json поле mcpServers не объект' }
    return $Cfg['mcpServers']
}
function Is-OurServer([string]$Id, $Entry) {
    if (-not ($Entry -is [System.Collections.Generic.IDictionary[string,object]])) { return $false }
    $def = $McpCatalog[$Id]
    if ($def.Url) { return ($Entry['serverUrl'] -eq $def.Url) -or ($Entry['url'] -eq $def.Url) }
    $cmd = [string]$Entry['command']
    return ($cmd -match '^npx(\.cmd)?$') -and (@($Entry['args']) -contains $def.Package)
}
function New-ServerEntry([string]$Id, $Old) {
    $def = $McpCatalog[$Id]
    $e = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    if ($def.Url) { $e['serverUrl'] = $def.Url; return $e }
    $e['command'] = 'npx'
    $e['args'] = [string[]]@('-y', $def.Package)
    $memory = ($DataDir -replace '\\', '/') + '/memory.jsonl'
    # Свой путь к файлу памяти, если пользователь его менял, сохраняем.
    if ($Old -and $Old['env'] -is [System.Collections.Generic.IDictionary[string,object]] -and $Old['env']['MEMORY_FILE_PATH']) { $memory = $Old['env']['MEMORY_FILE_PATH'] }
    $vars = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    $vars['MEMORY_FILE_PATH'] = $memory
    $e['env'] = $vars
    return $e
}
function Same-Json($A, $B) { return (ConvertTo-PrettyJson $A) -eq (ConvertTo-PrettyJson $B) }
function Mcp-State($Servers, [string]$Id) {
    if ($McpCatalog[$Id].Package -and -not (Get-Command npx -ErrorAction SilentlyContinue)) { $node = $false } else { $node = $true }
    if (-not $Servers.ContainsKey($Id)) { if ($node) { return 'не установлено' } else { return 'нужен Node.js' } }
    if (-not (Is-OurServer $Id $Servers[$Id])) { return 'занято' }
    if (Same-Json $Servers[$Id] (New-ServerEntry $Id $Servers[$Id])) { return 'установлено' }
    return 'есть обновление'
}

function ConvertTo-PrettyJson($Value, [int]$Level = 0) {
    $pad = '  ' * ($Level + 1); $end = '  ' * $Level
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) { return (New-Object System.Web.Script.Serialization.JavaScriptSerializer).Serialize([string]$Value) }
    if ($Value -is [bool]) { if ($Value) { return 'true' } else { return 'false' } }
    if ($Value -is [System.Collections.IDictionary]) {
        if ($Value.Count -eq 0) { return '{}' }
        $parts = foreach ($k in $Value.Keys) { $pad + (ConvertTo-PrettyJson ([string]$k)) + ': ' + (ConvertTo-PrettyJson $Value[$k] ($Level + 1)) }
        return "{`n" + ($parts -join ",`n") + "`n$end}"
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @($Value)
        if ($items.Count -eq 0) { return '[]' }
        $parts = foreach ($i in $items) { $pad + (ConvertTo-PrettyJson $i ($Level + 1)) }
        return "[`n" + ($parts -join ",`n") + "`n$end]"
    }
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant()
}

function Apply-Mcp([string[]]$Ids, [bool]$Remove) {
    if (-not $Ids) { return }
    try { $cfg = Read-McpConfig; $servers = Get-Servers $cfg }
    catch { Fail ("MCP не изменены: файл $McpFile не удалось прочитать как JSON. Исправьте его или покажите пользователю. " + $_.Exception.Message); return }
    $changed = $false
    foreach ($id in $Ids) {
        $state = Mcp-State $servers $id
        if ($Remove) {
            if ($state -eq 'установлено' -or $state -eq 'есть обновление') { [void]$servers.Remove($id); $changed = $true; Say 'удалено' "MCP $id" }
            elseif ($state -eq 'занято') { Say 'пропуск' "MCP $id — запись не наша, не удалена" }
            else { Say 'без изменений' "MCP $id не установлен" }
            continue
        }
        switch ($state) {
            'занято' { Say 'пропуск' "MCP $id — в mcp_config.json уже есть ваша запись с таким именем, она не изменена" }
            'нужен Node.js' { Say 'пропуск' "MCP $id — нужен Node.js (https://nodejs.org), установите его и повторите" }
            'установлено' { Say 'без изменений' "MCP $id" }
            default {
                $servers[$id] = New-ServerEntry $id $(if ($servers.ContainsKey($id)) { $servers[$id] } else { $null })
                $changed = $true
                Say $(if ($state -eq 'есть обновление') { 'обновлено' } else { 'установлено' }) "MCP $id"
            }
        }
    }
    if (-not $changed) { return }
    if ((Test-Path -LiteralPath $McpFile) -and (Read-Text $McpFile).Trim()) {
        $backup = Join-Path $DataDir ('backups\mcp_config-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
        New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
        Copy-Item -LiteralPath $McpFile -Destination $backup
        Say 'копия' "прежний mcp_config.json сохранён в $backup"
    }
    Write-Atomic $McpFile ((ConvertTo-PrettyJson $cfg) + "`n")
}

# ---------- Запуск ----------
if (-not (Test-Path -LiteralPath (Join-Path $Root 'skills')) -or -not (Test-Path -LiteralPath (Join-Path $Root 'rules'))) { throw 'Скрипт нужно запускать из папки репозитория antigravity-toolkit (рядом должны быть skills и rules).' }

if ($List -or -not ($All -or $Update -or $Commands -or $Rules -or $Mcp)) {
    Write-Output 'Команды (вызываются в чате через /):'
    foreach ($id in $AllCommands) { Write-Output ("  /{0,-10} {1}" -f $id, (Command-State $id)) }
    Write-Output 'Правила (действуют во всех чатах):'
    foreach ($id in $AllRules) { Write-Output ("  {0,-20} {1}" -f $id, (Rule-State $id)) }
    Write-Output 'MCP-серверы:'
    try { $servers = Get-Servers (Read-McpConfig); foreach ($id in $AllMcp) { Write-Output ("  {0,-16} {1,-15} {2}" -f $id, (Mcp-State $servers $id), $McpCatalog[$id].Title) } }
    catch { Write-Output "  mcp_config.json не читается как JSON: $($_.Exception.Message)" }
    exit 0
}

if ($Update) {
    $cmdIds = @($AllCommands | Where-Object { (Command-State $_) -eq 'есть обновление' })
    $ruleIds = @($AllRules | Where-Object { (Rule-State $_) -eq 'есть обновление' })
    try { $servers = Get-Servers (Read-McpConfig); $mcpIds = @($AllMcp | Where-Object { (Mcp-State $servers $_) -eq 'есть обновление' }) } catch { $mcpIds = @() }
    if (-not ($cmdIds + $ruleIds + $mcpIds)) { Say 'без изменений' 'всё установленное уже актуально' }
} else {
    $cmdIds = Resolve-Ids $Commands $AllCommands 'команды'
    $ruleIds = Resolve-Ids $Rules $AllRules 'правила'
    $mcpIds = Resolve-Ids $Mcp $AllMcp 'MCP'
}

foreach ($id in $cmdIds) { if ($Uninstall) { Remove-Command $id } else { Install-Command $id } }
foreach ($id in $ruleIds) { if ($Uninstall) { Remove-Rule $id } else { Install-Rule $id } }
Apply-Mcp $mcpIds ([bool]$Uninstall)
if ($Uninstall -and ($mcpIds -contains 'memory')) { Say 'сохранено' "файл памяти агента не удалялся: $DataDir\memory.jsonl" }

Write-Output ''
if ($script:Errors) { Write-Output "Готово с ошибками: $script:Errors. Изменения вступят в силу после перезапуска Antigravity."; exit 1 }
Write-Output 'Готово. Изменения вступят в силу после перезапуска Antigravity.'
