// ── Steam ────────────────────────────────────────────────────────────────────

function parseLibraryFoldersVdf(text) {
  var paths = []
  var re = /^\s*"path"\s+"(.+?)"/gm
  var m
  while ((m = re.exec(text)) !== null) {
    var p = m[1].replace(/\\\\/g, "/")
    if (paths.indexOf(p) < 0) paths.push(p)
  }
  return paths
}

function parseAcfValue(text, key) {
  var re = new RegExp('"' + key + '"\\s+"([^"]*)"')
  var m = re.exec(text)
  return m ? m[1] : ""
}

function parseAcfFile(content) {
  return {
    name: parseAcfValue(content, "name"),
    appid: parseAcfValue(content, "appid"),
    installdir: parseAcfValue(content, "installdir"),
    lastPlayed: parseInt(parseAcfValue(content, "LastPlayed") || "0", 10)
  }
}

function steamGamesFromContent(content, libraryPath) {
  var games = []
  var game = parseAcfFile(content)
  if (game.appid && game.name) {
    var lower = game.name.toLowerCase()
    if (lower.indexOf("proton") >= 0) return games
    if (lower.indexOf("steam linux runtime") >= 0) return games
    if (lower.indexOf("steamworks common redistributables") >= 0) return games
    if (lower.indexOf("windows") >= 0 && lower.indexOf("runtime") >= 0) return games
    if (game.appid === "961940" || game.appid === "1392830" || game.appid === "1493700") return games
    if (game.appid === "1070000" || game.appid === "1070010" || game.appid === "1113840") return games
    game.launcher = "steam"
    game.launcherIcon = "steam"
    game.launchUrl = "steam://rungameid/" + game.appid
    game.installPath = libraryPath + "/steamapps/common/" + game.installdir
    games.push(game)
  }
  return games
}

// ── Lutris ───────────────────────────────────────────────────────────────────

function parseLutrisJson(text) {
  var games = []
  try {
    var data = JSON.parse(text)
    var list = Array.isArray(data) ? data : (data.games || [])
    for (var i = 0; i < list.length; i++) {
      var g = list[i]
      if (!g) continue
      games.push({
        name: g.name || g.slug || "Unknown",
        appid: String(g.id || g.slug || ""),
        launcher: "lutris",
        launcherIcon: "lutris",
        launchUrl: "lutris:rungameid/" + g.id,
        installPath: g.install_path || "",
        lastPlayed: g.lastplayed || 0,
        runner: g.runner || ""
      })
    }
  } catch (e) {}
  return games
}

// ── Heroic ───────────────────────────────────────────────────────────────────

function parseHeroicLibrary(text, store) {
  var games = []
  try {
    var data = JSON.parse(text)
    var list = Array.isArray(data) ? data : (data.library || data.games || [])
    for (var i = 0; i < list.length; i++) {
      var g = list[i]
      if (!g) continue
      var installed = g.install || g.is_installed || (g.install_path && g.install_path !== "")
      if (!installed) continue
      games.push({
        name: g.title || g.app_name || g.name || "Unknown",
        appid: g.app_name || g.appId || g.id || "",
        launcher: "heroic-" + store,
        launcherIcon: "heroic",
        launchUrl: "heroic://launch/" + (g.app_name || g.appId || ""),
        installPath: g.install_path || "",
        lastPlayed: g.lastPlayed || g.last_played || 0,
        store: store
      })
    }
  } catch (e) {}
  return games
}

// ── Bottles ──────────────────────────────────────────────────────────────────

function parseBottlesYaml(text) {
  var games = []
  try {
    var data = JSON.parse(text)
    var programs = data.Installed || {}
    for (var key in programs) {
      if (!programs.hasOwnProperty(key)) continue
      var p = programs[key]
      games.push({
        name: p.name || key,
        appid: key,
        launcher: "bottles",
        launcherIcon: "bottles",
        launchUrl: "",
        installPath: p.path || "",
        lastPlayed: 0
      })
    }
  } catch (e) {}
  return games
}

// ── Flatpak ──────────────────────────────────────────────────────────────────

function parseFlatpakList(text) {
  var games = []
  var lines = text.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (!line) continue
    var parts = line.split("\t")
    if (parts.length >= 2) {
      games.push({
        name: parts[1] || parts[0],
        appid: parts[0],
        launcher: "flatpak",
        launcherIcon: "flatpak",
        launchUrl: "flatpak run " + parts[0],
        installPath: "",
        lastPlayed: 0
      })
    }
  }
  return games
}

// ── Merging & Sorting ────────────────────────────────────────────────────────

function mergeGames(allGames) {
  var seen = {}
  var result = []
  for (var i = 0; i < allGames.length; i++) {
    var g = allGames[i]
    var key = g.name.toLowerCase()
    if (seen[key] !== undefined) {
      if (g.installPath && !result[seen[key]].installPath) {
        result[seen[key]] = g
      }
    } else {
      seen[key] = result.length
      result.push(g)
    }
  }
  return result
}

function sortGames(games) {
  return games.sort(function(a, b) {
    var aPlayed = a.lastPlayed || 0
    var bPlayed = b.lastPlayed || 0
    if (aPlayed > 0 && bPlayed > 0) return bPlayed - aPlayed
    if (aPlayed > 0) return -1
    if (bPlayed > 0) return 1
    return a.name.localeCompare(b.name)
  })
}

function launcherDisplayName(launcher) {
  var names = {
    "steam": "Steam",
    "lutris": "Lutris",
    "heroic-epic": "Heroic (Epic)",
    "heroic-gog": "Heroic (GOG)",
    "heroic-amazon": "Heroic (Amazon)",
    "heroic-zoom": "Heroic (ZOOM)",
    "bottles": "Bottles",
    "flatpak": "Flatpak"
  }
  return names[launcher] || launcher
}

function launcherIcon(launcher) {
  var icons = {
    "steam": "\uf1b6",
    "lutris": "\uf11b",
    "heroic-epic": "\uf11b",
    "heroic-gog": "\uf11b",
    "heroic-amazon": "\uf11b",
    "heroic-zoom": "\uf11b",
    "bottles": "\uf0c3",
    "flatpak": "\uf187"
  }
  return icons[launcher] || "\uf11b"
}

function formatGameCount(games) {
  if (games.length === 0) return "No games"
  if (games.length === 1) return "1 game"
  return games.length + " games"
}

function filterGames(games, query) {
  if (!query || query === "") return games
  var lower = query.toLowerCase()
  return games.filter(function(g) {
    return g.name.toLowerCase().indexOf(lower) >= 0
      || g.launcher.toLowerCase().indexOf(lower) >= 0
  })
}
