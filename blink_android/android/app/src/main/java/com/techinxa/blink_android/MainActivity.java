package com.techinxa.blink_android;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.RectF;
import android.graphics.Shader;
import android.media.MediaMetadataRetriever;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

/**
 * Native cover extraction for Blink Reels.
 *
 * The third-party get_video_thumbnail plugin can call getScaledFrameAtTime()
 * with height=0 on certain Android camera recordings, causing an IOException.
 * We decode an unscaled video frame first, then safely scale its Bitmap.
 * If the device codec cannot decode a frame, publish can still proceed with
 * a clearly branded, valid JPEG cover instead of exposing a Java stack trace.
 */
public class MainActivity extends FlutterActivity {
    private static final String COVER_CHANNEL = "blink_android/reel_cover";
    private final ExecutorService coverExecutor = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(), COVER_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if (!"thumbnailJpeg".equals(call.method)) {
                result.notImplemented();
                return;
            }
            final String path = call.argument("path");
            final Number at = call.argument("timeMs");
            final long timeMs = at == null ? 0L : Math.max(0L, at.longValue());

            coverExecutor.execute(() -> {
                try {
                    if (path == null || path.isEmpty() || !new File(path).isFile()) {
                        throw new IllegalArgumentException("The recorded Reel file is unavailable.");
                    }
                    final byte[] jpeg = decodeCover(path, timeMs);
                    runOnUiThread(() -> result.success(jpeg));
                } catch (Exception error) {
                    runOnUiThread(() -> result.error(
                        "COVER_ERROR", "Unable to prepare Reel cover.", null));
                }
            });
        });
    }

    private byte[] decodeCover(String path, long timeMs) {
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        Bitmap frame = null;
        try {
            retriever.setDataSource(path);
            // Unlike getScaledFrameAtTime(), this does not require a video
            // metadata width/height. Some devices report one dimension as 0.
            frame = retriever.getFrameAtTime(
                timeMs * 1000L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            if (frame == null) {
                frame = retriever.getFrameAtTime(
                    0L, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);
            }
            if (frame == null) {
                frame = retriever.getFrameAtTime();
            }
            if (frame == null || frame.getWidth() <= 0 || frame.getHeight() <= 0) {
                return brandedFallbackCover();
            }
            final float scale = Math.min(1f, 720f /
                (float) Math.max(frame.getWidth(), frame.getHeight()));
            final int width = Math.max(1, Math.round(frame.getWidth() * scale));
            final int height = Math.max(1, Math.round(frame.getHeight() * scale));
            Bitmap scaled = Bitmap.createScaledBitmap(frame, width, height, true);
            try {
                return encodeJpeg(scaled);
            } finally {
                if (scaled != frame) scaled.recycle();
            }
        } catch (RuntimeException error) {
            // Failing to extract a frame must not discard a valid recorded Reel.
            return brandedFallbackCover();
        } finally {
            if (frame != null && !frame.isRecycled()) frame.recycle();
            try { retriever.release(); } catch (Exception ignored) { }
        }
    }

    private byte[] encodeJpeg(Bitmap bitmap) {
        ByteArrayOutputStream stream = new ByteArrayOutputStream();
        if (!bitmap.compress(Bitmap.CompressFormat.JPEG, 84, stream)) {
            throw new IllegalStateException("JPEG encoding failed.");
        }
        return stream.toByteArray();
    }

    private byte[] brandedFallbackCover() {
        final int width = 480;
        final int height = 720;
        Bitmap cover = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        try {
            Canvas canvas = new Canvas(cover);
            Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            paint.setShader(new LinearGradient(0, 0, width, height,
                new int[]{Color.rgb(255, 89, 0), Color.rgb(230, 75, 0),
                    Color.rgb(40, 22, 21)}, null, Shader.TileMode.CLAMP));
            canvas.drawRect(0, 0, width, height, paint);
            paint.setShader(null);

            // Reuse the app's ORIGINAL branded logo asset, not a substitute.
            try (InputStream input = getAssets().open(
                    "flutter_assets/assets/branding/final.png")) {
                Bitmap logo = BitmapFactory.decodeStream(input);
                if (logo != null) {
                    float ratio = Math.min(360f / logo.getWidth(),
                                           112f / logo.getHeight());
                    float dw = logo.getWidth() * ratio;
                    float dh = logo.getHeight() * ratio;
                    canvas.drawBitmap(logo, null, new RectF(
                        (width - dw) / 2f, 190f, (width + dw) / 2f, 190f + dh),
                        new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG));
                    logo.recycle();
                }
            } catch (Exception ignored) {
                paint.setColor(Color.WHITE);
                paint.setTextSize(62f);
                paint.setFakeBoldText(true);
                canvas.drawText("Blink", 155, 260, paint);
                paint.setFakeBoldText(false);
            }
            paint.setColor(Color.WHITE);
            Path triangle = new Path();
            triangle.moveTo(215f, 370f);
            triangle.lineTo(215f, 440f);
            triangle.lineTo(282f, 405f);
            triangle.close();
            canvas.drawPath(triangle, paint);
            paint.setTextSize(25f);
            paint.setTextAlign(Paint.Align.CENTER);
            canvas.drawText("A BLINK REEL", width / 2f, 515f, paint);
            return encodeJpeg(cover);
        } finally {
            cover.recycle();
        }
    }

    @Override
    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);
        coverExecutor.shutdown();
    }
}
