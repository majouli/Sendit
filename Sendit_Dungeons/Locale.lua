--[[
  Locale: UI texts in five languages (dungeon and boss names come from the client).
]]
local _, ns = ...
local keys = {
    "subtitle", "search", "page", "pageDesc", "open", "empty", "pick",
    "levels", "levelUnknown", "players", "raid", "dungeon", "bosses", "lootUnknown",
    "filterAll", "filterFits", "filterDungeons", "filterRaids",
    "boost", "boostHelp", "boostNeedsUpgrade", "boostOff", "boostAt", "boostOn", "boostAgain", "stale",
    "boostRating", "boostCount", "boostCountOne", "boostEmpty", "upgrades", "chance", "detailVs", "decimal",
    "resize", "fitsYou", "aboveYou", "belowYou", "worldOnly",
    "ahead", "aheadStandard", "aheadPlus", "aheadAll", "aheadHelp", "fromLevel", "worldBosses", "openWorld",
}
local rows = {
    enUS = {
        "Dungeons, bosses, loot", "Dungeon or boss…", "Dungeon browser",
        "Dungeons, their bosses and what they drop, in a separate window - with the gear boost.", "Open",
        "No dungeon found.", "Pick a dungeon on the left.",
        "Level %d-%d", "Level ?", "%d players", "Raid", "Dungeon", "%d bosses",
        "Loot unknown - no data for this boss yet (Forever's own boss or changed)",
        "All", "For my level", "Dungeons", "Raids",
        "Gear boost", "Dungeons whose bosses drop an item that makes your character stronger (Sendit Upgrade, %s), the biggest gain first - the same number as Upgrade's item tooltip.",
        "Needs Sendit: Upgrade (switched on).", "Off", "at least %s %%", "Boost ≥ %s %%", "Rate again", "stale",
        "rating %d / %d …", "%d dungeons with at least %s %% upgrade", "%d dungeon with at least %s %% upgrade",
        "No dungeon you can enter drops an upgrade of at least %s %%.", "%d upgrades", "%s %% drop chance",
        "Your whole character's %s with this item instead of your worn one - the same number as Sendit Upgrade's item tooltip.",
        ".", "Drag to resize", "your level", "above your level", "below your level", "No drops of its own - only world drops (random green items)", "Range", "Standard (your level)", "up to %d levels above", "All levels", "Standard: only dungeons you can enter and items you can wear now. A preview also shows higher dungeons and items: what they would give your character as it is today.", "from level %d", "World bosses", "Open world",
    },
    deDE = {
        "Dungeons, Bosse, Beute", "Dungeon oder Boss…", "Dungeon-Browser",
        "Dungeons, ihre Bosse und was sie fallen lassen, in einem eigenen Fenster - mit Gear-Boost.", "Öffnen",
        "Kein Dungeon gefunden.", "Wähle links einen Dungeon.",
        "Stufe %d-%d", "Stufe ?", "%d Spieler", "Schlachtzug", "Dungeon", "%d Bosse",
        "Beute unbekannt - für diesen Boss gibt es noch keine Daten (Forever-eigener oder geänderter Boss)",
        "Alle", "Für meine Stufe", "Dungeons", "Schlachtzüge",
        "Gear-Boost", "Dungeons, deren Bosse ein Teil fallen lassen, das deinen Charakter stärker macht (Sendit Upgrade, %s), größter Gewinn zuerst - dieselbe Zahl wie im Item-Tooltip von Upgrade.",
        "Benötigt Sendit: Upgrade (eingeschaltet).", "Aus", "mindestens %s %%", "Boost ≥ %s %%", "Neu bewerten", "veraltet",
        "bewerte %d / %d …", "%d Dungeons mit mindestens %s %% Upgrade", "%d Dungeon mit mindestens %s %% Upgrade",
        "Kein Dungeon, den du betreten kannst, bringt mindestens %s %% Upgrade.", "%d Upgrades", "%s %% Dropchance",
        "%s deines ganzen Charakters mit diesem Teil statt deinem getragenen - dieselbe Zahl wie im Item-Tooltip von Sendit Upgrade.",
        ",", "Ziehen zum Ändern der Größe", "deine Stufe", "über deiner Stufe", "unter deiner Stufe", "Keine eigene Beute - nur Welt-Drops (zufällige grüne Items)", "Reichweite", "Standard (deine Stufe)", "bis %d Stufen über dir", "Alle Stufen", "Standard: nur Dungeons, die du betreten, und Items, die du tragen kannst. Die Vorschau zeigt auch höhere Dungeons und Items: was sie deinem Charakter so, wie er heute ist, bringen würden.", "ab Stufe %d", "Weltbosse", "Offene Welt",
    },
    frFR = {
        "Donjons, boss, butin", "Donjon ou boss…", "Navigateur de donjons",
        "Les donjons, leurs boss et leur butin, dans une fenêtre à part - avec le boost d'équipement.", "Ouvrir",
        "Aucun donjon trouvé.", "Choisissez un donjon à gauche.",
        "Niveau %d-%d", "Niveau ?", "%d joueurs", "Raid", "Donjon", "%d boss",
        "Butin inconnu - pas encore de données pour ce boss (boss propre à Forever ou modifié)",
        "Tous", "Pour mon niveau", "Donjons", "Raids",
        "Boost d'équipement", "Donjons dont un boss lâche un objet qui rend votre personnage plus fort (Sendit Upgrade, %s), le plus grand gain d'abord - le même nombre que l'infobulle d'Upgrade.",
        "Nécessite Sendit : Upgrade (activé).", "Arrêt", "au moins %s %%", "Boost ≥ %s %%", "Réévaluer", "obsolète",
        "évaluation %d / %d …", "%d donjons avec au moins %s %% d'amélioration", "%d donjon avec au moins %s %% d'amélioration",
        "Aucun donjon accessible n'apporte au moins %s %%.", "%d améliorations", "%s %% de chance",
        "%s de tout votre personnage avec cet objet au lieu de celui porté - le même nombre que l'infobulle de Sendit Upgrade.",
        ",", "Glisser pour redimensionner", "votre niveau", "au-dessus de votre niveau", "sous votre niveau", "Pas de butin propre - seulement des objets mondiaux (verts aléatoires)", "Portée", "Standard (votre niveau)", "jusqu'à %d niveaux au-dessus", "Tous les niveaux", "Standard : seulement les donjons accessibles et les objets portables maintenant. L'aperçu montre aussi les donjons et objets plus élevés : ce qu'ils apporteraient à votre personnage tel qu'il est aujourd'hui.", "dès le niveau %d", "Boss mondiaux", "Monde ouvert",
    },
    esES = {
        "Mazmorras, jefes, botín", "Mazmorra o jefe…", "Explorador de mazmorras",
        "Las mazmorras, sus jefes y lo que sueltan, en una ventana aparte - con el impulso de equipo.", "Abrir",
        "No se encontró ninguna mazmorra.", "Elige una mazmorra a la izquierda.",
        "Nivel %d-%d", "Nivel ?", "%d jugadores", "Banda", "Mazmorra", "%d jefes",
        "Botín desconocido - aún no hay datos de este jefe (jefe propio de Forever o cambiado)",
        "Todas", "Para mi nivel", "Mazmorras", "Bandas",
        "Impulso de equipo", "Mazmorras cuyos jefes sueltan un objeto que hace más fuerte a tu personaje (Sendit Upgrade, %s), la mayor mejora primero - el mismo número que la descripción de Upgrade.",
        "Requiere Sendit: Upgrade (activado).", "Apagado", "al menos %s %%", "Impulso ≥ %s %%", "Evaluar de nuevo", "desactualizado",
        "evaluando %d / %d …", "%d mazmorras con al menos %s %% de mejora", "%d mazmorra con al menos %s %% de mejora",
        "Ninguna mazmorra accesible mejora al menos un %s %%.", "%d mejoras", "%s %% de probabilidad",
        "%s de todo tu personaje con este objeto en lugar del actual: el mismo número que la descripción de Sendit Upgrade.",
        ",", "Arrastra para cambiar el tamaño", "tu nivel", "por encima de tu nivel", "por debajo de tu nivel", "Sin botín propio - solo objetos del mundo (verdes aleatorios)", "Alcance", "Estándar (tu nivel)", "hasta %d niveles por encima", "Todos los niveles", "Estándar: solo mazmorras a las que puedes entrar y objetos que puedes llevar ahora. La vista previa muestra también mazmorras y objetos superiores: lo que darían a tu personaje tal como es hoy.", "desde nivel %d", "Jefes del mundo", "Mundo abierto",
    },
    ruRU = {
        "Подземелья, боссы, добыча", "Подземелье или босс…", "Обзор подземелий",
        "Подземелья, их боссы и добыча в отдельном окне - с улучшением снаряжения.", "Открыть",
        "Подземелье не найдено.", "Выберите подземелье слева.",
        "Уровень %d-%d", "Уровень ?", "%d игроков", "Рейд", "Подземелье", "Боссов: %d",
        "Добыча неизвестна - данных по этому боссу пока нет (собственный или изменённый босс Forever)",
        "Все", "Для моего уровня", "Подземелья", "Рейды",
        "Улучшение снаряжения", "Подземелья, боссы которых роняют предмет, делающий персонажа сильнее (Sendit Upgrade, %s), лучшие сверху - то же число, что в подсказке Upgrade.",
        "Нужен Sendit: Upgrade (включён).", "Выкл.", "не менее %s %%", "Улучшение ≥ %s %%", "Пересчитать", "устарело",
        "оценка %d / %d …", "%d подземелий с улучшением не менее %s %%", "%d подземелье с улучшением не менее %s %%",
        "Нет доступного подземелья с улучшением не менее %s %%.", "Улучшений: %d", "Шанс %s %%",
        "%s всего персонажа с этим предметом вместо надетого - то же число, что в подсказке Sendit Upgrade.",
        ",", "Потяните, чтобы изменить размер", "ваш уровень", "выше вашего уровня", "ниже вашего уровня", "Своей добычи нет - только мировые предметы (случайные зелёные)", "Охват", "Стандарт (ваш уровень)", "до %d ур. выше вас", "Все уровни", "Стандарт: только доступные подземелья и предметы, которые можно надеть сейчас. Предпросмотр показывает и более высокие: что они дали бы персонажу таким, какой он сегодня.", "с %d ур.", "Мировые боссы", "Открытый мир",
    },
}
local tables = {}
for code, values in pairs(rows) do
    tables[code] = {}
    for i, key in ipairs(keys) do tables[code][key] = values[i] end
end
ns.L = Sendit.Locale.New(tables)
