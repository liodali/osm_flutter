package hamza.dali.flutter_osm_plugin.mapscore

/**
 * Decoder for the positional legacy `trackMe` payload
 * `[stopFollowInDrag, disableMarkerRotation, useDirectionMarker, anchor?]`.
 *
 * The anchor slot is null when the application did not request an override.
 * Null must stay "no override" instead of falling back to the centered
 * default, otherwise a legacy tracking start re-centers the pivots the
 * user-location icon route applied for the application's own icons.
 */
internal object LegacyTrackMeArguments {

    /** Normalized `[x, y]` anchor, or null when no override was requested. */
    fun anchor(args: List<*>): List<Double>? {
        val raw = args.getOrNull(ANCHOR_INDEX) as? List<*> ?: return null
        if (raw.size < 2) return null
        val x = raw[0] as? Double ?: return null
        val y = raw[1] as? Double ?: return null
        return listOf(x, y)
    }

    private const val ANCHOR_INDEX = 3
}
