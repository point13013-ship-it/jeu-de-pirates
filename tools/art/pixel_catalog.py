"""Données du catalogue des pièces du pirate (libellés français, palettes, couleurs des couches, apparence par défaut)."""

# Couleur d'une couche : (catégorie, emplacement) -> canal de couleur du joueur, ou « #rrggbb » fixe.
LAYER_COLORS = {
    "pants.cloth": "pants", "pants.skin": "skin",
    "boots.boot": "boots", "boots.skin": "skin",
    "shirt.skin": "skin", "shirt.cloth": "shirt", "shirt.stripe": "shirt_stripe", "shirt.lace": "#d8c8a8",
    "coat.cloth": "coat", "coat.trim": "coat_trim",
    "belt.belt": "belt", "belt.buckle": "#e6b84a",
    "hands.skin": "skin", "head.skin": "skin", "nose.skin": "skin",
    "mark.patch": "#15101a", "mark.scar": "scar", "mark.frame": "#e6b84a",
    "eyes.white": "#f6f1e6", "eyes.iris": "eyes", "brows.hair": "hair", "mouth.mouth": "skin",
    "mouth.teeth": "#f6f1e6", "mouth.pipe": "#6b4423",
    "beard.hair": "hair", "mustache.hair": "hair", "hair.hair": "hair",
    "hat.hat": "hat", "hat.trim": "hat_trim",
    "weapon.metal": "#8a8d98", "weapon.wood": "#7a4a26",
}

CHANNELS = {  # canal -> (libellé, palette)
    "skin": ("Peau", ["#ffa57a", "#fbe0c8", "#f1c7a3", "#dca47a", "#bf8458", "#946039", "#6b4128", "#4a2c1c"]),
    "hair": ("Cheveux et barbe", ["#1b1410", "#3a2416", "#5a3a22", "#8a5a2e", "#b8823c", "#d8b86a", "#e8e0c8", "#a8402a",
                                  "#8a8a90"]),
    "eyes": ("Yeux", ["#3a2a1c", "#6b4423", "#2d5fa8", "#3f8f5f", "#8a8f94", "#a8281f", "#8a4fa8", "#e6b84a"]),
    "scar": ("Cicatrice", ["#c97a6e", "#a8504a", "#e0a8a0"]),
    "shirt": ("Chemise", ["#ffffff", "#f2ead8", "#d94a3b", "#2d5fa8", "#3f8f5f", "#e6b84a", "#2a2a33", "#8a4fa8", "#e8844a"]),
    "shirt_stripe": ("Rayures", ["#9adfe8", "#8cc4c8", "#2a3f78", "#a8281f", "#2a2a33", "#f2ead8"]),
    "coat": ("Manteau / gilet", ["#7a1f2a", "#223a66", "#2f5a3a", "#2a2a33", "#6b4423", "#d8c7a0", "#5a2f78", "#a8281f"]),
    "coat_trim": ("Parements", ["#e6b84a", "#d6d6d6", "#f2ead8", "#1b1410", "#a8281f"]),
    "pants": ("Pantalon", ["#232326", "#1c1c24", "#3a3a46", "#6b4423", "#2d4d8f", "#d8c7a0", "#2a2a33", "#7a1f2a", "#3f6f4a"]),
    "boots": ("Bottes", ["#2e1d14", "#5a3a22", "#1b1410", "#7a1f2a", "#8a8f94"]),
    "hat": ("Chapeau", ["#161616", "#33261c", "#2a2a33", "#7a1f2a", "#223a66", "#a8803a", "#8a3a2a", "#2f5a3a", "#5a4a3a"]),
    "hat_trim": ("Ruban du chapeau", ["#fafafa", "#e6b84a", "#d94a3b", "#f2ead8", "#1b1410", "#2d5fa8"]),
    "belt": ("Ceinture / écharpe", ["#ff4a40", "#4a2f1c", "#d94a3b", "#e6b84a", "#2a2a33", "#2d5fa8", "#f2ead8"]),
}

PART_LABELS = {  # catégorie -> (libellé, peut-être absente)
    "head": ("Visage", False), "hands": ("Mains", False), "nose": ("Nez", False), "eyes": ("Yeux", False),
    "brows": ("Sourcils", True), "mouth": ("Bouche", False), "mark": ("Signe", True), "hair": ("Coiffure", True),
    "beard": ("Barbe", True), "mustache": ("Moustache", True), "hat": ("Chapeau", True), "shirt": ("Haut", False),
    "coat": ("Manteau", True), "belt": ("Ceinture", True), "pants": ("Pantalon", False), "boots": ("Chaussures", False),
    "weapon": ("Arme (animations de tir)", True),
}


VARIANT_LABELS = {
    "head": {"round": "Rond"},
    "hands": {"bare": "Nues"},
    "nose": {"small": "Petit", "big": "Gros", "pointy": "Pointu", "round": "Rond", "flat": "Épaté"},
    "eyes": {"round": "Ronds", "narrow": "Fins", "angry": "Méchants", "wide": "Grands", "sleepy": "Endormis"},
    "brows": {"normal": "Normaux", "thick": "Épais", "angry": "Froncés", "raised": "Levés"},
    "mouth": {"smile": "Sourire", "neutral": "Neutre", "grin": "Grand sourire", "frown": "Boudeuse", "open": "Qui crie", "pipe": "Pipe"},
    "mark": {"patch_l": "Cache-œil gauche", "patch_r": "Cache-œil droit", "scar": "Cicatrice", "monocle": "Monocle", "earrings": "Boucles d'oreille"},
    "hair": {"short": "Courts", "buzz": "Ras", "long": "Longs", "ponytail": "Queue de cheval", "bun": "Chignon",
             "mohawk": "Crête", "afro": "Afro", "pigtails": "Couettes", "pompadour": "Banane", "dreads": "Dreadlocks",
             "bob": "Carré", "curly": "Bouclés"},
    "beard": {"stubble": "Barbe de trois jours", "goatee": "Bouc", "full": "Barbe pleine", "long": "Longue barbe",
              "braid": "Barbe tressée", "chinstrap": "Favoris", "twin": "Deux nattes", "forked": "Barbe fourchue",
              "chops": "Pattes", "bushy": "Broussaille"},
    "mustache": {"thin": "Fine", "handlebar": "Guidon", "walrus": "Morse", "chevron": "Chevron"},
    "hat": {"tricorn": "Tricorne", "bicorn": "Bicorne", "bandana": "Bandana", "straw": "Chapeau de paille",
            "cap": "Calot", "plume": "Chapeau à plume", "turban": "Turban", "headband": "Bandeau"},
    "shirt": {"bare": "Torse nu", "tee": "T-shirt", "pirate": "Chemise de pirate", "striped": "Marinière"},
    "coat": {"vest": "Gilet", "jacket": "Veste", "captain": "Manteau de capitaine"},
    "belt": {"belt": "Ceinture", "sash": "Écharpe", "baldric": "Baudrier"},
    "pants": {"long": "Long", "shorts": "Short", "rolled": "Retroussé"},
    "boots": {"high": "Hautes bottes", "shoes": "Souliers", "barefoot": "Pieds nus", "sandals": "Sandales"},
    "weapon": {"pistolet": "Pistolet", "tromblon": "Tromblon", "fusil": "Fusil", "sabre": "Sabre"},
}

DEFAULT_LOOK = {
    "parts": {"head": "round", "hands": "bare", "nose": "small", "eyes": "round", "brows": "normal", "mouth": "neutral",
              "hair": "long", "beard": "goatee", "mustache": "none", "hat": "bandana", "mark": "none",
              "shirt": "striped", "coat": "none", "belt": "sash", "pants": "long", "boots": "shoes"},
    "colors": {"skin": "#ffa57a", "hair": "#6b4423", "eyes": "#2c3a59", "scar": "#c97a6e", "shirt": "#ffffff",
               "shirt_stripe": "#9adfe8", "coat": "#7a1f2a", "coat_trim": "#e6b84a", "pants": "#232326",
               "boots": "#4c3b23", "hat": "#161616", "hat_trim": "#fafafa", "belt": "#ff4a40"},
}




CATEGORIES = ["pants", "boots", "shirt", "coat", "belt", "hands", "head", "nose", "mark", "eyes", "brows", "beard",
              "mouth", "mustache", "hair", "hat"]


def make_catalog(layers, frame, feet, anims, tones):
    """Le catalogue (data/character_parts.json) d'après les couches dessinées : id -> (catégorie, variante, emplacement)."""
    parts = {}
    for lid, (cat, var, slot, _fn) in layers.items():
        parts.setdefault(cat, {"variants": [], "layers": {}})
        if var not in parts[cat]["variants"]:
            parts[cat]["variants"].append(var)
        parts[cat]["layers"].setdefault(var, []).append({"id": lid, "slot": slot, "color": LAYER_COLORS[f"{cat}.{slot}"]})
    return {
        "frame": list(frame), "feet": list(feet), "directions": 8, "anims": dict(anims),
        "order": [c for c in CATEGORIES if c in parts],
        "parts": {c: {"label": PART_LABELS[c][0], "optional": PART_LABELS[c][1], **parts[c]} for c in parts},
        "channels": {k: {"label": v[0], "palette": v[1]} for k, v in CHANNELS.items()},
        "tones": list(tones), "labels": VARIANT_LABELS, "default_look": DEFAULT_LOOK,
    }
