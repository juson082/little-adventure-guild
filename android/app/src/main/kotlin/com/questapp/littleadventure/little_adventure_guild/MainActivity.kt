package com.questapp.littleadventure.little_adventure_guild

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val locationChannel = "hvildir/approximate_location"
    private val permissionRequest = 7214
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, locationChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "hasPermission") {
                    result.success(checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED)
                } else if (call.method != "getLocation" && call.method != "requestLocation") {
                    result.notImplemented()
                } else if (checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    readApproximateLocation(result)
                } else if (call.method == "getLocation") {
                    // Automatic daily lookups must never reopen the permission prompt.
                    result.success(null)
                } else if (pendingPermission != null) {
                    result.success(null)
                } else {
                    pendingPermission = result
                    requestPermissions(arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION), permissionRequest)
                }
            }
    }

    @Deprecated("Deprecated in Android API")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != permissionRequest) return
        val result = pendingPermission ?: return
        pendingPermission = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            readApproximateLocation(result)
        } else {
            result.success(null)
        }
    }

    @Suppress("DEPRECATION")
    private fun readApproximateLocation(result: MethodChannel.Result) {
        val manager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val handler = Handler(Looper.getMainLooper())
        var finished = false
        var listener: LocationListener? = null
        var timeout: Runnable? = null
        fun finish(location: Location?) {
            if (finished) return
            finished = true
            timeout?.let { handler.removeCallbacks(it) }
            listener?.let { try { manager.removeUpdates(it) } catch (_: Exception) {} }
            result.success(location?.let { mapOf("latitude" to it.latitude, "longitude" to it.longitude) })
        }
        try {
            if (!manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                finish(null)
                return
            }
            val last = manager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            val age = last?.let { System.currentTimeMillis() - it.time }
            if (last != null && age != null && age in 0..(15 * 60 * 1000L)) {
                finish(last)
                return
            }
            val currentListener = object : LocationListener {
                override fun onLocationChanged(location: Location) { finish(location) }
                @Deprecated("Deprecated in Android API")
                override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                override fun onProviderDisabled(provider: String) { finish(null) }
                override fun onProviderEnabled(provider: String) {}
            }
            listener = currentListener
            timeout = Runnable { finish(null) }
            handler.postDelayed(timeout!!, 7000)
            manager.requestSingleUpdate(LocationManager.NETWORK_PROVIDER, currentListener, Looper.getMainLooper())
        } catch (_: Exception) {
            finish(null)
        }
    }
}
