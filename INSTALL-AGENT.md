# Установка Antigravity Toolkit — инструкция для агента

Этот файл написан для агента Antigravity. Пользователь прислал ссылку на репозиторий https://github.com/ZakitKH0000/antigravity-toolkit и хочет, чтобы ты установил, обновил или удалил улучшения. Общайся с пользователем на его языке, коротко и понятно.

## Что ставится

| Группа | Позиции | Куда |
| --- | --- | --- |
| Команды (вызываются в чате через `/`) | `handoff`, `resume`, `review`, `commit`, `fix`, `explain` | `%USERPROFILE%\.gemini\config\skills\<имя>\` |
| Правила (действуют во всех чатах) | `context-economy`, `confirm-destructive`, `code-style`, `memory` | `%USERPROFILE%\.gemini\config\rules\antigravity-toolkit-<имя>.md` |
| MCP-серверы | `context7`, `deepwiki`, `microsoft-learn`, `memory` (нужен Node.js) | записи в `%USERPROFILE%\.gemini\config\mcp_config.json` |

Установщик `install.ps1` меняет только свои файлы и записи. Чужие файлы и серверы с такими же именами он пропускает, перед изменением `mcp_config.json` делает резервную копию. Ничего не меняется в самом Antigravity, его программе, `app.asar`, сети и системных настройках.

Работает только в Windows. На macOS и Linux скажи пользователю, что установщик пока только для Windows.

## Шаги

Не правь файлы настроек вручную — всё делает `install.ps1`.

1. **Скачай репозиторий** во временную папку. Если есть `git`:
   ```powershell
   $dir = Join-Path $env:TEMP 'antigravity-toolkit'
   if (Test-Path "$dir\.git") { git -C $dir pull --ff-only } else { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue; git clone --depth 1 https://github.com/ZakitKH0000/antigravity-toolkit $dir }
   ```
   Если `git` нет:
   ```powershell
   $dir = Join-Path $env:TEMP 'antigravity-toolkit'; $zip = "$dir.zip"
   Invoke-WebRequest https://github.com/ZakitKH0000/antigravity-toolkit/archive/refs/heads/main.zip -OutFile $zip -UseBasicParsing
   Remove-Item $dir, "$dir-main" -Recurse -Force -ErrorAction SilentlyContinue
   Expand-Archive $zip $env:TEMP -Force; Rename-Item "$env:TEMP\antigravity-toolkit-main" $dir; Remove-Item $zip
   ```

2. **Покажи, что уже установлено:**
   ```powershell
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\antigravity-toolkit\install.ps1" -List
   ```

3. **Спроси пользователя, что установить**, перечислив позиции с кратким описанием из таблицы выше. По умолчанию предлагай всё. Предупреди, что каждый MCP-сервер немного занимает контекст, а `memory` требует Node.js. Дождись ответа — не устанавливай без согласия.

4. **Установи выбранное** (пример; подставь выбор пользователя или используй `-All`):
   ```powershell
   powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\antigravity-toolkit\install.ps1" -Commands handoff,resume,review -Rules context-economy,confirm-destructive -Mcp context7,deepwiki
   ```

5. **Сообщи результат** по строкам вывода: `[установлено]`, `[обновлено]`, `[пропуск]` (с причиной), `[ошибка]`. Если код выхода не 0 — покажи пользователю ошибки как есть и не пытайся обойти их ручной правкой файлов.

6. **Скажи пользователю перезапустить Antigravity** — команды, правила и MCP подхватываются после перезапуска. Затем предложи попробовать, например, `/explain` в любом проекте.

## Обновление и удаление

- Обновить установленное до последней версии: шаг 1, затем `install.ps1 -Update`.
- Удалить: шаг 1, затем `install.ps1 -Uninstall -All` (или конкретные позиции через `-Commands`, `-Rules`, `-Mcp`). Перед удалением спроси подтверждение. Файл памяти агента (`%USERPROFILE%\.gemini\antigravity-toolkit\memory.jsonl`) при удалении сохраняется — если пользователь хочет удалить и его, удали этот файл отдельно после явного согласия.
- Если удаление команды сообщает, что папку держит Antigravity, — попроси пользователя закрыть Antigravity и выполнить удаление ещё раз из другого окна PowerShell, либо после перезапуска.
