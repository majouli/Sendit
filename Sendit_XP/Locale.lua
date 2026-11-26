--[[
  Locale: page texts in five languages. The "XP" after the number is the client's own XP string.
]]
local _, ns = ...
ns.L = Sendit.Locale.New({
    enUS = {
        title = "Experience", subtitle = "Experience bubbles your character draws in",
        effect = "Effect", height = "Character height",
        heightDesc = "Where the bubbles meet: move it until they fly into your character.",
        size = "Bubble size", preview = "Preview", previewDesc = "Plays the effect once.", play = "Play",
    },
    deDE = {
        title = "Erfahrung", subtitle = "Erfahrungsblasen, die dein Charakter einsaugt",
        effect = "Effekt", height = "Charakterhöhe",
        heightDesc = "Wo die Blasen zusammenlaufen: so verschieben, dass sie in deinen Charakter fliegen.",
        size = "Blasengröße", preview = "Vorschau", previewDesc = "Spielt den Effekt einmal ab.", play = "Abspielen",
    },
    frFR = {
        title = "Expérience", subtitle = "Des bulles d'expérience que ton personnage absorbe",
        effect = "Effet", height = "Hauteur du personnage",
        heightDesc = "Point où les bulles se rejoignent : déplace-le jusqu'à ce qu'elles entrent dans ton personnage.",
        size = "Taille des bulles", preview = "Aperçu", previewDesc = "Joue l'effet une fois.", play = "Jouer",
    },
    esES = {
        title = "Experiencia", subtitle = "Burbujas de experiencia que absorbe tu personaje",
        effect = "Efecto", height = "Altura del personaje",
        heightDesc = "Donde se juntan las burbujas: muévelo hasta que entren en tu personaje.",
        size = "Tamaño de las burbujas", preview = "Vista previa", previewDesc = "Reproduce el efecto una vez.",
        play = "Reproducir",
    },
    ruRU = {
        title = "Опыт", subtitle = "Пузырьки опыта, которые впитывает персонаж",
        effect = "Эффект", height = "Высота персонажа",
        heightDesc = "Точка, где сходятся пузырьки: сдвиньте её, чтобы они влетали в персонажа.",
        size = "Размер пузырьков", preview = "Предпросмотр", previewDesc = "Проигрывает эффект один раз.",
        play = "Запустить",
    },
})
