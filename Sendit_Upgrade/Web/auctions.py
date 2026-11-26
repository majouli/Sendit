"""
Sendit auction web data, the core: fetches one auction house of WoW Forever from the Battle.net API
and writes it as the data addon Sendit_AuctionData, which Sendit_Upgrade reads. Used by the app
(SenditAuctions.pyw: setup, install, the background task) and the command line (fetch_auctions.py).
Nothing here asks or prints.

Config %APPDATA%/Sendit/auctions.json (this PC only): client_id, client_secret, region, wow (game folder),
house {id, name}, token {value, expires} (the API token, valid about a day), modified {house, at} (the
Last-Modified of the written data), last_run {at, ok, text}, cadence (seconds between the server's last
renewals, at most CADENCE_KEEP: the data addon gets their median as "interval" and EVERY as "every", so the
game can tell when newer data is waiting on disk - it reads files only at login or /reload).
The server renews the data about hourly; fetch() asks only for something newer than the written data
(If-Modified-Since -> 304), so looking every few minutes costs next to nothing.
The house is found by matching the newest in-game scan (Sendit_Upgrade's SavedVariables) once.
"""
import base64
import calendar
import gzip
import json
import os
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

CONFIG = Path(os.environ.get("APPDATA", Path.home())) / "Sendit" / "auctions.json"
LOG = CONFIG.with_name("auctions.log")
ADDON = "Sendit_AuctionData"
INTERFACE = "16001"
TASK = "Sendit auction data"
EVERY = 5  # minutes between two looks of the background task
MIN_MATCH = 0.05  # share of the in-game scan a house must hold to be taken
LOG_LINES = 200
CADENCE_KEEP = 6
CADENCE_RANGE = (600, 6 * 3600)  # a renewal gap outside it is a missed hour or a restart, not the cadence
DEFAULT_INTERVAL = 3600
CLIENTS_URL = "https://develop.battle.net/access/clients"


class NeedHouse(Exception):
    """no house could be matched; .houses = [{id, name}] to choose from"""

    def __init__(self, houses):
        super().__init__("auction house unknown")
        self.houses = houses


def load_config():
    try:
        return json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def save_config(cfg):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONFIG.with_suffix(".tmp")
    tmp.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    os.replace(tmp, CONFIG)  # the background task and the app may write at the same time


def log(text):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    lines = LOG.read_text(encoding="utf-8").splitlines() if LOG.exists() else []
    lines.append(time.strftime("%Y-%m-%d %H:%M  ") + text)
    LOG.write_text("\n".join(lines[-LOG_LINES:]) + "\n", encoding="utf-8")


def request(url, data=None, headers=None):
    """(body, headers); body None when the server answers 304 (nothing newer than If-Modified-Since)"""
    req = urllib.request.Request(url, data=data, headers=dict(headers or {}, **{"Accept-Encoding": "gzip"}))
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            raw = r.read()
            if r.headers.get("Content-Encoding") == "gzip":
                raw = gzip.decompress(raw)
            return json.loads(raw.decode("utf-8")), r.headers
    except urllib.error.HTTPError as e:
        if e.code == 304:
            return None, e.headers
        raise


class Api:
    def __init__(self, cfg):
        self.cfg = cfg
        self.region = cfg["region"]
        self.host = f"https://{self.region}.api.blizzard.com"
        token = cfg.get("token") or {}
        if token.get("value") and token.get("expires", 0) > time.time() + 60:
            self.token = token["value"]
        else:
            self.renew()

    def renew(self):
        auth = base64.b64encode(f"{self.cfg['client_id']}:{self.cfg['client_secret']}".encode()).decode()
        body, _ = request("https://oauth.battle.net/token", b"grant_type=client_credentials",
                          {"Authorization": "Basic " + auth})
        self.token = body["access_token"]
        self.cfg["token"] = {"value": self.token, "expires": int(time.time()) + int(body.get("expires_in", 3600))}

    def get(self, path, since=None):
        sep = "&" if "?" in path else "?"
        url = f"{self.host}{path}{sep}namespace=dynamic-forever-{self.region}"
        for attempt in (1, 2):
            headers = {"Authorization": "Bearer " + self.token}
            if since:
                headers["If-Modified-Since"] = since
            try:
                return request(url, headers=headers)
            except urllib.error.HTTPError as e:
                if e.code != 401 or attempt == 2:
                    raise
                self.renew()  # a kept token the server no longer takes

    def ruleset(self):
        body, _ = self.get("/data/wow/ruleset/index")
        sets = body.get("rulesets") or body.get("results") or []
        if not sets:
            raise RuntimeError("The API lists no ruleset: " + json.dumps(body)[:300])
        return sets[0]["id"]

    def houses(self, ruleset):
        body, _ = self.get(f"/data/wow/ruleset/{ruleset}/auctions/")
        return [{"id": h["id"], "name": name(h.get("name"))} for h in body.get("auctions", [])]

    def auctions(self, ruleset, house, since=None):
        """(rows, headers); rows None when nothing is newer than since (a Last-Modified value)"""
        body, headers = self.get(f"/data/wow/ruleset/{ruleset}/auctions/{house}", since)
        if body is None:
            return None, headers
        return body.get("auctions") or [], headers


def name(value):
    """a name is a string, or one per locale when the request named none"""
    if isinstance(value, dict):
        return value.get("en_US") or value.get("en_GB") or next(iter(value.values()), "?")
    return value or "?"


def item_key(a):
    """(id, suffix, bonuses): one auction variant, keyed like Scan.Key in the game (sorted bonus ids)"""
    item = a.get("item") or {}
    bonuses = ".".join(str(b) for b in sorted(int(b) for b in item.get("bonus_lists") or []))
    return item.get("id"), int(item.get("rand") or 0), bonuses


def buyout(a):
    return int(a.get("buyout") or 0)


def unit_price(a):
    """copper per item: a stack's buyout over its size, or the unit price of a commodity"""
    if a.get("unit_price"):
        return int(a["unit_price"])
    total = buyout(a)
    return round(total / max(1, int(a.get("quantity") or 1))) if total > 0 else 0


def is_wow(path):
    return bool(path) and (Path(path) / "Interface" / "AddOns").is_dir() and (Path(path) / "WTF").is_dir()


def _registry_wow():
    try:
        import winreg
    except ImportError:
        return []
    found = []
    for key in (r"SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
                r"SOFTWARE\Blizzard Entertainment\World of Warcraft"):
        try:
            with winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, key) as k:
                path = Path(winreg.QueryValueEx(k, "InstallPath")[0])
                found += [path / "_forever_", path.parent / "_forever_", path]
        except OSError:
            pass
    return found


def find_wow(cfg=None):
    """the WoW Forever folder: the configured one, Blizzard's install path, or a usual place"""
    cfg = cfg or {}
    places = [Path(cfg["wow"])] if cfg.get("wow") else []
    places += _registry_wow()
    for drive in "CDEFGH":
        for rest in (r"Games\WoW\World of Warcraft", r"Games\World of Warcraft", r"World of Warcraft",
                     r"Program Files (x86)\World of Warcraft", r"Program Files\World of Warcraft",
                     r"Blizzard\World of Warcraft"):
            places.append(Path(f"{drive}:\\") / rest / "_forever_")
    for p in places:
        if is_wow(p):
            return p
    return None


def in_game_scan(wow):
    """(itemID, buyout) pairs of the newest kept in-game scan of any account on this PC."""
    best, best_at = set(), 0
    for f in (Path(wow) / "WTF" / "Account").glob("*/SavedVariables/Sendit_Upgrade.lua"):
        text = f.read_text(encoding="utf-8", errors="replace")
        start = text.find('["auctionLast"]')
        if start < 0:
            continue
        block = text[start:]
        at = re.search(r'\["at"\]\s*=\s*(\d+)', block)
        at = int(at.group(1)) if at else 0
        pairs = set()
        for entry in re.finditer(r"\{([^{}]*)\}", block):
            body = entry.group(1)
            item = re.search(r'\["itemID"\]\s*=\s*(\d+)', body)
            price = re.search(r'\["buyout"\]\s*=\s*(\d+)', body)
            if item and price:
                pairs.add((int(item.group(1)), int(price.group(1))))
        if pairs and at > best_at:
            best, best_at = pairs, at
    return best


def match_house(api, ruleset, wow):
    """the house holding most of the in-game scan; raises NeedHouse without a scan or a clear match"""
    houses = api.houses(ruleset)
    scan = in_game_scan(wow)
    if not scan:
        raise NeedHouse(houses)
    best, best_share = None, 0.0
    for h in houses:
        rows, _ = api.auctions(ruleset, h["id"])
        share = len(scan & {(item_key(a)[0], buyout(a)) for a in rows}) / len(scan)
        if share > best_share:
            best, best_share = h, share
    if best is None or best_share < MIN_MATCH:
        raise NeedHouse(houses)
    return best


def interval_of(cfg):
    """the server's renewal cadence: the median of the gaps seen, else an hour"""
    gaps = sorted(cfg.get("cadence") or [])
    return gaps[len(gaps) // 2] if gaps else DEFAULT_INTERVAL


def lua_data(rows, house, at, interval=DEFAULT_INTERVAL, every=EVERY * 60):
    best = {}
    for a in rows:
        item, suffix, bonuses = item_key(a)
        price = unit_price(a)
        if not item or price <= 0:
            continue
        cur = best.get((item, suffix, bonuses))
        best[(item, suffix, bonuses)] = [min(cur[0], price), cur[1] + 1] if cur else [price, 1]
    # one string, not a table: a Lua 5.1 chunk holds at most 2^18 constants
    items = "\n".join(f"{i}:{s}:{b}:{p}:{c}" for (i, s, b), (p, c) in sorted(best.items()))
    head = (f"SenditAuctionData = {{ at = {at}, house = {json.dumps(house, ensure_ascii=False)}, "
            f"auctions = {len(rows)}, interval = {int(interval)}, every = {int(every)}, items = [[\n")
    return head + items + "\n]] }\n", len(best)


def data_info(wow):
    """(at, house, auctions) of the written data addon as the game reads it, or None"""
    try:
        with open(data_file(wow), encoding="utf-8") as f:
            head = f.readline()
    except OSError:
        return None
    m = re.match(r'SenditAuctionData = \{ at = (\d+), house = (".*?"), auctions = (\d+)', head)
    if not m:
        return None
    return int(m.group(1)), json.loads(m.group(2)), int(m.group(3))


def data_file(wow):
    return Path(wow) / "Interface" / "AddOns" / ADDON / "Data.lua"


def write_addon(wow, text):
    folder = data_file(wow).parent
    folder.mkdir(parents=True, exist_ok=True)
    fresh = not (folder / f"{ADDON}.toc").exists()
    toc = (f"## Interface: {INTERFACE}\n## Title: Sendit: Auction Data\n"
           "## Notes: Auction house data from the Battle.net API, written by the Sendit auction data app.\n"
           "## X-License: GPL-3.0\nData.lua\n")
    (folder / f"{ADDON}.toc").write_text(toc, encoding="utf-8", newline="\n")
    tmp = folder / "Data.lua.tmp"
    tmp.write_text(text, encoding="utf-8", newline="\n")
    os.replace(tmp, folder / "Data.lua")
    return fresh


def fetch(cfg, house=None):
    """Writes newer data of the house (cfg's, given, or matched). Returns
    {new, house, auctions, items, at, fresh}; new False when the server had nothing newer.
    Raises NeedHouse, urllib errors; keeps the token and house in cfg (the caller saves)."""
    wow = Path(cfg["wow"])
    api = Api(cfg)
    ruleset = api.ruleset()
    if house is None:
        house = cfg.get("house") or match_house(api, ruleset, wow)
    cfg["house"] = house
    last = cfg.get("modified") or {}
    since = last.get("at") if last.get("house") == house["id"] and data_file(wow).exists() else None
    rows, headers = api.auctions(ruleset, house["id"], since)
    if rows is None:
        return {"new": False, "house": house}
    modified = headers.get("Last-Modified")
    at = calendar.timegm(time.strptime(modified, "%a, %d %b %Y %H:%M:%S GMT")) if modified else int(time.time())
    previous = last.get("time") if last.get("house") == house["id"] else None
    if previous and CADENCE_RANGE[0] <= at - previous <= CADENCE_RANGE[1]:
        cfg["cadence"] = ((cfg.get("cadence") or []) + [at - previous])[-CADENCE_KEEP:]
    text, items = lua_data(rows, house["name"], at, interval_of(cfg))
    fresh = write_addon(wow, text)
    cfg["modified"] = {"house": house["id"], "at": modified, "time": at, "auctions": len(rows)}
    return {"new": True, "house": house, "auctions": len(rows), "items": items, "at": at, "fresh": fresh}


def run_once(cfg):
    """One look as the background task does it: never raises, notes the outcome in cfg and the log."""
    try:
        if not cfg.get("wow") or not is_wow(cfg["wow"]):
            raise RuntimeError("WoW folder not found")
        result = fetch(cfg)
        text = (f"{result['house']['name']} ({result['house']['id']}): {result['auctions']} auctions"
                if result["new"] else "no newer data")
        cfg["last_run"] = {"at": int(time.time()), "ok": True, "text": text, "new": result["new"]}
    except NeedHouse:
        cfg["last_run"] = {"at": int(time.time()), "ok": False, "text": "auction house unknown"}
    except urllib.error.HTTPError as e:
        cfg["last_run"] = {"at": int(time.time()), "ok": False, "text": f"API error {e.code} {e.reason}"}
    except Exception as e:  # the task runs unattended: every failure ends in the log
        cfg["last_run"] = {"at": int(time.time()), "ok": False, "text": f"{type(e).__name__}: {e}"}
    save_config(cfg)
    log(("ok    " if cfg["last_run"]["ok"] else "fail  ") + cfg["last_run"]["text"])
    return cfg["last_run"]
