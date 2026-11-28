--[[
  Locale: UI texts in five languages (dungeon and boss names come from the client).
]]
local _, ns = ...
local keys = {
    "subtitle", "search", "page", "pageDesc", "open", "empty", "pick",
    "levels", "levelUnknown", "players", "raid", "dungeon", "bosses", "lootUnknown",
    "filterAll", "filterFits", "filterDungeons", "filterRaids",
    "boost", "boostHelp", "boostNeedsUpgrade", "boostOn", "boostAgain", "stale",
    "boostRating", "boostCount", "boostCountOne", "boostEmpty", "upgrades", "chance", "detailVs", "decimal",
    "resize", "fitsYou", "aboveYou", "belowYou", "worldOnly",
    "aheadAll", "fromLevel", "worldBosses", "openWorld", "noUpgrade", "rare", "dungeonDrops", "map",
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
        "Needs Sendit: Upgrade (switched on).", "Boost ≥ %s %%", "Rate again", "stale",
        "rating %d / %d …", "%d dungeons with at least %s %% upgrade", "%d dungeon with at least %s %% upgrade",
        "No dungeon you can enter drops an upgrade of at least %s %%.", "%d upgrades", "%s %% drop chance",
        "Your whole character's %s with this item instead of your worn one - the same number as Sendit Upgrade's item tooltip.",
        ".", "Drag to resize", "your level", "above your level", "below your level", "No drops of its own - only world drops (random green items)", "All levels", "from level %d", "World bosses", "Open world", "No upgrade for you", "Rare", "Anywhere in the instance", "Map",
    },
    deDE = {
        "Dungeons, Bosse, Beute", "Dungeon oder Boss…", "Dungeon-Browser",
        "Dungeons, ihre Bosse und was sie fallen lassen, in einem eigenen Fenster - mit Gear-Boost.", "Öffnen",
        "Kein Dungeon gefunden.", "Wähle links einen Dungeon.",
        "Stufe %d-%d", "Stufe ?", "%d Spieler", "Schlachtzug", "Dungeon", "%d Bosse",
        "Beute unbekannt - für diesen Boss gibt es noch keine Daten (Forever-eigener oder geänderter Boss)",
        "Alle", "Für meine Stufe", "Dungeons", "Schlachtzüge",
        "Gear-Boost", "Dungeons, deren Bosse ein Teil fallen lassen, das deinen Charakter stärker macht (Sendit Upgrade, %s), größter Gewinn zuerst - dieselbe Zahl wie im Item-Tooltip von Upgrade.",
        "Benötigt Sendit: Upgrade (eingeschaltet).", "Boost ≥ %s %%", "Neu bewerten", "veraltet",
        "bewerte %d / %d …", "%d Dungeons mit mindestens %s %% Upgrade", "%d Dungeon mit mindestens %s %% Upgrade",
        "Kein Dungeon, den du betreten kannst, bringt mindestens %s %% Upgrade.", "%d Upgrades", "%s %% Dropchance",
        "%s deines ganzen Charakters mit diesem Teil statt deinem getragenen - dieselbe Zahl wie im Item-Tooltip von Sendit Upgrade.",
        ",", "Ziehen zum Ändern der Größe", "deine Stufe", "über deiner Stufe", "unter deiner Stufe", "Keine eigene Beute - nur Welt-Drops (zufällige grüne Items)", "Alle Stufen", "ab Stufe %d", "Weltbosse", "Offene Welt", "Kein Upgrade für dich", "Selten", "Überall in der Instanz", "Karte",
    },
    frFR = {
        "Donjons, boss, butin", "Donjon ou boss…", "Navigateur de donjons",
        "Les donjons, leurs boss et leur butin, dans une fenêtre à part - avec le boost d'équipement.", "Ouvrir",
        "Aucun donjon trouvé.", "Choisissez un donjon à gauche.",
        "Niveau %d-%d", "Niveau ?", "%d joueurs", "Raid", "Donjon", "%d boss",
        "Butin inconnu - pas encore de données pour ce boss (boss propre à Forever ou modifié)",
        "Tous", "Pour mon niveau", "Donjons", "Raids",
        "Boost d'équipement", "Donjons dont un boss lâche un objet qui rend votre personnage plus fort (Sendit Upgrade, %s), le plus grand gain d'abord - le même nombre que l'infobulle d'Upgrade.",
        "Nécessite Sendit : Upgrade (activé).", "Boost ≥ %s %%", "Réévaluer", "obsolète",
        "évaluation %d / %d …", "%d donjons avec au moins %s %% d'amélioration", "%d donjon avec au moins %s %% d'amélioration",
        "Aucun donjon accessible n'apporte au moins %s %%.", "%d améliorations", "%s %% de chance",
        "%s de tout votre personnage avec cet objet au lieu de celui porté - le même nombre que l'infobulle de Sendit Upgrade.",
        ",", "Glisser pour redimensionner", "votre niveau", "au-dessus de votre niveau", "sous votre niveau", "Pas de butin propre - seulement des objets mondiaux (verts aléatoires)", "Tous les niveaux", "dès le niveau %d", "Boss mondiaux", "Monde ouvert", "Aucune amélioration pour vous", "Rare", "Partout dans l'instance", "Carte",
    },
    esES = {
        "Mazmorras, jefes, botín", "Mazmorra o jefe…", "Explorador de mazmorras",
        "Las mazmorras, sus jefes y lo que sueltan, en una ventana aparte - con el impulso de equipo.", "Abrir",
        "No se encontró ninguna mazmorra.", "Elige una mazmorra a la izquierda.",
        "Nivel %d-%d", "Nivel ?", "%d jugadores", "Banda", "Mazmorra", "%d jefes",
        "Botín desconocido - aún no hay datos de este jefe (jefe propio de Forever o cambiado)",
        "Todas", "Para mi nivel", "Mazmorras", "Bandas",
        "Impulso de equipo", "Mazmorras cuyos jefes sueltan un objeto que hace más fuerte a tu personaje (Sendit Upgrade, %s), la mayor mejora primero - el mismo número que la descripción de Upgrade.",
        "Requiere Sendit: Upgrade (activado).", "Impulso ≥ %s %%", "Evaluar de nuevo", "desactualizado",
        "evaluando %d / %d …", "%d mazmorras con al menos %s %% de mejora", "%d mazmorra con al menos %s %% de mejora",
        "Ninguna mazmorra accesible mejora al menos un %s %%.", "%d mejoras", "%s %% de probabilidad",
        "%s de todo tu personaje con este objeto en lugar del actual: el mismo número que la descripción de Sendit Upgrade.",
        ",", "Arrastra para cambiar el tamaño", "tu nivel", "por encima de tu nivel", "por debajo de tu nivel", "Sin botín propio - solo objetos del mundo (verdes aleatorios)", "Todos los niveles", "desde nivel %d", "Jefes del mundo", "Mundo abierto", "Ninguna mejora para ti", "Raro", "En cualquier parte de la instancia", "Mapa",
    },
    ruRU = {
        "Подземелья, боссы, добыча", "Подземелье или босс…", "Обзор подземелий",
        "Подземелья, их боссы и добыча в отдельном окне - с улучшением снаряжения.", "Открыть",
        "Подземелье не найдено.", "Выберите подземелье слева.",
        "Уровень %d-%d", "Уровень ?", "%d игроков", "Рейд", "Подземелье", "Боссов: %d",
        "Добыча неизвестна - данных по этому боссу пока нет (собственный или изменённый босс Forever)",
        "Все", "Для моего уровня", "Подземелья", "Рейды",
        "Улучшение снаряжения", "Подземелья, боссы которых роняют предмет, делающий персонажа сильнее (Sendit Upgrade, %s), лучшие сверху - то же число, что в подсказке Upgrade.",
        "Нужен Sendit: Upgrade (включён).", "Улучшение ≥ %s %%", "Пересчитать", "устарело",
        "оценка %d / %d …", "%d подземелий с улучшением не менее %s %%", "%d подземелье с улучшением не менее %s %%",
        "Нет доступного подземелья с улучшением не менее %s %%.", "Улучшений: %d", "Шанс %s %%",
        "%s всего персонажа с этим предметом вместо надетого - то же число, что в подсказке Sendit Upgrade.",
        ",", "Потяните, чтобы изменить размер", "ваш уровень", "выше вашего уровня", "ниже вашего уровня", "Своей добычи нет - только мировые предметы (случайные зелёные)", "Все уровни", "с %d ур.", "Мировые боссы", "Открытый мир", "Нет улучшений для вас", "Редкий", "Где угодно в подземелье", "Карта",
    },
}
local dialogKeys = { "boostFor", "boostMinLabel", "boostMinHint", "boostAhead", "boostSlots", "slotsAll", "slotsNone",
    "boostGo", "boostEnd", "boostCancel", "slotWeapon", "slotOffhand", "slotRanged" }
local dialog = {
    enUS = { "Rated by Sendit Upgrade for: %s", "Your character at least this much stronger",
        "The same number as Sendit Upgrade's item tooltip. One armour piece gives 0,5-2 %, a weapon more. Decimals allowed (0,5).",
        "Preview: also dungeons and items up to this many levels above you", "Slots", "All", "None",
        "Boost", "End boost", "Cancel", "Weapon", "Off hand / shield", "Ranged" },
    deDE = { "Bewertet von Sendit Upgrade für: %s", "Dein Charakter mindestens so viel stärker",
        "Dieselbe Zahl wie im Item-Tooltip von Sendit Upgrade. Ein Rüstungsteil bringt 0,5-2 %, eine Waffe mehr. Dezimalwerte erlaubt (0,5).",
        "Vorschau: auch Dungeons und Items bis so viele Level über dir", "Plätze", "Alle", "Keine",
        "Boost", "Boost beenden", "Abbrechen", "Waffe", "Nebenhand / Schild", "Distanz" },
    frFR = { "Évalué par Sendit Upgrade pour : %s", "Votre personnage au moins autant plus fort",
        "Le même nombre que l'infobulle de Sendit Upgrade. Une armure donne 0,5-2 %, une arme plus. Décimales permises (0,5).",
        "Aperçu : aussi les donjons et objets jusqu'à autant de niveaux au-dessus de vous", "Emplacements", "Tous", "Aucun",
        "Boost", "Arrêter le boost", "Annuler", "Arme", "Main gauche / bouclier", "Distance" },
    esES = { "Evaluado por Sendit Upgrade para: %s", "Tu personaje al menos esto más fuerte",
        "El mismo número que la descripción de Sendit Upgrade. Una armadura da 0,5-2 %, un arma más. Se permiten decimales (0,5).",
        "Vista previa: también mazmorras y objetos hasta tantos niveles por encima de ti", "Ranuras", "Todas", "Ninguna",
        "Impulsar", "Terminar", "Cancelar", "Arma", "Mano izquierda / escudo", "A distancia" },
    ruRU = { "Оценка Sendit Upgrade для: %s", "Персонаж минимум насколько сильнее",
        "То же число, что в подсказке Sendit Upgrade. Броня даёт 0,5-2 %, оружие больше. Можно дробные (0,5).",
        "Предпросмотр: также подземелья и предметы до стольких уровней выше вас", "Ячейки", "Все", "Ни одной",
        "Запуск", "Завершить", "Отмена", "Оружие", "Левая рука / щит", "Дальний бой" },
}
local tables = {}
for code, values in pairs(rows) do
    tables[code] = {}
    for i, key in ipairs(keys) do tables[code][key] = values[i] end
    for i, key in ipairs(dialogKeys) do tables[code][key] = dialog[code][i] end
end
ns.L = Sendit.Locale.New(tables)
