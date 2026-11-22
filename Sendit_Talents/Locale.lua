--[[
  Locale: the route texts in five languages (talent and tree names come from the client).
  One row per key: enUS, deDE, frFR, esES, ruRU. v_* = a guide's variant name, t_* = what it means, role_* = the route's role.
]]
local _, ns = ...
local CODES = { "enUS", "deDE", "frFR", "esES", "ruRU" }
local rows = {
    route = { "Talent route", "Talentroute", "Parcours de talents", "Ruta de talentos", "Маршрут талантов" },
    off = { "No route", "Keine Route", "Aucun parcours", "Sin ruta", "Без маршрута" },
    next = { "Next point: %s %d/%d", "Nächster Punkt: %s %d/%d", "Prochain point : %s %d/%d", "Siguiente punto: %s %d/%d", "Следующее очко: %s %d/%d" },
    nextAt = { "At level %d: %s %d/%d", "Ab Stufe %d: %s %d/%d", "Au niveau %d : %s %d/%d", "Al nivel %d: %s %d/%d", "На уровне %d: %s %d/%d" },
    done = { "Route complete", "Route abgeschlossen", "Parcours terminé", "Ruta completada", "Маршрут пройден" },
    toggle = { "Show or hide the talent route", "Talentroute ein- oder ausblenden", "Afficher ou masquer le parcours de talents", "Mostrar u ocultar la ruta de talentos", "Показать или скрыть маршрут талантов" },
    free = { "%d points free: %s", "%d Punkte frei: %s", "%d points libres : %s", "%d puntos libres: %s", "Свободных очков: %d — %s" },
    dropped = { "dropped", "entfällt", "abandonné", "descartado", "отпадает" },
    leveling = { "Leveling", "Leveling", "Montée de niveau", "Subida de nivel", "Прокачка" },
    group = { "Dungeons & raids", "Dungeons & Raids", "Donjons & raids", "Mazmorras y bandas", "Подземелья и рейды" },
    use_level = { "From level 10 to 60", "Von Stufe 10 bis 60", "Du niveau 10 au 60", "Del nivel 10 al 60", "С 10 по 60 уровень" },
    role_tank = { "Tank", "Tank", "Tank", "Tanque", "Танк" },
    role_heal = { "Healer", "Heiler", "Soigneur", "Sanador", "Лекарь" },
    role_damage = { "Damage", "Schaden", "Dégâts", "Daño", "Урон" },
    hybrid = { "Hybrid with %s", "Hybrid mit %s", "Hybride avec %s", "Híbrido con %s", "Гибрид с веткой «%s»" },
    pvp = { "PvP", "PvP", "JcJ", "JcJ", "PvP" },

    tip_level = { "Talent order from level 10 to 60 for leveling.", "Talentreihenfolge von Stufe 10 bis 60 zum Leveln.", "Ordre des talents du niveau 10 au 60 pour monter de niveau.", "Orden de talentos del nivel 10 al 60 para subir de nivel.", "Порядок талантов с 10 по 60 уровень для прокачки." },
    tip_points = { "Points", "Punkte", "Points", "Puntos", "Очки" },
    tip_core = { "What the build is built on:", "Worauf der Build aufbaut:", "Ce sur quoi repose le build :", "En qué se basa la configuración:", "На чём строится билд:" },
    tip_own = { "What only this build gives you:", "Was nur dieser Build dir bringt:", "Ce que seul ce build vous apporte :", "Lo que solo esta configuración te da:", "Что даёт только этот билд:" },
    tip_derived = { "Order derived from the guide's final build.", "Reihenfolge aus dem fertigen Build des Guides abgeleitet.", "Ordre déduit du build final du guide.", "Orden deducido de la configuración final de la guía.", "Порядок выведен из итогового билда гайда." },
    tip_guide = { "Order as the guide gives it.", "Reihenfolge wie im Guide.", "Ordre tel que donné par le guide.", "Orden tal como lo da la guía.", "Порядок как в гайде." },

    v_lowHit = { "Low hit gear", "Wenig Trefferwertung", "Peu de toucher", "Poco golpe", "Мало меткости" },
    v_standard = { "Standard", "Standard", "Standard", "Estándar", "Стандарт" },
    v_threat = { "Threat", "Bedrohung", "Menace", "Amenaza", "Угроза" },
    v_tanky = { "Survivability", "Überlebensfähigkeit", "Survie", "Supervivencia", "Живучесть" },
    v_mainTank = { "Main tank", "Haupttank", "Tank principal", "Tanque principal", "Основной танк" },
    v_offTank = { "Off-tank", "Nebentank", "Tank secondaire", "Tanque secundario", "Второй танк" },
    v_raid = { "Raid", "Raid", "Raid", "Banda", "Рейд" },
    v_dungeon = { "Dungeon", "Dungeon", "Donjon", "Mazmorra", "Подземелье" },
    v_bg = { "Battleground", "Schlachtfeld", "Champ de bataille", "Campo de batalla", "Поле боя" },
    v_solo = { "Solo", "Solo", "Solo", "En solitario", "Соло" },
    v_group = { "Group", "Gruppe", "Groupe", "En grupo", "Группа" },
    v_aoe = { "AoE", "Flächenschaden", "Zone", "Área", "По площади" },
    v_ranged = { "Ranged", "Fernkampf", "Distance", "A distancia", "Дальний бой" },
    v_weave = { "Melee weaving", "Nahkampf-Weaving", "Alternance mêlée", "Alternar cuerpo a cuerpo", "Чередование с ближним боем" },
    v_spellpower = { "Max spell power", "Max. Zaubermacht", "Puissance des sorts max.", "Poder con hechizos máx.", "Макс. сила заклинаний" },
    v_noRespec = { "No respec", "Ohne Umskillen", "Sans respécialisation", "Sin reespecializar", "Без смены талантов" },
    v_fire = { "Fire", "Feuer", "Feu", "Fuego", "Огонь" },
    v_shadow = { "Shadow", "Schatten", "Ombre", "Sombras", "Тьма" },
    v_frostfire = { "Frostfire", "Frostfeuer", "Givrefeu", "Fuego de escarcha", "Ледяной огонь" },

    t_hybrid = { "Mixes in more %s than the standard build.", "Nimmt mehr %s als der Standard-Build.", "Prend plus de %s que le build standard.", "Toma más %s que la configuración estándar.", "Берёт больше талантов ветки «%s», чем стандартный билд." },
    t_lowHit = { "For gear with little hit chance.", "Für Ausrüstung mit wenig Trefferwertung.", "Pour un équipement avec peu de toucher.", "Para equipo con poco índice de golpe.", "Для экипировки с малой меткостью." },
    t_standard = { "The guide's default build for this tree.", "Der Standard-Build des Guides für diesen Baum.", "Le build par défaut du guide pour cet arbre.", "La configuración por defecto de la guía para este árbol.", "Стандартный билд гайда для этой ветки." },
    t_threat = { "Takes the talents that raise threat, to hold aggro.", "Nimmt die Talente für mehr Bedrohung, um die Aggro zu halten.", "Prend les talents qui augmentent la menace, pour garder l'aggro.", "Toma los talentos que aumentan la amenaza, para mantener el aggro.", "Берёт таланты на угрозу, чтобы держать агро." },
    t_tanky = { "Takes the talents that let you take more hits.", "Nimmt die Talente, mit denen du mehr aushältst.", "Prend les talents qui vous font encaisser davantage.", "Toma los talentos que te permiten aguantar más golpes.", "Берёт таланты, с которыми вы выдерживаете больше урона." },
    t_mainTank = { "For the main tank.", "Für den Haupttank.", "Pour le tank principal.", "Para el tanque principal.", "Для основного танка." },
    t_offTank = { "For the off-tank.", "Für den Nebentank.", "Pour le tank secondaire.", "Para el tanque secundario.", "Для второго танка." },
    t_raid = { "Tuned for raids.", "Auf Raids ausgelegt.", "Conçu pour les raids.", "Pensado para bandas.", "Рассчитан на рейды." },
    t_dungeon = { "Tuned for dungeons.", "Auf Dungeons ausgelegt.", "Conçu pour les donjons.", "Pensado para mazmorras.", "Рассчитан на подземелья." },
    t_bg = { "Tuned for battlegrounds.", "Auf Schlachtfelder ausgelegt.", "Conçu pour les champs de bataille.", "Pensado para campos de batalla.", "Рассчитан на поля боя." },
    t_solo = { "For leveling alone.", "Zum Leveln allein.", "Pour monter de niveau seul.", "Para subir de nivel en solitario.", "Для прокачки в одиночку." },
    t_group = { "For leveling in a group.", "Zum Leveln in der Gruppe.", "Pour monter de niveau en groupe.", "Para subir de nivel en grupo.", "Для прокачки в группе." },
    t_aoe = { "Pull many enemies and kill them with area damage.", "Viele Gegner ziehen und mit Flächenschaden töten.", "Attirer de nombreux ennemis et les tuer avec des dégâts de zone.", "Atraer a muchos enemigos y matarlos con daño en área.", "Собирать много врагов и убивать уроном по площади." },
    t_ranged = { "Ranged attacks only.", "Nur Fernkampf.", "Attaques à distance uniquement.", "Solo ataques a distancia.", "Только дальний бой." },
    t_weave = { "Mixes melee attacks in between shots.", "Nahkampfangriffe zwischen den Schüssen.", "Glisse des attaques de mêlée entre les tirs.", "Intercala ataques cuerpo a cuerpo entre disparos.", "Атаки ближнего боя между выстрелами." },
    t_spellpower = { "Takes every spell power talent.", "Nimmt jedes Zaubermacht-Talent.", "Prend chaque talent de puissance des sorts.", "Toma todos los talentos de poder con hechizos.", "Берёт все таланты на силу заклинаний." },
    t_noRespec = { "The guide's build for players who do not respec.", "Der Build des Guides für alle, die nicht umskillen.", "Le build du guide pour qui ne se respécialise pas.", "La configuración de la guía para quien no reespecializa.", "Билд гайда для тех, кто не меняет таланты." },
    t_fire = { "Casts fire spells.", "Wirkt Feuerzauber.", "Lance des sorts de feu.", "Lanza hechizos de fuego.", "Использует заклинания огня." },
    t_shadow = { "Casts shadow spells.", "Wirkt Schattenzauber.", "Lance des sorts d'ombre.", "Lanza hechizos de sombras.", "Использует заклинания тьмы." },
    t_frostfire = { "Fire build with frost talents as the second tree.", "Feuer-Build mit Frost-Talenten als zweitem Baum.", "Build feu avec des talents de givre en second arbre.", "Configuración de fuego con talentos de escarcha como segundo árbol.", "Огненный билд с талантами льда во второй ветке." },
}
local tables = {}
for i, code in ipairs(CODES) do
    tables[code] = {}
    for key, values in pairs(rows) do tables[code][key] = values[i] end
end
ns.L = Sendit.Locale.New(tables)
