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
        val radius = 15f
        val extraX = bitmap.width / 2.0f
        canvas!!.drawBitmap(bitmap, (point.x-extraX).toFloat(), (point.y - (bitmap.height)).toFloat(), mCirclePaint)
        mCirclePaint.color = Color.BLUE
        mCirclePaint.alpha = 30
        mCirclePaint.style = Paint.Style.FILL
        canvas.drawCircle(point.x.toFloat()-radius/2, point.y.toFloat()-radius, radius, mCirclePaint)
        mCirclePaint.alpha = 150
        mCirclePaint.style = Paint.Style.STROKE
        canvas.drawCircle(point.x.toFloat()-radius/2, point.y.toFloat()-radius, radius, mCirclePaint)

        canvas.save()
    }


}