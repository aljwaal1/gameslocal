package com.explapp.gameslocal.kitkat;

import android.app.Activity;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.os.Bundle;
import android.os.Handler;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

public class MainActivity extends Activity {
    private LinearLayout root;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        showHome();
    }

    private void showHome() {
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setPadding(24, 24, 24, 24);
        root.setBackgroundColor(Color.rgb(244, 247, 246));

        TextView title = new TextView(this);
        title.setText("ألعاب محلية 4.4");
        title.setTextSize(26);
        title.setTextColor(Color.rgb(25, 55, 50));
        title.setGravity(Gravity.CENTER);
        root.addView(title, new LinearLayout.LayoutParams(-1, -2));

        TextView note = new TextView(this);
        note.setText("نسخة Java خفيفة للأجهزة القديمة. كل لعبة سيتم تطويرها لوحدها.");
        note.setTextSize(16);
        note.setGravity(Gravity.CENTER);
        note.setPadding(0, 18, 0, 18);
        root.addView(note, new LinearLayout.LayoutParams(-1, -2));

        Button checkers = new Button(this);
        checkers.setText("الضامة ضد الكمبيوتر");
        checkers.setOnClickListener(v -> showCheckers());
        root.addView(checkers, new LinearLayout.LayoutParams(-1, -2));

        Button domino = new Button(this);
        domino.setText("الدومينو - لاحقًا");
        root.addView(domino, new LinearLayout.LayoutParams(-1, -2));

        Button chess = new Button(this);
        chess.setText("الشطرنج - لاحقًا");
        root.addView(chess, new LinearLayout.LayoutParams(-1, -2));

        Button cards = new Button(this);
        cards.setText("الشدة / السراقة - لاحقًا");
        root.addView(cards, new LinearLayout.LayoutParams(-1, -2));

        setContentView(root);
    }

    private void showCheckers() {
        LinearLayout screen = new LinearLayout(this);
        screen.setOrientation(LinearLayout.VERTICAL);
        screen.setPadding(12, 12, 12, 12);
        screen.setBackgroundColor(Color.rgb(244, 247, 246));

        Button back = new Button(this);
        back.setText("رجوع");
        back.setOnClickListener(v -> showHome());
        screen.addView(back, new LinearLayout.LayoutParams(-1, -2));

        TextView status = new TextView(this);
        status.setText("أنت الأحمر - دورك");
        status.setTextSize(18);
        status.setGravity(Gravity.CENTER);
        status.setPadding(0, 10, 0, 10);
        screen.addView(status, new LinearLayout.LayoutParams(-1, -2));

        CheckersView view = new CheckersView(this, status);
        screen.addView(view, new LinearLayout.LayoutParams(-1, 0, 1));

        Button reset = new Button(this);
        reset.setText("إعادة اللعبة");
        reset.setOnClickListener(v -> view.reset());
        screen.addView(reset, new LinearLayout.LayoutParams(-1, -2));

        setContentView(screen);
    }

    public static class CheckersView extends View {
        private static final int EMPTY = 0;
        private static final int RED = 1;
        private static final int BLACK = 2;
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final int[][] board = new int[8][8];
        private final TextView status;
        private int selectedRow = -1;
        private int selectedCol = -1;
        private boolean redTurn = true;
        private boolean botThinking = false;
        private final Handler handler = new Handler();

        public CheckersView(Activity activity, TextView status) {
            super(activity);
            this.status = status;
            reset();
        }

        public void reset() {
            for (int r = 0; r < 8; r++) {
                for (int c = 0; c < 8; c++) board[r][c] = EMPTY;
            }
            for (int r = 0; r < 3; r++) {
                for (int c = 0; c < 8; c++) if (((r + c) % 2) == 1) board[r][c] = BLACK;
            }
            for (int r = 5; r < 8; r++) {
                for (int c = 0; c < 8; c++) if (((r + c) % 2) == 1) board[r][c] = RED;
            }
            selectedRow = -1;
            selectedCol = -1;
            redTurn = true;
            botThinking = false;
            status.setText("أنت الأحمر - دورك");
            invalidate();
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            int size = Math.min(getWidth(), getHeight());
            int left = (getWidth() - size) / 2;
            int top = (getHeight() - size) / 2;
            int cell = size / 8;

            for (int r = 0; r < 8; r++) {
                for (int c = 0; c < 8; c++) {
                    boolean dark = ((r + c) % 2) == 1;
                    if (r == selectedRow && c == selectedCol) paint.setColor(Color.rgb(255, 209, 102));
                    else paint.setColor(dark ? Color.rgb(86, 115, 109) : Color.rgb(232, 239, 234));
                    canvas.drawRect(left + c * cell, top + r * cell, left + (c + 1) * cell, top + (r + 1) * cell, paint);

                    if (board[r][c] != EMPTY) {
                        paint.setColor(board[r][c] == RED ? Color.rgb(200, 76, 76) : Color.rgb(34, 40, 49));
                        canvas.drawCircle(left + c * cell + cell / 2f, top + r * cell + cell / 2f, cell * 0.34f, paint);
                    }
                }
            }
        }

        @Override
        public boolean performClick() {
            super.performClick();
            return true;
        }

        @Override
        public boolean onTouchEvent(android.view.MotionEvent event) {
            if (event.getAction() != android.view.MotionEvent.ACTION_DOWN) return true;
            performClick();
            if (botThinking || !redTurn) return true;

            int size = Math.min(getWidth(), getHeight());
            int left = (getWidth() - size) / 2;
            int top = (getHeight() - size) / 2;
            int cell = size / 8;
            int c = (int) ((event.getX() - left) / cell);
            int r = (int) ((event.getY() - top) / cell);
            if (r < 0 || r >= 8 || c < 0 || c >= 8) return true;

            tap(r, c);
            return true;
        }

        private void tap(int r, int c) {
            if (selectedRow < 0) {
                if (board[r][c] == RED) {
                    selectedRow = r;
                    selectedCol = c;
                    status.setText("اختر خانة للحركة");
                    invalidate();
                }
                return;
            }

            if (board[r][c] == RED) {
                selectedRow = r;
                selectedCol = c;
                invalidate();
                return;
            }

            Move move = validMove(selectedRow, selectedCol, r, c, RED);
            if (move == null) {
                status.setText("حركة غير صحيحة");
                return;
            }

            apply(move);
            selectedRow = -1;
            selectedCol = -1;
            redTurn = false;
            status.setText("الكمبيوتر يفكر...");
            invalidate();
            botMoveLater();
        }

        private void botMoveLater() {
            botThinking = true;
            handler.postDelayed(() -> {
                Move move = chooseBotMove();
                if (move == null) {
                    status.setText("فزت! لا توجد حركة للكمبيوتر");
                    botThinking = false;
                    invalidate();
                    return;
                }
                apply(move);
                redTurn = true;
                botThinking = false;
                status.setText("أنت الأحمر - دورك");
                invalidate();
            }, 550);
        }

        private Move chooseBotMove() {
            List<Move> moves = allMoves(BLACK);
            if (moves.isEmpty()) return null;
            for (Move m : moves) if (m.captureRow >= 0) return m;
            return moves.get(0);
        }

        private List<Move> allMoves(int player) {
            List<Move> moves = new ArrayList<>();
            int dir = player == RED ? -1 : 1;
            for (int r = 0; r < 8; r++) {
                for (int c = 0; c < 8; c++) {
                    if (board[r][c] != player) continue;
                    addIfValid(moves, r, c, r + dir, c - 1, player);
                    addIfValid(moves, r, c, r + dir, c + 1, player);
                    addIfValid(moves, r, c, r + dir * 2, c - 2, player);
                    addIfValid(moves, r, c, r + dir * 2, c + 2, player);
                }
            }
            return moves;
        }

        private void addIfValid(List<Move> moves, int sr, int sc, int tr, int tc, int player) {
            Move m = validMove(sr, sc, tr, tc, player);
            if (m != null) moves.add(m);
        }

        private Move validMove(int sr, int sc, int tr, int tc, int player) {
            if (!inside(sr, sc) || !inside(tr, tc)) return null;
            if (board[sr][sc] != player || board[tr][tc] != EMPTY) return null;
            int dr = tr - sr;
            int dc = tc - sc;
            int dir = player == RED ? -1 : 1;
            if (Math.abs(dc) != Math.abs(dr)) return null;
            if (dr == dir && Math.abs(dc) == 1) return new Move(sr, sc, tr, tc, -1, -1);
            if (dr == dir * 2 && Math.abs(dc) == 2) {
                int mr = (sr + tr) / 2;
                int mc = (sc + tc) / 2;
                int opponent = player == RED ? BLACK : RED;
                if (board[mr][mc] == opponent) return new Move(sr, sc, tr, tc, mr, mc);
            }
            return null;
        }

        private void apply(Move move) {
            board[move.tr][move.tc] = board[move.sr][move.sc];
            board[move.sr][move.sc] = EMPTY;
            if (move.captureRow >= 0) board[move.captureRow][move.captureCol] = EMPTY;
        }

        private boolean inside(int r, int c) {
            return r >= 0 && r < 8 && c >= 0 && c < 8;
        }
    }

    public static class Move {
        final int sr, sc, tr, tc, captureRow, captureCol;
        Move(int sr, int sc, int tr, int tc, int captureRow, int captureCol) {
            this.sr = sr;
            this.sc = sc;
            this.tr = tr;
            this.tc = tc;
            this.captureRow = captureRow;
            this.captureCol = captureCol;
        }
    }
}
