package hamza.dali.flutter_osm_plugin.mapscore.fontloader

import android.content.Context
import android.graphics.BitmapFactory
import android.util.Log
import io.openmobilemaps.mapscore.graphics.BitmapTextureHolder
import io.openmobilemaps.mapscore.shared.graphics.common.Quad2dD
import io.openmobilemaps.mapscore.shared.graphics.common.Vec2D
import io.openmobilemaps.mapscore.shared.map.loader.Font
import io.openmobilemaps.mapscore.shared.map.loader.FontData
import io.openmobilemaps.mapscore.shared.map.loader.FontGlyph
import io.openmobilemaps.mapscore.shared.map.loader.FontLoaderInterface
import io.openmobilemaps.mapscore.shared.map.loader.FontLoaderResult
import io.openmobilemaps.mapscore.shared.map.loader.FontWrapper
import io.openmobilemaps.mapscore.shared.map.loader.LoaderStatus
import org.json.JSONObject
import java.util.concurrent.locks.ReentrantLock

class SystemFontLoader(context: Context) : FontLoaderInterface() {

    private val providers: List<FontAtlasProvider> = listOf(MSDFAtlasProvider(context))
    private val cache = mutableMapOf<String, FontAtlas>()
    private val cacheLock = ReentrantLock()

    override fun loadFont(font: Font): FontLoaderResult {
        val name = font.name
        Log.d("SystemFontLoader", "loadFont: $name")
        cacheLock.lock()
        val cached = cache[name]
        if (cached != null) {
            cacheLock.unlock()
            return FontLoaderResult(cached.texture, cached.fontData, LoaderStatus.OK)
        }
        cacheLock.unlock()

        for (provider in providers) {
            val atlas = provider.loadAtlas(name)
            if (atlas != null) {
                cacheLock.lock()
                cache[name] = atlas
                cacheLock.unlock()
                Log.d("SystemFontLoader", "loaded '$name' via ${provider.javaClass.simpleName}")
                return FontLoaderResult(atlas.texture, atlas.fontData, LoaderStatus.OK)
            }
        }

        val fallbackName = notoSansFallbackName(name)
        if (fallbackName != name) {
            for (provider in providers) {
                val atlas = provider.loadAtlas(fallbackName)
                if (atlas != null) {
                    cacheLock.lock()
                    cache[name] = atlas
                    cacheLock.unlock()
                    Log.d("SystemFontLoader", "using Noto Sans fallback '$fallbackName' for '$name'")
                    return FontLoaderResult(atlas.texture, atlas.fontData, LoaderStatus.OK)
                }
            }
        }

        Log.e("SystemFontLoader", "failed to load font: $name")
        return FontLoaderResult(null, null, LoaderStatus.ERROR_OTHER)
    }

    private fun notoSansFallbackName(name: String): String {
        val lower = name.lowercase()
        return when {
            lower.contains("bold") -> "Noto Sans Bold"
            lower.contains("italic") -> "Noto Sans Italic"
            else -> "Noto Sans Regular"
        }
    }
}

private data class FontAtlas(
    val texture: BitmapTextureHolder,
    val fontData: FontData,
)

private interface FontAtlasProvider {
    fun loadAtlas(name: String): FontAtlas?
}

private class MSDFAtlasProvider(private val context: Context) : FontAtlasProvider {

    private val psMapping = mapOf(
        "Noto Sans Regular" to "NotoSans-Regular",
        "Noto Sans Italic" to "NotoSans-Italic",
        "Noto Sans Bold" to "NotoSans-Bold",
    )

    override fun loadAtlas(name: String): FontAtlas? {
        val candidates = listOfNotNull(
            name.replace(" ", "_"),
            psMapping[name]
        )

        var jsonPath: String? = null
        var pngPath: String? = null
        for (candidate in candidates) {
            if (jsonPath == null && assetExists("fonts/$candidate.json")) {
                jsonPath = "fonts/$candidate.json"
            }
            if (pngPath == null && assetExists("fonts/$candidate.png")) {
                pngPath = "fonts/$candidate.png"
            }
        }

        if (jsonPath == null || pngPath == null) {
            return null
        }

        return try {
            val jsonString = context.assets.open(jsonPath).bufferedReader().use { it.readText() }
            val json = JSONObject(jsonString)
            val infoJson = json.getJSONObject("info")
            val commonJson = json.getJSONObject("common")
            val distanceFieldJson = json.getJSONObject("distanceField")
            val charsJson = json.getJSONArray("chars")

            val size = infoJson.getInt("size").toDouble()
            val imageSize = commonJson.getInt("scaleW").toDouble()
            if (size <= 0 || imageSize <= 0) {
                return null
            }

            val fontInfo = FontWrapper(
                name = name,
                lineHeight = commonJson.getInt("lineHeight").toDouble() / size,
                base = commonJson.getInt("base").toDouble() / size,
                bitmapSize = Vec2D(imageSize, imageSize),
                size = size,
                distanceRange = distanceFieldJson.getInt("distanceRange").toDouble()
            )

            val glyphs = ArrayList<FontGlyph>(charsJson.length())
            for (i in 0 until charsJson.length()) {
                val glyph = charsJson.getJSONObject(i)
                val s0 = glyph.getInt("x").toDouble()
                val s1 = s0 + glyph.getInt("width").toDouble()
                val t0 = glyph.getInt("y").toDouble()
                val t1 = t0 + glyph.getInt("height").toDouble()

                val uv = Quad2dD(
                    Vec2D(s0 / imageSize, t1 / imageSize),
                    Vec2D(s1 / imageSize, t1 / imageSize),
                    Vec2D(s1 / imageSize, t0 / imageSize),
                    Vec2D(s0 / imageSize, t0 / imageSize)
                )

                val xoffset = glyph.getInt("xoffset").toDouble()
                val yoffset = glyph.getInt("yoffset").toDouble()
                val bearing = Vec2D(xoffset / size, -yoffset / size)
                val advance = Vec2D(glyph.getInt("xadvance").toDouble() / size, 0.0)
                val bbox = Vec2D(glyph.getInt("width").toDouble() / size, glyph.getInt("height").toDouble() / size)

                glyphs.add(
                    FontGlyph(
                        glyph.getString("char"),
                        advance,
                        bbox,
                        bearing,
                        uv
                    )
                )
            }

            val bitmap = BitmapFactory.decodeStream(context.assets.open(pngPath))
                ?: return null
            val texture = BitmapTextureHolder(bitmap)

            Log.d("MSDFAtlasProvider", "loaded MSDF atlas for $name (${glyphs.size} glyphs, ${imageSize.toInt()}x${imageSize.toInt()})")
            FontAtlas(texture, FontData(fontInfo, glyphs))
        } catch (e: Exception) {
            Log.e("MSDFAtlasProvider", "failed to load atlas for $name", e)
            null
        }
    }

    private fun assetExists(path: String): Boolean {
        return try {
            context.assets.open(path).close()
            true
        } catch (e: Exception) {
            false
        }
    }
}
