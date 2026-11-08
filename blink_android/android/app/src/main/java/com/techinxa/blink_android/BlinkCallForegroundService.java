package com.techinxa.blink_android;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.IBinder;
import androidx.annotation.Nullable;

/**
 * Ongoing WebRTC call capture notification.
 * Starts only AFTER the in-foreground app obtains microphone/camera consent.
 * This is not an incoming-call push receiver or Android Telecom replacement.
 */
public final class BlinkCallForegroundService extends Service {
    private static final String CHANNEL = "blink_ongoing_call";
    private static final int NOTIFICATION_ID = 2107;

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            final NotificationChannel channel = new NotificationChannel(
                CHANNEL, "Ongoing Blink calls",
                NotificationManager.IMPORTANCE_LOW);
            channel.setDescription("Shows an active voice or video call.");
            getSystemService(NotificationManager.class).createNotificationChannel(channel);
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        final boolean video = intent != null && intent.getBooleanExtra("video", false);
        final Intent open = getPackageManager().getLaunchIntentForPackage(getPackageName());
        PendingIntent launch = null;
        if (open != null) {
            open.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            final int options = PendingIntent.FLAG_UPDATE_CURRENT |
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
                    ? PendingIntent.FLAG_IMMUTABLE : 0);
            launch = PendingIntent.getActivity(this, 0, open, options);
        }

        final Notification.Builder builder = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
            ? new Notification.Builder(this, CHANNEL) : new Notification.Builder(this);
        builder.setContentTitle(video ? "Blink video call" : "Blink voice call")
            .setContentText("Call in progress — tap to return to Blink")
            .setSmallIcon(android.R.drawable.stat_sys_phone_call)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_CALL)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true);
        if (launch != null) builder.setContentIntent(launch);

        final int serviceTypes = video
            ? ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE |
                ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            : ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE;

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, builder.build(), serviceTypes);
        } else {
            startForeground(NOTIFICATION_ID, builder.build());
        }
        return START_NOT_STICKY;
    }

    @Override
    public void onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE);
        } else {
            stopForeground(true);
        }
        super.onDestroy();
    }

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
}
