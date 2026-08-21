import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.caideny.game-launcher"
  ipcTarget: "io.github.caideny.game-launcher"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property int activeTab: 0
  property var allGames: []
  property var steamGames: []
  property var lutrisGames: []
  property var heroicGames: []
  property var bottlesGames: []
  property var flatpakGames: []
  property string searchQuery: ""
  property bool scanning: false
  property int totalGames: allGames.length

  property bool steamEnabled: setting("steamEnabled", true)
  property bool lutrisEnabled: setting("lutrisEnabled", true)
  property bool heroicEnabled: setting("heroicEnabled", true)
  property bool bottlesEnabled: setting("bottlesEnabled", true)
  property bool flatpakEnabled: setting("flatpakEnabled", true)

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var tabs: ["Games", "Launchers", "Settings"]
  property int tabIndex: 0

  function open() {
    refresh()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened && root.bar && "centerHoverRevealSuppressed" in root.bar)
        root.bar.centerHoverRevealSuppressed = true
    })
  }

  function close() {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = false
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) close()
    else open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var e in root.settings) if (e !== "id") entry[e] = root.settings[e]
    for (var k in values) entry[k] = values[k]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function refresh() {
    scanning = true
    allGames = []
    if (steamEnabled && !steamFoldersProc.running) steamFoldersProc.running = true
    if (lutrisEnabled && !lutrisProc.running) lutrisProc.running = true
    if (heroicEnabled) {
      if (!heroicEpicProc.running) heroicEpicProc.running = true
      if (!heroicGogProc.running) heroicGogProc.running = true
      if (!heroicAmazonProc.running) heroicAmazonProc.running = true
    }
    if (bottlesEnabled && !bottlesProc.running) bottlesProc.running = true
    if (flatpakEnabled && !flatpakProc.running) flatpakProc.running = true
  }

  function collectGames() {
    var merged = Model.mergeGames(
      steamGames.concat(lutrisGames, heroicGames, bottlesGames, flatpakGames)
    )
    allGames = Model.sortGames(merged)
    scanning = false
  }

  function filteredGames() {
    return Model.filterGames(allGames, searchQuery)
  }

  function launchGame(game) {
    if (!game) return
    if (game.launchUrl && game.launchUrl !== "") {
      Quickshell.execDetached(["bash", "-c", "xdg-open " + game.launchUrl])
    }
    close()
  }

  function openLauncher(name) {
    var cmds = { "steam": "steam", "lutris": "lutris", "heroic": "heroic", "bottles": "bottles" }
    var cmd = cmds[name]
    if (cmd) {
      Quickshell.execDetached([cmd])
      close()
    }
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      tabIndex = 0
      searchQuery = ""
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(mainCol.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          var n = root.tabIndex + (dx > 0 ? 1 : -1)
          if (n >= 0 && n < root.tabs.length) root.tabIndex = n
        }
      }
      onCloseRequested: root.close()
      onTabRequested: function(dir) { root.switchPanel(dir) }
      onTextKey: function(t) {
        if (t === "1") root.tabIndex = 0
        else if (t === "2") root.tabIndex = 1
        else if (t === "3") root.tabIndex = 2
        else if (t === "r" || t === "R") root.refresh()
      }
    }

    Column {
      id: mainCol
      width: parent.width
      spacing: 0

      Item {
        width: parent.width
        height: heroIcon.implicitHeight + Style.space(12)
        Text {
          id: heroIcon
          anchors.left: parent.left
          anchors.leftMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          text: "\uf11b"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: 36
        }
        Column {
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(12)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - heroIcon.width - Style.space(16)
          Text {
            text: "Game Library"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            width: parent.width
            text: root.scanning ? "Scanning..." : Model.formatGameCount(root.allGames)
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.letterSpacing: 1
          }
        }
      }

      Rectangle {
        width: parent.width
        height: Style.space(32)
        color: "transparent"
        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)
          Repeater {
            model: root.tabs
            Rectangle {
              required property string modelData
              required property int index
              width: tabLbl.implicitWidth + Style.space(24)
              height: parent.height
              radius: Style.cornerRadius
              color: root.tabIndex === index
                ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                : (tabMs.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) : "transparent")
              Text {
                id: tabLbl
                anchors.centerIn: parent
                text: modelData.toUpperCase()
                color: root.tabIndex === index ? root.contentForeground : Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: root.tabIndex === index
                font.letterSpacing: 1
              }
              MouseArea {
                id: tabMs
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.tabIndex = index
              }
            }
          }
        }
      }

      PanelSeparator { width: parent.width; foreground: root.contentForeground }

      // Tab content
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.tabIndex === 0

        Rectangle {
          width: parent.width
          height: Style.space(34)
          radius: Style.cornerRadius
          color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06)
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(6)
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "\uf002"
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
            TextInput {
              id: searchField
              width: parent.width - Style.space(20)
              anchors.verticalCenter: parent.verticalCenter
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              clip: true
              selectByMouse: true
              selectionColor: Color.accent
              onTextChanged: root.searchQuery = text
              Keys.onEscapePressed: { text = ""; root.searchQuery = "" }
              Text {
                visible: !searchField.text && !searchField.activeFocus
                anchors.verticalCenter: parent.verticalCenter
                text: "Search games..."
                color: Qt.darker(root.contentForeground, 1.8)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
            }
          }
        }

        Flickable {
          width: parent.width
          height: Style.space(360)
          contentHeight: gamesCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          Column {
            id: gamesCol
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              model: root.filteredGames()
              Rectangle {
                required property var modelData
                required property int index
                width: gamesCol.width
                height: Style.space(36)
                radius: Style.cornerRadius
                color: rowMouse.containsMouse
                  ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
                  : "transparent"
                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.launchGame(modelData)
                }
                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.launcherIcon(modelData.launcher)
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.6)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - badgeLbl.width - Style.space(24)
                    text: modelData.name
                    color: rowMouse.containsMouse ? root.contentForeground : Qt.darker(root.contentForeground, 1.2)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }
                  Text {
                    id: badgeLbl
                    anchors.verticalCenter: parent.verticalCenter
                    text: Model.launcherDisplayName(modelData.launcher)
                    color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.5)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Text {
              width: gamesCol.width
              height: Style.space(80)
              visible: root.filteredGames().length === 0 && !root.scanning
              text: root.allGames.length === 0 ? "No games found" : "No matches"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            Text {
              width: gamesCol.width
              height: Style.space(80)
              visible: root.scanning
              text: "Scanning for games..."
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }

      // Launchers tab
      Grid {
        width: parent.width
        columns: 2
        spacing: Style.space(8)
        visible: root.tabIndex === 1

        Repeater {
          model: ListModel {
            ListElement { key: "steam"; label: "STEAM"; icon: "\uf1b6" }
            ListElement { key: "lutris"; label: "LUTRIS"; icon: "\uf11b" }
            ListElement { key: "heroic"; label: "HEROIC"; icon: "\uf3ed" }
            ListElement { key: "bottles"; label: "BOTTLES"; icon: "\uf0c3" }
          }
          Rectangle {
            required property var modelData
            required property int index
            width: (parent.width - Style.space(8)) / 2
            height: Style.space(80)
            radius: Style.cornerRadius
            color: lncMouse.containsMouse
              ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)
              : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.04)
            MouseArea {
              id: lncMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openLauncher(modelData.key)
            }
            Column {
              anchors.centerIn: parent
              spacing: Style.space(4)
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.icon
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                color: Qt.darker(root.contentForeground, 1.3)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1
              }
            }
          }
        }
      }

      // Settings tab
      Column {
        width: parent.width
        spacing: Style.space(8)
        visible: root.tabIndex === 2

        Text {
          text: "GAME SOURCES"
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
        }

        Repeater {
          model: ListModel {
            ListElement { lbl: "Steam"; key: "steamEnabled"; ic: "\uf1b6" }
            ListElement { lbl: "Lutris"; key: "lutrisEnabled"; ic: "\uf11b" }
            ListElement { lbl: "Heroic"; key: "heroicEnabled"; ic: "\uf3ed" }
            ListElement { lbl: "Bottles"; key: "bottlesEnabled"; ic: "\uf0c3" }
            ListElement { lbl: "Flatpak"; key: "flatpakEnabled"; ic: "\uf187" }
          }
          Rectangle {
            id: rowItem
            required property var modelData
            required property int index
            width: parent.width
            height: Style.space(40)
            radius: Style.cornerRadius
            color: sMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.06) : "transparent"
            property bool isEnabled: root.settings && root.settings[modelData.key] !== undefined ? root.settings[modelData.key] : true
            MouseArea {
              id: sMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var current = rowItem.isEnabled
                var u = {}
                u[modelData.key] = !current
                root.persistSettings(u)
              }
            }
            Row {
              id: sRow
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(10)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(20)
                text: modelData.ic
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(70)
                text: modelData.lbl
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(36)
                height: Style.space(20)
                radius: height / 2
                color: rowItem.isEnabled ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.15)
                Rectangle {
                  x: rowItem.isEnabled ? parent.width - width - 2 : 2
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(16)
                  height: Style.space(16)
                  radius: width / 2
                  color: "white"
                  Behavior on x { NumberAnimation { duration: 120 } }
                }
              }
            }
          }
        }

        PanelSeparator { width: parent.width; foreground: root.contentForeground }

        Rectangle {
          width: parent.width
          height: Style.space(40)
          radius: Style.cornerRadius
          color: rescanMouse.containsMouse ? Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12) : "transparent"
          border.width: 1
          border.color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.2)
          MouseArea {
            id: rescanMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.refresh()
          }
          Text {
            anchors.centerIn: parent
            text: "\uf021  SCAN NOW"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }
        }
      }
    }
  }

  // ── Processes ──────────────────────────────────────────────────────────

  Process {
    id: steamFoldersProc
    command: ["bash", "-c", `
      USER_HOME="$HOME"
      # Read libraryfolders.vdf for known Steam library paths
      VDF="$USER_HOME/.steam/steam/steamapps/libraryfolders.vdf"
      PATHS=""
      if [ -f "$VDF" ]; then
        PATHS=$(grep -oP '"path"\\s*"\\K[^"]*' "$VDF" 2>/dev/null | sed 's/\\\\\\//\\//g')
      fi
      # Always include default Steam path
      ALL_PATHS="$USER_HOME/.steam/steam"
      for p in $PATHS; do
        case " $ALL_PATHS " in *" $p "*) ;; *) ALL_PATHS="$ALL_PATHS $p" ;; esac
      done
      # Scan all known paths
      for p in $ALL_PATHS; do
        for f in "$p"/steamapps/appmanifest_*.acf; do
          [ -f "$f" ] && printf '===LIB:%s===\\n' "$p" && cat "$f"
        done
      done 2>/dev/null
      # Scan mounted drives for additional Steam libraries
      for mount in /mnt/* /media/$USER/* /run/media/$USER/*; do
        [ -d "$mount" ] || continue
        case "$(readlink -f "$mount" 2>/dev/null)" in
          /boot*|/proc*|/sys*|/dev*|/run/user*) continue ;;
        esac
        find "$mount" -maxdepth 4 -name "appmanifest_*.acf" 2>/dev/null | while read f; do
          dir=$(dirname "$f" | sed 's|/steamapps$||')
          # Skip if already scanned from known paths
          case " $ALL_PATHS " in *" $dir "*) continue ;; esac
          printf '===LIB:%s===\\n' "$dir" && cat "$f"
        done
      done
    `]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.steamGames = []
        var chunks = text.split("===LIB:")
        for (var i = 1; i < chunks.length; i++) {
          var chunk = chunks[i]
          var libEnd = chunk.indexOf("===")
          if (libEnd < 0) continue
          var libPath = chunk.substring(0, libEnd)
          var acfContent = chunk.substring(libEnd + 3)
          var acfParts = acfContent.split(/AppID/)
          for (var j = 0; j < acfParts.length; j++) {
            var games = Model.steamGamesFromContent(acfParts[j], libPath)
            root.steamGames = root.steamGames.concat(games)
          }
        }
        root.collectGames()
      }
    }
  }

  Process {
    id: lutrisProc
    command: ["bash", "-c", "which lutris >/dev/null 2>&1 && lutris --list-games --installed --json 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.lutrisGames = Model.parseLutrisJson(text); root.collectGames() }
    }
  }

  Process {
    id: heroicEpicProc
    command: ["bash", "-c", "cat $HOME/.config/heroic/library/epicLibrary.json 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.heroicGames = root.heroicGames.concat(Model.parseHeroicLibrary(text, "epic")); root.collectGames() }
    }
  }

  Process {
    id: heroicGogProc
    command: ["bash", "-c", "cat $HOME/.config/heroic/library/gog_library.json 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.heroicGames = root.heroicGames.concat(Model.parseHeroicLibrary(text, "gog")); root.collectGames() }
    }
  }

  Process {
    id: heroicAmazonProc
    command: ["bash", "-c", "cat $HOME/.config/heroic/library/amazon_library.json 2>/dev/null || echo '[]'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.heroicGames = root.heroicGames.concat(Model.parseHeroicLibrary(text, "amazon")); root.collectGames() }
    }
  }

  Process {
    id: bottlesProc
    command: ["bash", "-c", "find $HOME/.local/share/bottles/bottles -name 'bottle.yml' -exec cat {} \\; 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.bottlesGames = Model.parseBottlesYaml(text); root.collectGames() }
    }
  }

  Process {
    id: flatpakProc
    command: ["bash", "-c", "which flatpak >/dev/null 2>&1 && flatpak list --app --columns=application,name 2>/dev/null || echo ''"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { root.flatpakGames = Model.parseFlatpakList(text); root.collectGames() }
    }
  }

  Component.onCompleted: { if (steamEnabled) steamFoldersProc.running = true }
}
