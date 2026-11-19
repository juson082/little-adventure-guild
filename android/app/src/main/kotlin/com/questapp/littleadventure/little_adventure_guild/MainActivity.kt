package com.questapp.littleadventure.little_adventure_guild

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<String, Int>()
    private val loadedSounds = mutableSetOf<Int>()
    private val pendingSounds = mutableSetOf<Int>()
    private var effectsVolume = 1f
    private var musicPlayer: MediaPlayer? = null
    private var activityResumed = false
    private val activeStreams = mutableSetOf<Int>()

    private fun playSound(pool: SoundPool, id: Int) {
        val stream = pool.play(id, effectsVolume, effectsVolume, 1, 0, 1f)
        if (stream != 0) {
            activeStreams.add(stream)
            Handler(Looper.getMainLooper()).postDelayed({ activeStreams.remove(stream) }, 7000)
        }
    }

    private val locationChannel = "hvildir/approximate_location"
    private val permissionRequest = 7214
    private var pendingPermission: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val pool = SoundPool.Builder().setMaxStreams(4)
            .setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            .build()
        soundPool = pool
        pool.setOnLoadCompleteListener { loadedPool, soundId, status ->
            if (status == 0) {
                loadedSounds.add(soundId)
                if (pendingSounds.remove(soundId)) playSound(loadedPool, soundId)
            } else pendingSounds.remove(soundId)
        }
        soundIds["wood"] = pool.load(this, R.raw.guild_wood, 1)
        soundIds["gold"] = pool.load(this, R.raw.guild_gold, 1)
        soundIds["question"] = pool.load(this, R.raw.guild_question, 1)
        soundIds["reveal_normal"] = pool.load(this, R.raw.guild_reveal_normal, 1)
        soundIds["reveal_hard"] = pool.load(this, R.raw.guild_reveal_hard, 1)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hvildir/sound_effects")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "play" -> {
                        soundIds[call.arguments as? String]?.let { id ->
                            if (loadedSounds.contains(id)) playSound(pool, id)
                            else pendingSounds.add(id)
                        }
                        result.success(null)
                    }
                    "volume" -> {
                        effectsVolume = ((call.arguments as? Number)?.toFloat() ?: 1f).coerceIn(0f, 1f)
                        activeStreams.forEach { pool.setVolume(it, effectsVolume, effectsVolume) }
                        result.success(null)
                    }
                    "musicVolume" -> {
                        val volume = ((call.arguments as? Number)?.toFloat() ?: 1f).coerceIn(0f, 1f)
                        try {
                            val player = musicPlayer ?: MediaPlayer.create(this, R.raw.guild_bgm)?.also {
                                it.isLooping = true
                                musicPlayer = it
                            }
                            player?.setVolume(volume, volume)
                            if (activityResumed && player != null && !player.isPlaying) player.start()
                        } catch (_: IllegalStateException) {
                            musicPlayer?.release()
                            musicPlayer = null
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hvildir/sound_effects")
            .setMethodCallHandler(null)
        soundPool?.release()
        soundPool = null
        soundIds.clear()
        loadedSounds.clear()
        pendingSounds.clear()
        activeStreams.clear()
        musicPlayer?.release()
        musicPlayer = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        activityResumed = true
        try {
            musicPlayer?.let { if (!it.isPlaying) it.start() }
        } catch (_: IllegalStateException) {
            musicPlayer?.release()
            musicPlayer = null
        }
    }

    override fun onPause() {
        activityResumed = false
        try {
            musicPlayer?.let { if (it.isPlaying) it.pause() }
        } catch (_: IllegalStateException) {
            musicPlayer?.release()
            musicPlayer = null
        }
        super.onPause()
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
