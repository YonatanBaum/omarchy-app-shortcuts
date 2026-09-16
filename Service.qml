import QtQuick
import Quickshell
import Quickshell.Io

// Keeps the shortcut library in step with the installed apps.
//
// Shortly after the shell starts, and whenever a .desktop file is added,
// changed or removed in any applications directory, shortcuts.py rescans the
// installed apps and looks up shortcuts for any app that has none yet. The
// overlay reads the same library through the helper, so it works even while a
// sync is running.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool syncQueued: false

  readonly property string helper: {
    var url = String(Qt.resolvedUrl("shortcuts.py"))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : url
  }

  function sync() {
    if (syncProc.running) {
      syncQueued = true
      return
    }
    syncProc.command = [helper, "sync"]
    syncProc.running = true
  }

  Process {
    id: syncProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var line = text.trim()
        if (line !== "") console.log("funcoder.app-shortcuts: sync " + line)
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var line = text.trim()
        if (line !== "") console.warn("funcoder.app-shortcuts: " + line)
      }
    }
    onExited: {
      if (root.syncQueued) {
        root.syncQueued = false
        root.sync()
      }
    }
  }

  // One inotifywait for every applications directory that exists; pacman,
  // flatpak and omarchy-webapp-install all drop .desktop files into these.
  Process {
    id: watcher
    running: true
    command: ["bash", "-c",
      "dirs=(); for d in \"$HOME/.local/share/applications\" /usr/local/share/applications /usr/share/applications "
      + "\"$HOME/.local/share/flatpak/exports/share/applications\" /var/lib/flatpak/exports/share/applications; "
      + "do [[ -d $d ]] && dirs+=(\"$d\"); done; "
      + "exec inotifywait -m -q -e create,moved_to,close_write,delete,moved_from --format %f \"${dirs[@]}\""]
    stdout: SplitParser {
      onRead: function(line) {
        if (String(line).endsWith(".desktop")) debounce.restart()
      }
    }
    onExited: restartWatcher.start()
  }

  // Package installs write several files in a burst; sync once it settles.
  Timer {
    id: debounce
    interval: 5000
    onTriggered: root.sync()
  }

  Timer {
    id: restartWatcher
    interval: 30000
    onTriggered: watcher.running = true
  }

  Timer {
    interval: 20000
    running: true
    onTriggered: root.sync()
  }

  // Retries failed lookups (the helper waits a day between attempts).
  Timer {
    interval: 6 * 3600 * 1000
    running: true
    repeat: true
    onTriggered: root.sync()
  }
}
