package com.explapp.gameslocal.kitkat;

import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Bundle;
import android.os.Handler;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;

/** Adds rich, lightweight interaction sounds to every legacy game screen. */
public class SoundMainActivity extends MainActivity {
    private final Handler observer = new Handler();
    private ToneGenerator tones;
    private float downX;
    private float downY;
    private long lastTapAt;
    private String lastStatus = "";

    @Override protected void onCreate(Bundle savedInstanceState) {
        tones = new ToneGenerator(AudioManager.STREAM_MUSIC, 84);
        super.onCreate(savedInstanceState);
        observer.post(statusWatcher);
    }

    @Override public boolean dispatchTouchEvent(MotionEvent event) {
        if (event.getAction() == MotionEvent.ACTION_DOWN) {
            downX = event.getRawX();
            downY = event.getRawY();
        } else if (event.getAction() == MotionEvent.ACTION_UP) {
            float dx = Math.abs(event.getRawX() - downX);
            float dy = Math.abs(event.getRawY() - downY);
            if (dx < 18f && dy < 18f) playTap(event.getRawX(), event.getRawY());
        }
        return super.dispatchTouchEvent(event);
    }

    private void playTap(float x, float y) {
        if (tones == null || System.currentTimeMillis() - lastTapAt < 55L) return;
        lastTapAt = System.currentTimeMillis();
        View target = findView(getWindow().getDecorView(), x, y);
        String label = target instanceof TextView ? ((TextView) target).getText().toString() : "";

        if (containsAny(label, "رجوع", "العودة", "إغلاق")) {
            tones.startTone(ToneGenerator.TONE_PROP_BEEP2, 80);
        } else if (containsAny(label, "إعادة", "جولة جديدة", "ابدأ", "بدء")) {
            tones.startTone(ToneGenerator.TONE_DTMF_0, 115);
        } else if (containsAny(label, "حذف", "إلغاء")) {
            tones.startTone(ToneGenerator.TONE_PROP_NACK, 120);
        } else if (containsAny(label, "لعبة", "اختيار", "التالي")) {
            tones.startTone(ToneGenerator.TONE_PROP_ACK, 105);
        } else {
            tones.startTone(ToneGenerator.TONE_DTMF_5, 75);
        }
    }

    private final Runnable statusWatcher = new Runnable() {
        @Override public void run() {
            if (tones != null) {
                String status = collectText(getWindow().getDecorView());
                if (!status.equals(lastStatus)) {
                    if (containsAny(status, "فزت", "فاز", "أحسنت", "مبروك")) {
                        tones.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 430);
                    } else if (containsAny(status, "تعادل")) {
                        tones.startTone(ToneGenerator.TONE_CDMA_ABBR_INTERCEPT, 230);
                    } else if (containsAny(status, "انتهت الجولة", "خسرت", "لا توجد لك حركة")) {
                        tones.startTone(ToneGenerator.TONE_PROP_NACK, 220);
                    } else if (containsAny(status, "الكمبيوتر يفكر")) {
                        tones.startTone(ToneGenerator.TONE_DTMF_9, 70);
                    }
                    lastStatus = status;
                }
                observer.postDelayed(this, 280L);
            }
        }
    };

    private String collectText(View view) {
        StringBuilder builder = new StringBuilder();
        appendText(view, builder);
        return builder.toString();
    }

    private void appendText(View view, StringBuilder builder) {
        if (view == null || view.getVisibility() != View.VISIBLE) return;
        if (view instanceof TextView) builder.append('|').append(((TextView) view).getText());
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = 0; i < group.getChildCount(); i++) appendText(group.getChildAt(i), builder);
        }
    }

    private View findView(View view, float rawX, float rawY) {
        if (view == null || view.getVisibility() != View.VISIBLE) return null;
        int[] location = new int[2];
        view.getLocationOnScreen(location);
        if (rawX < location[0] || rawX > location[0] + view.getWidth()
                || rawY < location[1] || rawY > location[1] + view.getHeight()) return null;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup) view;
            for (int i = group.getChildCount() - 1; i >= 0; i--) {
                View child = findView(group.getChildAt(i), rawX, rawY);
                if (child != null) return child;
            }
        }
        return view;
    }

    private boolean containsAny(String value, String... words) {
        for (String word : words) if (value.contains(word)) return true;
        return false;
    }

    @Override protected void onDestroy() {
        observer.removeCallbacksAndMessages(null);
        if (tones != null) {
            tones.release();
            tones = null;
        }
        super.onDestroy();
    }
}
