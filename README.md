<img align="right" src="https://github.com/pixel-quest/pixel-games/raw/main/logo.png" height="200">

# 🕹 Игры [Pixel Quest](https://pixelquest.ru)

Репозиторий содержит исходный код игр проекта [Pixel Quest](https://pixelquest.ru), написанных на языке Lua.
Здесь представлены исходники не всех игр проекта, часть игр по-прежнему написана на Go и со временем будет также перенесена на Lua.

**Шаблон скрипта с подробными комментариями – [template.lua](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua)**

Скрипты обслуживаются виртуальной машиной [GopherLua](https://github.com/yuin/gopher-lua), написанной на языке Go.  
На момент февраля 2024 г. используется **GopherLua v1.1.1** (Lua5.1 + оператор goto из Lua5.2).

### Список текущих механик Pixel Quest:
- Заставка **Радуга** (Lua) – *переливающийся пол* [rainbow_v1.lua](https://github.com/pixel-quest/pixel-games/blob/main/rainbow_v1/rainbow_v1.lua)
- Заставка **Круги на воде** (Go) – *расходящиеся круги от шагов*
- Заставка **Марио** (Go) – *рисунок Марио во весь пол с переливающимся фоном*
- **Пиксель дуэль** (Lua) – *собираем свой цвет быстрее соперника* [pixel_duel_v1.lua](https://github.com/pixel-quest/pixel-games/blob/main/pixel_duel_v1/pixel_duel_v1.lua)
- **Море волнуется** (Go) – *соревнуемся и собираем на цветном поле свой цвет* (в процессе переписывания на Lua)
- **Найди цвет** (Go) – *на разноцветном поле требуется найти нужный цвет* (в процессе переписывания на Lua)
- **Пол – это лава** (Go) – *собираем синие, избегая лавы (самая жирная и тяжёлая механика, под неё имеется конструктор уровней)*
- **Перебежка** (Go) – *бегаем от кнопки к кнопке, перепрыгивая полоску лавы*
- **Безопасный цвет** (Go) – *нужно успеть встать на безопасный цвет, прежде чем поле загорится красным*
- **Классики** (Go) – *классики 3х6*

### Приоритетная очередь механик на разработку:
- **Танцы** – *ловим пиксели под веселую корейскую музыку*
- **Черепашьи бега** – *игроки быстро попеременно нажимают на пиксели, а на экране бегут черепашки*
- **Лава дуэль** – *игровое поле поделено на зоны, где отдельные игроки соревнуются на скорость*
- **Змейка** – *аналог Пиксель дуэли против компьютерной змейки*
- **Повтори рисунок** – *нужно на скорость нарисовать рисунок по шаблону* 
- **Вирус** – *игроки захватывают поле своим цветом*
- **Пакман** – *собираем синие в лабиринте с бегающим красным пикселем*
- **Арканоид** – *платформой отбиваем мячик, выбивая блоки на противоположной стороне*
- **Пинг-понг** – *платформами отбиваем мячик друг другу*
- **Классики-эстафета** – *игроки делятся на команды и проходят классики на скорость в виде эстафеты*

### Базовая структура Lua скрипта:
- Таблица [GameObj](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L44)  – заполняется из Game Json, должна обязательно содержать поля Cols x Rows для задания размера пола
- Таблица [GameConfigObj](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L51) – заполняется из Config Json, настройки игры перед стартом (сложность, скорость, очки, жизни и т.д)
- Таблица [GameStats](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L55) – информация для отображения на табло (время, жизни, очки, цвета)
- Таблица [GameResults](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L75) – результат завершения игры, возвращается в последнем вздохе NextTick()
- **Обязательные функции:**
  - [StartGame(gameJson, gameConfigJson)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L90) – инициализация игры, на входе Game Json и Config Json
  - [NextTick()](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L111) – тик игрового мира, здесь вся основная логика
  - [RangeFloor(setPixel, setButton)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L122) – забор снапшота пола, вызывается следом за NextTick()
  - [GetStats()](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L136) – забор статистики игры, вызывается следом за RangeFloor()
  - [PauseGame()](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L141) – событие паузы игры
  - [ResumeGame()](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L145) – событие снятия игры с паузы
  - [SwitchStage()](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L150) – рычаг админа для переключения этапа, может быть полезен в некоторых играх
  - [PixelClick(click)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L162) – событие клика/отпускания пикселя
  - [ButtonClick(click)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L173) – событие клика/отпускания кнопки
  - [DefectPixel(defect)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L186) – событие дефектовки/раздефектовки пикселя
  - [DefectButton(defect)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L198) – событие дефектовки/радефектовки кнопки
- **Вспомогательные функции:**
  - [shallowCopy(t)](https://github.com/pixel-quest/pixel-games/blob/main/template/template.lua#L205) – неглубокое копирование таблиц, полезно для заполнения матрицы пола
