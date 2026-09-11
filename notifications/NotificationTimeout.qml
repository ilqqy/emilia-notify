import QtQuick
import Quickshell.Services.Notifications

// Lifetime starts after entry animation. A zero protocol timeout is persistent;
// a timed notification with zero remaining time must still expire on resume.
Item {
    id: root

    property var notification: null
    property bool active: false
    property bool paused: false
    property real remaining: 0
    property bool persistent: true
    property double startedAt: 0
    readonly property bool running: timer.running
    signal expired()

    function durationFor(notification): real {
        if (!notification || notification.expireTimeout === 0)
            return 0;
        if (notification.expireTimeout > 0)
            return Math.max(NotificationConfig.minimumRequestedTimeout,
                Math.min(NotificationConfig.maximumRequestedTimeout,
                    notification.expireTimeout));
        if (notification.urgency === NotificationUrgency.Critical)
            return NotificationConfig.criticalTimeout;
        if (notification.urgency === NotificationUrgency.Low)
            return NotificationConfig.lowTimeout;
        return NotificationConfig.defaultTimeout;
    }

    function reset(): void {
        timer.stop();
        remaining = durationFor(notification);
        persistent = remaining === 0;
        synchronize();
    }

    function synchronize(): void {
        if (timer.running) {
            remaining = Math.max(0, remaining - (Date.now() - startedAt));
            timer.stop();
        }
        if (active && !paused && !persistent) {
            startedAt = Date.now();
            timer.interval = Math.max(1, Math.ceil(remaining));
            timer.start();
        }
    }

    onActiveChanged: {
        if (active) reset();
        else synchronize();
    }
    onPausedChanged: synchronize()
    onNotificationChanged: reset()

    Timer {
        id: timer
        onTriggered: {
            root.remaining = 0;
            root.expired();
        }
    }
}
