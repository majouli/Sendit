"""
Sendit auction web data on the command line, for checks - players use the app (SenditAuctions.pyw).

  py fetch_auctions.py              fetch once (asks for the API client when none is set up)
  py fetch_auctions.py --houses     list the auction houses
  py fetch_auctions.py --house ID   take this auction house (else the set one, else the in-game scan's)
  py fetch_auctions.py --rematch    find the auction house again from the in-game scan
  py fetch_auctions.py --dump       print three raw auctions (to check the API's fields)
"""
import argparse
import getpass
import json
import sys

import auctions as core


def setup(cfg):
    if not cfg.get("client_id"):
        print("A Battle.net API client is needed (free): " + core.CLIENTS_URL)
        cfg["client_id"] = input("Client ID: ").strip()
        cfg["client_secret"] = getpass.getpass("Client secret (hidden): ").strip()
    if not cfg.get("region"):
        cfg["region"] = (input("Region [eu]: ").strip() or "eu").lower()
    if not core.is_wow(cfg.get("wow")):
        found = core.find_wow(cfg)
        cfg["wow"] = str(found) if found else input("WoW Forever folder (with Interface and WTF): ").strip().strip('"')
    return cfg


def main():
    p = argparse.ArgumentParser(description="Sendit auction web data (Battle.net API, WoW Forever)")
    p.add_argument("--house", type=int, help="auction house id (see --houses)")
    p.add_argument("--houses", action="store_true", help="list the auction houses")
    p.add_argument("--rematch", action="store_true", help="find the auction house again")
    p.add_argument("--dump", action="store_true", help="print three raw auctions")
    args = p.parse_args()
    cfg = setup(core.load_config())
    if args.rematch:
        cfg.pop("house", None)
    api = core.Api(cfg)
    ruleset = api.ruleset()
    if args.houses:
        for h in api.houses(ruleset):
            print(f"  {h['id']:>4}  {h['name']}")
    elif args.dump:
        house = cfg.get("house") or core.match_house(api, ruleset, cfg["wow"])
        rows, _ = api.auctions(ruleset, house["id"])
        print(json.dumps(rows[:3], indent=2))
    else:
        house = None
        if args.house:
            house = next((h for h in api.houses(ruleset) if h["id"] == args.house), None)
            if not house:
                sys.exit("No such house.")
        try:
            result = core.fetch(cfg, house)
        except core.NeedHouse:
            sys.exit("No in-game scan matches a house - scan once at the auction house, or pick one with --house.")
        if result["new"]:
            print(f"{result['house']['name']} ({result['house']['id']}): {result['auctions']} auctions, "
                  f"{result['items']} items -> {core.ADDON}")
            print("New data addon: restart the game once." if result["fresh"] else "In game: /reload.")
        else:
            print("No newer data.")
    core.save_config(cfg)


if __name__ == "__main__":
    main()
