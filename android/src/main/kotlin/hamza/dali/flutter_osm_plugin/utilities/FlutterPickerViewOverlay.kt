package hamza.dali.flutter_osm_plugin.utilities

import android.content.Context
import android.graphics.*
import android.view.View

class FlutterPickerViewOverlay constructor(
        private val bitmap: Bitmap,
        context: Context,
        private val point: Point,
) : View(context, null) {

    private var mCirclePaint = Paint()

    override fun draw(canvas: Canvas?) {
        super.draw(canvas)
        val radius = 45f
        val extraX = bitmap.width / 2.0f - 0.5f
        val extraY = bitmap.height / 2.0f - 0.5f
        mCirclePaint.color = Color.BLUE
        mCirclePaint.alpha = 30
        mCirclePaint.style = Paint.Style.FILL
        canvas!!.drawCircle(point.x.toFloat(), point.y.toFloat(), radius, mCirclePaint)
        mCirclePaint.alpha = 150
        mCirclePaint.style = Paint.Style.STROKE
        canvas.drawCircle(point.x.toFloat(), point.y.toFloat(), radius, mCirclePaint)

        canvas.drawBitmap(bitmap, (point.x - extraX).toFloat(), (point.y - extraX).toFloat(), mCirclePaint)
        canvas.save()
    }


}