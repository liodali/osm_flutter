package hamza.dali.flutter_osm_plugin

import io.flutter.plugin.common.MethodCall

// Define all possible method calls as a sealed class
sealed class MapMethodChannelCall(val methodName: String) {
    object Init : MapMethodChannelCall("initMap")
    object ChangeTile : MapMethodChannelCall("change#tile")
    object InfoWindowVisibility : MapMethodChannelCall("use#visiblityInfoWindow")
    object ZoomConfiguration : MapMethodChannelCall("config#Zoom")
    object SetZoom : MapMethodChannelCall("Zoom")
    object GetZoom : MapMethodChannelCall("get#Zoom")
    object SetStepZoom : MapMethodChannelCall("change#stepZoom")
    object ZoomToRegion : MapMethodChannelCall("zoomToRegion")
    object ShowZoomController : MapMethodChannelCall("showZoomController")
    object CurrentLocation : MapMethodChannelCall("currentLocation")
    object LimitArea : MapMethodChannelCall("limitArea")
    object RemoveLimitArea : MapMethodChannelCall("remove#limitArea")
    object TrackMe : MapMethodChannelCall("trackMe")
    object DeactivateTrackMe : MapMethodChannelCall("deactivateTrackMe")
    object StartLocationUpdating : MapMethodChannelCall("startLocationUpdating")
    object StopLocationUpdating : MapMethodChannelCall("stopLocationUpdating")
    object Center : MapMethodChannelCall("map#center")
    object Bounds : MapMethodChannelCall("map#bounds")
    object UserPosition : MapMethodChannelCall("user#position")
    object MoveTo : MapMethodChannelCall("moveTo#position")
    object RemoveMarkerPosition : MapMethodChannelCall("user#removeMarkerPosition")
    object DeleteRoad : MapMethodChannelCall("delete#road")
    object DrawMultiRoad : MapMethodChannelCall("draw#multi#road")
    object ClearRoads : MapMethodChannelCall("clear#roads")
    object DefaultMarkerIcon : MapMethodChannelCall("marker#icon")
    object DrawRoadManually : MapMethodChannelCall("drawRoad#manually")
    object StaticPosition : MapMethodChannelCall("staticPosition")
    object StaticPositionIconMarker : MapMethodChannelCall("staticPosition#IconMarker")
    object DrawCircle : MapMethodChannelCall("draw#circle")
    object RemoveCircle : MapMethodChannelCall("remove#circle")
    object DrawRect : MapMethodChannelCall("draw#rect")
    object RemoveRect : MapMethodChannelCall("remove#rect")
    object ClearShapes : MapMethodChannelCall("clear#shapes")
    object MapOrientation : MapMethodChannelCall("map#orientation")
    object LocationMarkers : MapMethodChannelCall("user#locationMarkers")
    object AddMarker : MapMethodChannelCall("add#Marker")
    object UpdateMarker : MapMethodChannelCall("update#Marker")
    object ChangeMarker : MapMethodChannelCall("change#Marker")
    object GetMarkers : MapMethodChannelCall("get#geopoints")
    object DeleteMakers : MapMethodChannelCall("delete#markers")
    object ToggleLayers : MapMethodChannelCall("toggle#Alllayer")
    // Add more method calls as needed

    companion object {
        fun fromMethodCall(call: MethodCall): MapMethodChannelCall? {
            return when (call.method) {
                Init.methodName -> Init
                ChangeTile.methodName -> ChangeTile
                InfoWindowVisibility.methodName -> InfoWindowVisibility
                ZoomConfiguration.methodName -> ZoomConfiguration
                SetZoom.methodName -> SetZoom
                GetZoom.methodName -> GetZoom
                SetStepZoom.methodName -> SetStepZoom
                ZoomToRegion.methodName -> ZoomToRegion
                ShowZoomController.methodName -> ShowZoomController
                CurrentLocation.methodName -> CurrentLocation
                LimitArea.methodName -> LimitArea
                RemoveLimitArea.methodName -> RemoveLimitArea
                TrackMe.methodName -> TrackMe
                DeactivateTrackMe.methodName -> DeactivateTrackMe
                StartLocationUpdating.methodName -> StartLocationUpdating
                StopLocationUpdating.methodName -> StopLocationUpdating
                Center.methodName -> Center
                Bounds.methodName -> Bounds
                UserPosition.methodName -> UserPosition
                MoveTo.methodName -> MoveTo
                DeleteRoad.methodName -> DeleteRoad
                DrawMultiRoad.methodName -> DrawMultiRoad
                DefaultMarkerIcon.methodName -> DefaultMarkerIcon
                ClearRoads.methodName -> ClearRoads
                DefaultMarkerIcon.methodName -> DefaultMarkerIcon
                DrawRoadManually.methodName -> DrawRoadManually
                StaticPosition.methodName -> StaticPosition
                StaticPositionIconMarker.methodName -> StaticPositionIconMarker
                DrawCircle.methodName -> DrawCircle
                RemoveCircle.methodName -> RemoveCircle
                DrawRect.methodName -> DrawRect
                RemoveRect.methodName -> RemoveRect
                ClearShapes.methodName -> ClearShapes
                MapOrientation.methodName -> MapOrientation
                AddMarker.methodName -> AddMarker
                LocationMarkers.methodName -> LocationMarkers
                AddMarker.methodName -> AddMarker
                RemoveMarkerPosition.methodName -> RemoveMarkerPosition
                UpdateMarker.methodName -> UpdateMarker
                ChangeMarker.methodName -> ChangeMarker
                GetMarkers.methodName -> GetMarkers
                DeleteMakers.methodName -> DeleteMakers
                ToggleLayers.methodName -> ToggleLayers

                else -> null
            }
        }
    }
}