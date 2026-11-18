# Sendit Talents sources

This module is licensed under GPL-3.0; see LICENSE.md. Its implementation
is original Sendit code.

- Talent routes (tools/data/talent_routes.tsv, talent_route_meta.tsv): one
  talent point per level 10-60 for 28 class/spec routes, compiled and checked
  by the Sendit author (2026-11-18) from public WoW Forever leveling and
  talent guides (mobalytics.gg, icy-veins.com, forever-hub.com; row gates
  checked against wowfdb.com). Each route's source is in
  talent_route_meta.tsv. Some orders are derived from a guide's final build.
- Talent nodes: the Forever client's own trait tables (wago.tools DB2
  TraitNode, TraitNodeEntry, TraitNodeXTraitNodeEntry, TraitDefinition,
  SkillLineXTraitTree, SpellName; build in tools/forever-build.txt),
  matched by tools/gen_talents.py.
