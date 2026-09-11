import QtQuick

Item {
    id: root

    property var entries: []
    property bool waitingForHide: false

    readonly property int count: entries.length
    readonly property var currentEntry: entries.length > 0 ? entries[0] : null
    readonly property var currentNotification: currentEntry
        ? currentEntry.notification
        : null

    signal currentAvailable(var notification)
    signal currentClosed(int reason)
    signal currentUpdated()
    signal queueChanged()

    function indexOfId(notificationId: real): int {
        for (let index = 0; index < root.entries.length; ++index) {
            if (root.entries[index].notificationId === notificationId)
                return index;
        }
        return -1;
    }

    function enqueue(notification: var): void {
        if (!notification || root.indexOfId(notification.id) !== -1)
            return;

        const wasEmpty = root.entries.length === 0;
        const entry = entryComponent.createObject(root, { "notification": notification });
        if (!entry) {
            console.warn("emilia-notifications: could not create queue entry");
            notification.dismiss();
            return;
        }

        entry.closed.connect(reason => root.handleClosed(entry, reason));

        const next = root.entries.slice();
        next.push(entry);
        root.entries = next;
        root.queueChanged();

        if (wasEmpty)
            root.currentAvailable(notification);
    }

    function handleClosed(entry: var, reason: int): void {
        const index = root.entries.indexOf(entry);
        if (index < 0)
            return;

        if (index === 0) {
            if (!root.waitingForHide) {
                root.waitingForHide = true;
                root.currentClosed(reason);
            }
            return;
        }

        const next = root.entries.slice();
        next.splice(index, 1);
        root.entries = next;
        root.queueChanged();
        entry.destroy();
    }

    function dismissCurrent(): void {
        if (root.currentNotification && !root.waitingForHide)
            root.currentNotification.dismiss();
    }

    function expireCurrent(): void {
        if (root.currentNotification && !root.waitingForHide)
            root.currentNotification.expire();
    }

    function finishCurrentHide(): void {
        if (!root.waitingForHide || root.entries.length === 0)
            return;

        const oldEntry = root.entries[0];
        const next = root.entries.slice(1);
        root.entries = next;
        root.waitingForHide = false;
        root.queueChanged();
        oldEntry.destroy();

        if (next.length > 0)
            root.currentAvailable(next[0].notification);
    }

    Connections {
        target: root.currentNotification
        enabled: root.currentNotification !== null && !root.waitingForHide

        function onExpireTimeoutChanged(): void { root.currentUpdated(); }
        function onAppNameChanged(): void { root.currentUpdated(); }
        function onAppIconChanged(): void { root.currentUpdated(); }
        function onSummaryChanged(): void { root.currentUpdated(); }
        function onBodyChanged(): void { root.currentUpdated(); }
        function onUrgencyChanged(): void { root.currentUpdated(); }
        function onActionsChanged(): void { root.currentUpdated(); }
        function onImageChanged(): void { root.currentUpdated(); }
        function onHintsChanged(): void { root.currentUpdated(); }
    }

    Component {
        id: entryComponent

        NotificationQueueEntry {}
    }
}
