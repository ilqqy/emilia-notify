import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "notifications" as N

ShellRoot {
    id: harness
    N.NotificationQueue { id: notificationQueue }
    LazyLoader {
        active: Quickshell.env("EMILIA_TEST_SESSION") === "1"
        component: N.NotificationService { queue: notificationQueue }
    }
    N.NotificationPopup {
        id: popup
        queue: notificationQueue
    }
    TestEvent { id: events }

    function findItem(item, name) {
        if (item.objectName === name) return item;
        for (const child of item.children || []) {
            const found = findItem(child, name);
            if (found) return found;
        }
        return null;
    }

    IpcHandler {
        target: "test"
        function state(): string {
            const card = harness.findItem(popup.contentItem, "notificationCard");
            const close = harness.findItem(card, "closeButton");
            const strip = harness.findItem(card, "actionStrip");
            const body = harness.findItem(card, "bodyText");
            return JSON.stringify({
                ids: notificationQueue.entries.map(entry => entry.notificationId),
                summary: notificationQueue.currentNotification ? notificationQueue.currentNotification.summary : "",
                phase: popup.animationState, hovered: card.hovered,
                compositionX: card.parent.x, compositionY: card.parent.y,
                screenName: popup.screen ? popup.screen.name : "",
                cardX: card.x, emiliaX: N.NotificationConfig.emiliaX,
                shownOffsetX: N.NotificationConfig.shownOffsetX,
                topMargin: N.NotificationConfig.popupTopMargin,
                cardHeight: card.height, cardWidth: card.width,
                actions: card.buttonActions.length, enabled: card.enabled,
                iconVisible: harness.findItem(card, "appIcon").visible,
                imageVisible: harness.findItem(card, "attachment").visible,
                closeBottom: close.mapToItem(card, 0, close.height).y,
                actionsBottom: strip.mapToItem(card, 0, strip.height).y,
                bodyHeight: body.height,
                maskWidth: popup.mask.width, maskY: popup.mask.y
            });
        }
        function hover(inside: bool): bool {
            const card = harness.findItem(popup.contentItem, "notificationCard");
            return events.mouseMove(card, inside ? card.width / 2 : -20,
                inside ? card.height / 2 : -20, 0, Qt.NoButton, Qt.NoModifier);
        }
        function click(name: string): bool {
            const item = harness.findItem(popup.contentItem, name);
            if (!item) return false;
            return events.mouseClick(item, item.width / 2, item.height / 2,
                Qt.LeftButton, Qt.NoModifier, 0);
        }
        function scrollActions(): void {
            const strip = harness.findItem(popup.contentItem, "actionStrip");
            events.mouseWheel(strip, strip.width / 2, strip.height / 2,
                Qt.NoButton, Qt.NoModifier, 0, -1200, 0);
        }
        function capture(path: string): void {
            harness.findItem(popup.contentItem, "notificationComposition")
                .grabToImage(result => result.saveToFile(path));
        }
        function exhaustPausedTimeout(): void {
            harness.findItem(popup.contentItem, "notificationLifetime").remaining = 0;
        }
        function reload(): void { Qt.callLater(Quickshell.reload, true); }
    }
}
