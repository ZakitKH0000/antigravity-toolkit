# План и факты

## Что известно об Antigravity 2.26

Источник: встроенный skill `agy-customizations` (`~/.gemini/antigravity/builtin/skills/agy-customizations/`) и проверка владельцем.

- **Отдельные команды (skills)** — `~/.gemini/config/skills/<имя>/SKILL.md` с frontmatter `name` и `description`. Вызываются `/<имя>`, агент может выбрать их и сам. **Проверено: работает** после перезапуска.
- **Плагины** — по документации `plugins/<имя>/plugin.json` + `skills/`, `rules/`, `mcp_config.json`, `hooks.json`. **Проверено: папка, просто скопированная в `~/.gemini/config/plugins/`, не подхватывается.** Плагины Google установлены из каталога и записаны в `config.json` (`plugins.<имя>.installedFrom`). Поэтому пока используем отдельные команды и правила.
- **Workflows устарели**, вместо них skills.
- **Правила:** глобальные — `~/.gemini/config/rules/*.md` (frontmatter `trigger: always_on` или `model_decision`), так уже работает правило языка русификатора. Always-on и глобальные правила делят 20 000 токенов; файл — до 24 000 байт. Лишние понижаются до ссылки на файл.
- **Skills загружаются постепенно:** в контексте только имя и описание, тело — при вызове. Объёмные инструкции оформляем skills, правила держим короткими.
- **MCP:** глобальный `~/.gemini/config/mcp_config.json` → `mcpServers`; stdio (`command`, `args`, `env`) или Streamable HTTP (`url`). Legacy SSE не поддерживается. У владельца файл пока пустой. Запись в него требует согласования.
- Размер окна контекста модели задаёт сервер — увеличить его клиентом нельзя. Помогают: `/handoff` + `/resume`, короткие правила, skills вместо длинных правил, `AGENTS.md` в проекте.

## Этапы

1. ~~Команды~~ — `handoff`, `resume`, `review`, `commit`, `fix`, `explain` в `skills/`. Видны в меню «/» (проверено владельцем).
2. ~~Проверка в чате~~ — `/handoff` → новый чат → `/resume` и `/explain` работают (проверено владельцем 2026-10-27). `/review`, `/commit`, `/fix` в чате ещё не проверялись.
3. ~~Правила~~ — `rules/antigravity-toolkit-{context-economy,confirm-destructive,code-style}.md` с `trigger` и маркером; установлены у владельца 2026-10-27 (~5 КБ). Проверено владельцем: агент спрашивает подтверждение перед удалением и перечисляет эти правила.
4. **Установка агентом** (вместо EXE, по решению владельца): `INSTALL-AGENT.md` + `install.ps1` (`-List`, `-All`, выбор позиций, `-Update`, `-Uninstall`). 34 проверки в `tests/Test-Install.ps1` проходят; `-List` на реальном профиле владельца видит всё установленным. Осталось: проверить установку агентом по ссылке в живом Antigravity.
5. ~~MCP~~ — проверено владельцем: все четыре сервера подключились и работают в чате. Владелец выбрал context7, deepwiki, microsoft-learn (удалённые, без ключа, отвечают на `initialize` с его компьютера) и memory (`npx @modelcontextprotocol/server-memory`, файл `~/.gemini/antigravity-toolkit/memory.jsonl`). 2026-10-27 записаны в пустой `mcp_config.json` владельца с его согласия; пример — `mcp/mcp_config.example.json`. GitHub MCP (`https://api.githubcopilot.com/mcp/`) требует токен — не подключали. Antigravity понимает поля `url`/`serverUrl`, `headers`, `disabled`, `disabledTools`, `env`, `cwd`. Установщик должен дописывать `mcpServers`, не трогая чужие записи, и писать UTF-8 без BOM.
5a. ~~Правило памяти~~ — `rules/antigravity-toolkit-memory.md` (always_on): поиск через `search_nodes`/`open_nodes` в начале задачи, запись предпочтений, решений и исправлений через `add_observations`, без секретов. Названия инструментов сверены с `@modelcontextprotocol/server-memory` 2.0.0. Установлено у владельца 2026-10-27. Проверено владельцем: агент сам записал факт и вспомнил его в новом чате.
6. Автопроверки (`Build.ps1 -Test`), GitHub Actions, первый релиз.
