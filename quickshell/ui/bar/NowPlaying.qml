import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.ui.neu

// MPRIS, replacing the waybar nowplaying.sh polling loop.
BarButton {
    id: root

    readonly property var player: {
        for (const p of Mpris.players.values)
            if (p.playbackState === MprisPlaybackState.Playing)
                return p;
        return Mpris.players.values.length > 0 ? Mpris.players.values[0] : null;
    }

    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    visible: player !== null
    icon: playing ? Icons.play : Icons.pause
    tint: playing ? Theme.neuAccentText : Theme.neuTextDim

    label: {
        if (!player) return "";
        const t = player.trackTitle || "";
        const a = player.trackArtist || "";
        const s = a ? a + " — " + t : t;
        return s.length > 42 ? s.slice(0, 41) + "…" : s;
    }

    onActivated: if (player && player.canTogglePlaying) player.togglePlaying()
    onScrolled: (d) => {
        if (!player) return;
        if (d > 0 && player.canGoNext) player.next();
        else if (d < 0 && player.canGoPrevious) player.previous();
    }
}
