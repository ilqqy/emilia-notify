import QtQuick
import Quickshell.Services.Notifications

Item {
    id: root

    required property var queue

    NotificationServer {
        id: server

        // Do not replay stale popups when QML reloads. The old generation is
        // expired by Quickshell before this server begins accepting new ones.
        keepOnReload: false
        persistenceSupported: false
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: false

        onNotification: notification => {
            if (notification.lastGeneration) {
                notification.expire();
                return;
            }

            notification.tracked = true;
            root.queue.enqueue(notification);
        }
    }
}

