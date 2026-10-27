# Контекст для Claude

Проект **Antigravity Toolkit** — набор улучшений для агента в Antigravity App: слэш-команды (skills), пресеты правил и MCP-серверы, упакованные в один штатный плагин Antigravity. Общение с владельцем — на русском. Вопросы и предложения владельцу задавай с вариантами ответа. Прочитай этот файл, затем `README.md` и `docs/PLAN.md`.

## Связь с русификатором

Это **отдельный** проект от Antigravity Russian (`C:\Users\zikri\Desktop\AntigravityRussian`, https://github.com/ZakitKH0000/antigravity-russian). Русификатор меняет только `resources/app.asar`, анлокер региона (https://github.com/confeden/Antigravity) — `language_server`/`agy`, NRPT и свою службу. Toolkit не трогает ни то, ни другое: он пишет только в папку своего плагина в `~/.gemini/config/plugins/antigravity-toolkit/`. Правило языка русификатора (`~/.gemini/config/rules/antigravity-russian.md`) не трогаем и не дублируем.

## Главные правила

1. Пишем только в папку своего плагина. Владение подтверждается маркером `.antigravity-toolkit` внутри неё; без маркера папку не перезаписываем и не удаляем.
2. Глобальные `~/.gemini/config/mcp_config.json`, `config.json`, `rules/` пользователя не изменяем. Включение/выключение плагина — штатный переключатель Antigravity (запись в `config.json` делает сам Antigravity).
3. Не меняем EXE, Language Server, `app.asar`, DNS, прокси и настройки безопасности.
4. Токены и ключи MCP не попадают в Git, логи и отчёты. Ключи вводит сам пользователь.
5. Не завершаем Antigravity принудительно.
6. Не обещаем совместимость со всеми будущими версиями: форматы плагинов взяты из встроенного skill `agy-customizations` Antigravity 2.26 и могут измениться.

## Технологии (план)

Установщик — как у русификатора: C# **5**, WinForms, .NET Framework **4.8**, x64, штатный `csc.exe`, Windows PowerShell **5.1**. Поставка — один EXE. Пока установщика нет: готов только сам плагин в `plugin/`.

Claude Desktop — MSIX: файлы в `%LOCALAPPDATA%`, созданные командами Claude, не видны программам пользователя. `~/.gemini` лежит в профиле, а не в `%LOCALAPPDATA%`, но итоговую установку всё равно проверяет владелец запуском.
