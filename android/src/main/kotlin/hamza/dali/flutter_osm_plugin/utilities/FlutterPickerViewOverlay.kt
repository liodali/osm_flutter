package hamza.dali.flutter_osm_plugin.utilities

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.view.View

class FlutterPickerViewOverlay(
    private val bitmap: Bitmap,
    context: Context,
    private val point: Point,
    private val isCustom: Boolean = false,
) : View(context) {


    private var mCirclePaint = Paint()

    override fun draw(canvas: Canvas) {
        super.draw(canvas)
        val radius = 18f
        val extraX = bitmap.width / 3.0f
        val extraY = bitmap.height / 10f

        if (!isCustom) {
            mCirclePaint.color = Color.BLUE
            mCirclePaint.alpha = 30
            mCirclePaint.style = Paint.Style.FILL
            canvas.drawCircle(
                (point.x.toFloat() /*- radius / 2 + extraX*/),
                point.y.toFloat() - radius + extraY,
                radius,
                mCirclePaint
            )
            mCirclePaint.alpha = 150
            mCirclePaint.style = Paint.Style.STROKE
            canvas.drawCircle(
                (point.x.toFloat()/* - radius / 2 + extraX*/),
                point.y.toFloat() - radius + extraY,
                radius,
                mCirclePaint
            )

        }
        canvas.drawBitmap(
            bitmap,
            (point.x - extraX),
            (point.y - (bitmap.height)).toFloat(),
            Paint()
        )
        canvas.save()
    }


}