import QtQuick
import Quickshell

QtObject {
    id: root

    required property var notification
    readonly property real notificationId: notification ? notification.id : -1

    signal closed(int reason)

    // A notification is normally destroyed as soon as its closed handler
    // returns. Retaining it keeps the visual bindings valid through the exit.
    property RetainableLock notificationLock: RetainableLock {
        object: root.notification
        locked: true
    }

    property Connections notificationConnections: Connections {
        target: root.notification
        enabled: root.notification !== null

        function onClosed(reason): void {
            root.closed(reason);
        }
    }
}
