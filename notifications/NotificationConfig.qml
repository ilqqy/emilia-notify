pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Transparent side-pose art; the card is always live QML.
    readonly property url emiliaSource: Qt.resolvedUrl("../assets/emilia_side_body.png")
    // Optional registered transparent foreground layer. Empty uses hand crops
    // from the body, so final layered artwork can be swapped without UI edits.
    property url handSource: ""
    readonly property rect bodySourceRect: Qt.rect(0, 0, 1024, 1536)
    readonly property rect upperHandSourceRect: Qt.rect(402, 430, 112, 110)

    property real emiliaScale: 0.25
    property real emiliaX: 284
    property real emiliaY: 0
    property real cardX: 8
    property real cardY: 118
    property real cardWidth: 410
    property real cardHeight: 150
    property real cardMinHeight: 150
    property real cardMaxHeight: 218
    property real handX: emiliaX
    property real handY: emiliaY
    property real handScale: emiliaScale

    property int popupTopMargin: 12
    property int popupRightMargin: 0
    property real shownOffsetX: 0
    property real hiddenOffsetX: popupWidth + Math.max(0, popupRightMargin)

    // Motion and lifetime tuning.
    property int showDuration: 340
    property int hideDuration: 270
    property int defaultTimeout: 5000
    property int lowTimeout: 4200
    property int criticalTimeout: 15000
    property int minimumRequestedTimeout: 1500
    property int maximumRequestedTimeout: 30000

    // Card metrics.
    property int cardPadding: 16
    property int cardGripInset: 10
    property int cardTopGripInset: 3
    property int cardRadius: 18
    property int iconSize: 27
    property int imageSize: 42
    property int actionHeight: 26
    property int actionSpacing: 5
    property int contentSpacing: 5
    property int titleMaxLines: 2
    property int bodyMaxLines: 3

    readonly property real bodyWidth: bodySourceRect.width * emiliaScale
    readonly property real bodyHeight: bodySourceRect.height * emiliaScale
    readonly property real popupWidth: Math.ceil(Math.max(
        emiliaX + bodyWidth, cardX + cardWidth))
    readonly property real popupHeight: Math.ceil(Math.max(
        emiliaY + bodyHeight, cardY + cardMaxHeight) + popupTopMargin + 8)
}
