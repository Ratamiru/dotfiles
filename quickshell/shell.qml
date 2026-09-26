import Quickshell // for PanelWindow
import QtQuick // for Text
import Quickshell.Io //
import "./layers" as Lay

// ShellRoot главный узел, невидимый, под ним уже будут рождаться узлы 
  ShellRoot {
    Lay.PowerMenu {}
    Lay.AudioSink {}
    Lay.ToolsMenu {}
    Lay.Notes {}
    Lay.Projects {}
    Lay.LockScreen {}
    Lay.Music {}
  }
