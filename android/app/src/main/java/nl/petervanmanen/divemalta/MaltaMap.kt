package nl.petervanmanen.divemalta

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.RectF
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.camera.CameraUpdateFactory
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.geometry.LatLngBounds
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.OnCameraTrackingChangedListener
import org.maplibre.android.location.engine.LocationEngineCallback
import org.maplibre.android.location.engine.LocationEngineRequest
import org.maplibre.android.location.engine.LocationEngineResult
import android.os.Looper
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import org.maplibre.android.style.layers.CircleLayer
import org.maplibre.android.style.layers.Property
import org.maplibre.android.style.layers.PropertyFactory
import org.maplibre.android.style.sources.GeoJsonSource
import org.maplibre.geojson.Feature
import org.maplibre.geojson.FeatureCollection
import org.maplibre.geojson.Point

/**
 * MapLibre map drawn entirely from the bundled data (shared/data: OpenStreetMap vector tiles, depth
 * contours, dive sites), so it works offline. Always north up, no tilting.
 */
class MaltaMap(context: Context) {
    val view = MapView(context)

    var onSelectSite: (String) -> Unit = {}
    var onTapMap: () -> Unit = {}
    var onProbe: (Double, Double) -> Unit = { _, _ -> }
    var onOutsideMap: (Boolean) -> Unit = {}
    /** Following stopped on its own: the user panned, or their location is outside the map. */
    var onStopFollowing: () -> Unit = {}
    var onUserOutsideMap: () -> Unit = {}

    private var map: MapLibreMap? = null
    private var style: Style? = null
    private var outside = false
    private var following = false
    private var waitingForLocation = false
    private var visitedShown: Set<String>? = null
    private val bundledSites: List<Feature> by lazy {
        view.context.assets.open("data/malta-dive-sites.geojson").bufferedReader().use {
            FeatureCollection.fromJson(it.readText()).features().orEmpty()
        }
    }

    companion object {
        /** What the bundled map covers. */
        val bounds: LatLngBounds = LatLngBounds.from(36.12, 14.65, 35.75, 14.10)
        private val malta: LatLngBounds = LatLngBounds.from(36.09, 14.61, 35.78, 14.16)

        fun contains(lat: Double, lon: Double) = lat in 35.75..36.12 && lon in 14.10..14.65
    }

    fun start(styleJson: String, scene: ScreenshotScene?, onReady: () -> Unit) {
        view.getMapAsync { map ->
            this.map = map
            map.uiSettings.apply {
                isRotateGesturesEnabled = false
                isTiltGesturesEnabled = false
                isCompassEnabled = false
                isLogoEnabled = false
                isAttributionEnabled = false   // credits are shown by the app
            }
            map.setMinZoomPreference(8.5)
            map.setMaxZoomPreference(18.0)
            map.setStyle(Style.Builder().fromJson(styleJson)) { style ->
                this.style = style
                style.addSource(GeoJsonSource("probe"))
                style.addLayer(CircleLayer("probe", "probe").withProperties(
                    PropertyFactory.circleColor("#FF3B30"), PropertyFactory.circleRadius(9f),
                    PropertyFactory.circleStrokeColor("#FFFFFF"), PropertyFactory.circleStrokeWidth(3f),
                ))
                val camera = scene?.camera
                if (camera != null) {
                    map.moveCamera(CameraUpdateFactory.newCameraPosition(
                        CameraPosition.Builder().target(LatLng(camera.first, camera.second)).zoom(camera.third).build()))
                } else {
                    view.post { showMalta(animated = false) }
                }
                onReady()
            }
            map.addOnMapClickListener { latLng ->
                val point = map.projection.toScreenLocation(latLng)
                val r = 22 * view.resources.displayMetrics.density
                val features = map.queryRenderedFeatures(RectF(point.x - r, point.y - r, point.x + r, point.y + r),
                    "sites", "site-clusters")
                val feature = features.firstOrNull()
                when {
                    feature == null -> onTapMap()
                    feature.hasProperty("point_count") ->
                        map.animateCamera(CameraUpdateFactory.newLatLngZoom(
                            (feature.geometry() as Point).let { LatLng(it.latitude(), it.longitude()) },
                            minOf(map.cameraPosition.zoom + 2, 16.0)))
                    feature.hasProperty("id") -> onSelectSite(feature.getStringProperty("id"))
                }
                true
            }
            map.addOnMapLongClickListener { latLng ->
                onProbe(latLng.latitude, latLng.longitude); true
            }
            map.addOnCameraIdleListener {
                val target = map.cameraPosition.target ?: return@addOnCameraIdleListener
                val now = !contains(target.latitude, target.longitude)
                if (now != outside) { outside = now; onOutsideMap(now) }
            }
        }
    }

    fun showMalta(animated: Boolean = true) {
        val map = map ?: return
        val d = view.resources.displayMetrics.density
        val update = CameraUpdateFactory.newLatLngBounds(malta, (10 * d).toInt(), (40 * d).toInt(), (10 * d).toInt(), (60 * d).toInt())
        if (following) setFollowing(false)
        if (animated) map.animateCamera(update) else map.moveCamera(update)
    }

    fun focus(lat: Double, lon: Double) {
        map?.animateCamera(CameraUpdateFactory.newLatLngZoom(LatLng(lat, lon), 15.0))
    }

    fun setContours(visible: Boolean) {
        val v = PropertyFactory.visibility(if (visible) Property.VISIBLE else Property.NONE)
        listOf("contours", "contour-labels").forEach { style?.getLayer(it)?.setProperties(v) }
    }

    /**
     * Sets "visited" on the sites from your dive log; the style gives them, and clusters holding one,
     * a thick green ring (shared/tools/style/make_style.mjs).
     */
    fun setVisited(ids: Set<String>) {
        val source = style?.getSourceAs<GeoJsonSource>("sites") ?: return
        if (ids == visitedShown) return
        // Before the first dive log scan there is nothing to change in the bundled data.
        if (visitedShown == null && ids.isEmpty()) { visitedShown = ids; return }
        visitedShown = ids
        source.setGeoJson(FeatureCollection.fromFeatures(bundledSites.map { feature ->
            val id = if (feature.hasProperty("id")) feature.getStringProperty("id") else null
            if (id != null && id in ids) {
                Feature.fromJson(feature.toJson()).also { it.addBooleanProperty("visited", true) }
            } else feature
        }))
    }

    fun setProbe(lat: Double?, lon: Double?) {
        val source = style?.getSourceAs<GeoJsonSource>("probe") ?: return
        if (lat != null && lon != null) source.setGeoJson(Point.fromLngLat(lon, lat))
        else source.setGeoJson(FeatureCollection.fromFeatures(emptyList()))
    }

    /** Only follow the user inside the bundled map; otherwise tell the UI and stay put. */
    @SuppressLint("MissingPermission")   // called after the permission was granted
    fun setFollowing(follow: Boolean) {
        val map = map ?: return
        val style = style ?: return
        following = follow
        val lc = map.locationComponent
        if (follow) {
            if (!lc.isLocationComponentActivated) {
                lc.activateLocationComponent(
                    LocationComponentActivationOptions.builder(view.context, style).useDefaultLocationEngine(true).build())
                lc.addOnCameraTrackingChangedListener(object : OnCameraTrackingChangedListener {
                    override fun onCameraTrackingDismissed() {
                        if (following) { following = false; onStopFollowing() }
                    }
                    override fun onCameraTrackingChanged(currentMode: Int) {}
                })
                // Watch the location while following: start once the first fix arrives, stop if it leaves the map.
                lc.locationEngine?.requestLocationUpdates(
                    LocationEngineRequest.Builder(2000).build(),
                    object : LocationEngineCallback<LocationEngineResult> {
                        override fun onSuccess(result: LocationEngineResult) {
                            val location = result.lastLocation ?: return
                            if (following && waitingForLocation) startFollowing()
                            else if (following && !contains(location.latitude, location.longitude)) stopOutside()
                        }
                        override fun onFailure(exception: Exception) {}
                    }, Looper.getMainLooper())
            }
            lc.isLocationComponentEnabled = true
            lc.renderMode = RenderMode.NORMAL
            startFollowing()
        } else {
            waitingForLocation = false
            if (lc.isLocationComponentActivated) lc.cameraMode = CameraMode.NONE
        }
    }

    @SuppressLint("MissingPermission")
    private fun startFollowing() {
        val lc = map?.locationComponent ?: return
        val location = lc.lastKnownLocation
        if (location == null) { waitingForLocation = true; return }
        waitingForLocation = false
        if (contains(location.latitude, location.longitude)) lc.cameraMode = CameraMode.TRACKING
        else stopOutside()
    }

    private fun stopOutside() {
        following = false
        waitingForLocation = false
        map?.locationComponent?.cameraMode = CameraMode.NONE
        view.post { onStopFollowing(); onUserOutsideMap() }
    }
}
