--[[
  Locale: UI text in Sendit's five languages. Talent, tree and form names
  come from the client (C_Traits, spell names); only the route texts live here.
]]
local _, ns = ...
local keys = { "route", "off", "next", "nextAt", "done", "toggle", "free", "dropped" }
local rows = {
    enUS = { "Talent route", "No route", "Next point: %s %d/%d", "At level %d: %s %d/%d", "Route complete", "Show or hide the talent route", "%d points free: %s", "dropped" },
    deDE = { "Talentroute", "Keine Route", "Nächster Punkt: %s %d/%d", "Ab Stufe %d: %s %d/%d", "Route abgeschlossen", "Talentroute ein- oder ausblenden", "%d Punkte frei: %s", "entfällt" },
    frFR = { "Parcours de talents", "Aucun parcours", "Prochain point : %s %d/%d", "Au niveau %d : %s %d/%d", "Parcours terminé", "Afficher ou masquer le parcours de talents", "%d points libres : %s", "abandonné" },
    esES = { "Ruta de talentos", "Sin ruta", "Siguiente punto: %s %d/%d", "Al nivel %d: %s %d/%d", "Ruta completada", "Mostrar u ocultar la ruta de talentos", "%d puntos libres: %s", "descartado" },
    ruRU = { "Маршрут талантов", "Без маршрута", "Следующее очко: %s %d/%d", "На уровне %d: %s %d/%d", "Маршрут пройден", "Показать или скрыть маршрут талантов", "Свободных очков: %d — %s", "отпадает" },
}
local tables = {}
for code, values in pairs(rows) do
    tables[code] = {}
    for i, key in ipairs(keys) do tables[code][key] = values[i] end
end
ns.L = Sendit.Locale.New(tables)
