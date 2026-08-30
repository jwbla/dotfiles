import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs
import qs.ui.neu

Row {
    id: root
    spacing: Theme.sizeXs

    Repeater {
        model: SystemTray.items

        Item {
            required property var modelData

            width: 22
            height: Theme.barHeight - Theme.sizeS * 2

            IconImage {
                anchors.centerIn: parent
                width: 18
                height: 18
                // SystemTray usually hands back a usable URL, but some clients
                // give a bare icon name; route those through the provider too.
                source: modelData.icon && modelData.icon.indexOf("/") === -1
                        && modelData.icon.indexOf(":") === -1
                            ? Quickshell.iconPath(modelData.icon, true)
                            : modelData.icon
                opacity: hover.hovered ? 1 : 0.8
                Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }
            }

            HoverHandler { id: hover }

            TapHandler {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onTapped: (e) => {
                    if (e.button === Qt.RightButton) modelData.display(null, 0, 0);
                    else modelData.activate();
                }
            }
        }
    }
}
