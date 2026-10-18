#!/usr/bin/env python3
"""Verify Medical Card QR fragment encoding and the static HTML viewer.

Mirrors MedTracker/Models/MedicalCardQR.swift:
  fragment = "1." + base64url(utf8(json with sorted keys, omit nulls))
  QR string = https://borismak96.github.io/MedTracker/mc.html#<fragment>
"""

from __future__ import annotations

import base64
import json
import pathlib
import re
import sys

VIEWER = "https://borismak96.github.io/MedTracker/mc.html"
ROOT = pathlib.Path(__file__).resolve().parents[1]
MC_HTML = ROOT / "docs" / "mc.html"


def prune(value):
    if isinstance(value, dict):
        return {k: prune(v) for k, v in value.items() if v is not None}
    if isinstance(value, list):
        return [prune(v) for v in value]
    return value


def fragment_for(card: dict) -> str:
    payload = json.dumps(prune(card), separators=(",", ":"), ensure_ascii=False, sort_keys=True).encode("utf-8")
    token = base64.urlsafe_b64encode(payload).decode("ascii").rstrip("=")
    return "1." + token


def qr_string_for(card: dict) -> str:
    return f"{VIEWER}#{fragment_for(card)}"


def decode_fragment(fragment: str) -> dict:
    raw = fragment[2:] if fragment.startswith("1.") else fragment
    pad = (-len(raw)) % 4
    data = base64.urlsafe_b64decode(raw + ("=" * pad))
    return json.loads(data.decode("utf-8"))


def encode_toggles(include_name, include_allergies, include_ice, include_meds, profile) -> dict | None:
    card = {}
    if include_name:
        card["n"] = profile["name"]
    if include_allergies:
        card["a"] = profile.get("allergies") or ""
    if include_ice:
        ice = {}
        if profile.get("ice_name"):
            ice["n"] = profile["ice_name"]
        if profile.get("ice_rel"):
            ice["r"] = profile["ice_rel"]
        if profile.get("ice_phone"):
            ice["p"] = profile["ice_phone"]
        card["i"] = ice
    if include_meds:
        card["m"] = [
            ({"n": med["n"], "d": med["d"]} if med.get("d") else {"n": med["n"]})
            for med in profile["meds"]
        ]
    return card or None


PROFILE = {
    "name": "陳大文",
    "allergies": "盤尼西林 / penicillin",
    "ice_name": "Lee Mei",
    "ice_rel": "Daughter",
    "ice_phone": "+85261234567",
    "meds": [{"n": "Aspirin", "d": "81mg"}, {"n": "Metformin", "d": "500mg"}],
}


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def test_round_trip() -> None:
    card = encode_toggles(True, True, True, True, PROFILE)
    frag = fragment_for(card)
    decoded = decode_fragment(frag)
    check(decoded["n"] == "陳大文", "name round-trip")
    check(decoded["a"].startswith("盤尼西林"), "allergies round-trip")
    check(decoded["i"]["p"] == "+85261234567", "ICE phone round-trip")
    check(decoded["m"][1]["n"] == "Metformin", "medication round-trip")
    url = qr_string_for(card)
    check(url.startswith(VIEWER + "#1."), "hosted URL + versioned fragment")
    check("#" in url and "盤尼西林" not in url.split("#", 1)[0], "PHI is only in the fragment")
    check(len(url.encode("utf-8")) < 900, f"comfortable QR size, got {len(url.encode('utf-8'))}")


def test_toggles_omit_fields() -> None:
    name_only = encode_toggles(True, False, False, False, PROFILE)
    check(set(name_only) == {"n"}, "name-only card")
    check("a" not in decode_fragment(fragment_for(name_only)), "allergies omitted")

    no_meds = encode_toggles(True, True, True, False, PROFILE)
    decoded = decode_fragment(fragment_for(no_meds))
    check("m" not in decoded, "medications omitted when toggle is off")
    check("i" in decoded, "ICE kept when toggle is on")

    empty = encode_toggles(False, False, False, False, PROFILE)
    check(empty is None, "no fields selected")


def test_viewer_is_self_contained() -> None:
    html = MC_HTML.read_text(encoding="utf-8")
    check("<!DOCTYPE html>" in html, "html document")
    check("PillPal Medical Card" in html, "clear title")
    check("這不是正式醫療證件或診斷" in html, "Chinese disclaimer")
    check("This is not an official medical ID or a diagnosis" in html, "English disclaimer")
    check("僅供個人參考" in html, "Chinese reference-only")
    check("for personal reference only" in html, "English reference-only")
    check("location.hash" in html, "reads fragment only")
    check("textContent" in html, "does not inject raw HTML for values")
    check(not re.search(r'<link[^>]+href=', html), "no external stylesheet")
    check(not re.search(r'<script[^>]+src=', html), "no external script")
    check("noindex" in html, "viewer is not a public medical record page")


def main() -> int:
    test_round_trip()
    test_toggles_omit_fields()
    test_viewer_is_self_contained()
    full = qr_string_for(encode_toggles(True, True, True, True, PROFILE))
    name_only = qr_string_for(encode_toggles(True, False, False, False, PROFILE))
    print("OK")
    print(f"FULL {full}")
    print(f"NAME {name_only}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
