import QtQuick
import Quickshell
import "notifications" as Notifications

ShellRoot {
    Notifications.NotificationQueue {
        id: notificationQueue
    }

    Notifications.NotificationService {
        queue: notificationQueue
    }

    Notifications.NotificationPopup {
        queue: notificationQueue
    }
}

