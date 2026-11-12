package com.secretbase.secret_base_app

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.AudioEncoderSettings
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Trims and converts videos to H.264/AAC MP4 with the short side capped,
 * using AndroidX Media3 Transformer.
 *
 * MethodChannel `secretbase/video_tools`:
 *  - `convert` {id, path, startMs?, endMs?, maxShortSide, videoBitrate, audioBitrate}
 *    → output .mp4 path in cacheDir.
 *  - `cancel` {id} → the pending `convert` fails with code `cancelled`.
 *  - `supported` → true when a Transformer can be created.
 * Error codes: `cancelled`, `unsupported`, `failed`.
 *
 * EventChannel `secretbase/video_tools/progress`: {id, progress 0..1}
 * roughly every 250ms per running job, then a final 1.0.
 *
 * Transformer must be used from a single looper thread; everything here runs
 * on the main looper (the platform thread Flutter delivers calls on).
 */
@OptIn(UnstableApi::class)
class VideoToolsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private class Job(
        val id: String,
        val transformer: Transformer,
        val output: File,
        val result: MethodChannel.Result,
    ) {
        var finished = false
        val progressHolder = ProgressHolder()
    }

    private lateinit var context: Context
    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var events: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val jobs = HashMap<String, Job>()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        for (job in jobs.values.toList()) {
            job.finished = true
            runCatching { job.transformer.cancel() }
            job.output.delete()
        }
        jobs.clear()
        mainHandler.removeCallbacksAndMessages(null)
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        events = null
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
    }

    override fun onCancel(arguments: Any?) {
        events = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "convert" -> convert(call, result)
            "cancel" -> {
                val id = call.argument<String>("id")
                if (id != null) cancel(id)
                result.success(null)
            }
            "supported" -> result.success(
                runCatching {
                    Transformer.Builder(context).setLooper(Looper.getMainLooper()).build()
                }.isSuccess,
            )
            else -> result.notImplemented()
        }
    }

    private fun convert(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        val path = call.argument<String>("path")
        if (id.isNullOrEmpty() || path.isNullOrEmpty()) {
            result.error("failed", "convert needs id and path", null)
            return
        }
        if (jobs.containsKey(id)) {
            result.error("failed", "a conversion with id $id is already running", null)
            return
        }
        val startMs = call.argument<Number>("startMs")?.toLong()
        val endMs = call.argument<Number>("endMs")?.toLong()
        val maxShortSide = call.argument<Number>("maxShortSide")?.toInt() ?: 720
        val videoBitrate = call.argument<Number>("videoBitrate")?.toInt() ?: 2_500_000
        val audioBitrate = call.argument<Number>("audioBitrate")?.toInt() ?: 128_000

        val uri = toUri(path)
        val outDir = File(context.cacheDir, "video_tools").apply { mkdirs() }
        val safeId = id.replace(Regex("[^A-Za-z0-9_-]"), "_").take(48)
        val output = File(outDir, "${safeId}_${System.currentTimeMillis()}.mp4")

        val job: Job
        try {
            val mediaItemBuilder = MediaItem.Builder().setUri(uri)
            if (startMs != null || endMs != null) {
                val clipping = MediaItem.ClippingConfiguration.Builder()
                if (startMs != null && startMs > 0) clipping.setStartPositionMs(startMs)
                if (endMs != null && endMs > 0) clipping.setEndPositionMs(endMs)
                mediaItemBuilder.setClippingConfiguration(clipping.build())
            }

            // Short side is rotation-invariant, so the stored dimensions are
            // enough to decide whether to scale; never upscale.
            val sourceShortSide = shortSideOf(uri)
            val videoEffects = if (sourceShortSide == null || sourceShortSide > maxShortSide) {
                listOf(Presentation.createForShortSide(maxShortSide))
            } else {
                emptyList()
            }

            val edited = EditedMediaItem.Builder(mediaItemBuilder.build())
                .setEffects(Effects(emptyList(), videoEffects))
                .build()

            val encoderFactory = DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(
                    VideoEncoderSettings.Builder().setBitrate(videoBitrate).build(),
                )
                .setRequestedAudioEncoderSettings(
                    AudioEncoderSettings.Builder().setBitrate(audioBitrate).build(),
                )
                .setEnableFallback(true)
                .build()

            lateinit var created: Job
            val transformer = Transformer.Builder(context)
                .setLooper(Looper.getMainLooper())
                .setVideoMimeType(MimeTypes.VIDEO_H264)
                .setAudioMimeType(MimeTypes.AUDIO_AAC)
                .setEncoderFactory(encoderFactory)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        onJobCompleted(created)
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        onJobError(created, exportException)
                    }
                })
                .build()
            created = Job(id, transformer, output, result)
            job = created
            jobs[id] = job
            transformer.start(edited, output.absolutePath)
        } catch (e: Exception) {
            jobs.remove(id)
            output.delete()
            result.error("failed", e.toString(), null)
            return
        }
        emitProgress(id, 0.0)
        scheduleProgress(job)
    }

    private fun scheduleProgress(job: Job) {
        mainHandler.postDelayed({
            if (job.finished) return@postDelayed
            val state = runCatching { job.transformer.getProgress(job.progressHolder) }
                .getOrDefault(Transformer.PROGRESS_STATE_NOT_STARTED)
            if (state == Transformer.PROGRESS_STATE_AVAILABLE) {
                // Keep 1.0 for the final event only.
                emitProgress(job.id, (job.progressHolder.progress / 100.0).coerceIn(0.0, 0.99))
            }
            scheduleProgress(job)
        }, PROGRESS_INTERVAL_MS)
    }

    private fun onJobCompleted(job: Job) {
        if (job.finished) return
        job.finished = true
        jobs.remove(job.id)
        emitProgress(job.id, 1.0)
        job.result.success(job.output.absolutePath)
    }

    private fun onJobError(job: Job, e: ExportException) {
        if (job.finished) return
        job.finished = true
        jobs.remove(job.id)
        job.output.delete()
        val code = when (e.errorCode) {
            ExportException.ERROR_CODE_ENCODER_INIT_FAILED,
            ExportException.ERROR_CODE_ENCODING_FORMAT_UNSUPPORTED,
            ExportException.ERROR_CODE_DECODER_INIT_FAILED,
            ExportException.ERROR_CODE_DECODING_FORMAT_UNSUPPORTED,
            -> "unsupported"
            else -> "failed"
        }
        job.result.error(code, e.toString(), e.errorCodeName)
    }

    private fun cancel(id: String) {
        val job = jobs.remove(id) ?: return
        if (job.finished) return
        job.finished = true
        // Transformer fires no listener callback after cancel(); answer here.
        runCatching { job.transformer.cancel() }
        job.output.delete()
        job.result.error("cancelled", "conversion $id was cancelled", null)
    }

    private fun emitProgress(id: String, progress: Double) {
        events?.success(mapOf("id" to id, "progress" to progress))
    }

    private fun toUri(path: String): Uri =
        if (path.startsWith("content://") || path.startsWith("file://")) {
            Uri.parse(path)
        } else {
            Uri.fromFile(File(path))
        }

    private fun shortSideOf(uri: Uri): Int? {
        val retriever = MediaMetadataRetriever()
        return try {
            if (uri.scheme == "file") {
                retriever.setDataSource(uri.path)
            } else {
                retriever.setDataSource(context, uri)
            }
            val w = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val h = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            if (w != null && h != null && w > 0 && h > 0) minOf(w, h) else null
        } catch (_: Exception) {
            null
        } finally {
            runCatching { retriever.release() }
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "secretbase/video_tools"
        const val EVENT_CHANNEL = "secretbase/video_tools/progress"
        const val PROGRESS_INTERVAL_MS = 250L
    }
}
